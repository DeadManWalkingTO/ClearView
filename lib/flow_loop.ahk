; ==================== lib/flow_loop.ahk ====================
#Requires AutoHotkey v2.0
#Include "settings.ahk"
#Include "videopicker.ahk"
#Include "moves.ahk"         ; ← χρησιμοποιούμε ClickCenter() & MoveMouseRandom4()

; FlowLoop:
; - Τρέχει τον συνεχόμενο κύκλο: Pick -> Navigate -> Ensure -> Recheck/Recover -> Wait.
; - Δεν ανοίγει/κλείνει Edge· δέχεται ήδη έτοιμο hWnd.
; - Διατηρεί pause/stop state, cycle counter και GUI-rect για exclusion στο VideoService.
; - Τηρεί τους κανόνες AHK v2 (πολυγραμμικά if, πλήρη try/catch, χωρίς &&/||).

class FlowLoop {
    __New(logger, edgeSvc, videoSvc, picker, settings) {
        this.log := logger
        this.edge := edgeSvc
        this.video := videoSvc
        this.picker := picker
        this.settings := settings

        this._paused := false
        this._stopRequested := false
        this._cycleCount := 0

        ; GUI-rect (screen coords) για exclusion στο sampling
        this.guiX := 0
        this.guiY := 0
        this.guiW := 0
        this.guiH := 0
    }

    ; ---- Public API ----
    SetGuiRect(x, y, w, h) {
        try {
            this.guiX := x + 0
        } catch {
            this.guiX := 0
        }
        try {
            this.guiY := y + 0
        } catch {
            this.guiY := 0
        }
        try {
            this.guiW := w + 0
        } catch {
            this.guiW := 0
        }
        try {
            this.guiH := h + 0
        } catch {
            this.guiH := 0
        }
        try {
            if (this.log) {
                this.log.Write(Format("🧭 GUI rect (loop): x={1} y={2} w={3} h={4}", this.guiX, this.guiY, this.guiW, this.guiH))
            }
        } catch {
        }
    }

    TogglePause() {
        this._paused := !this._paused
        return this._paused
    }

    RequestStop() {
        this._stopRequested := true
    }

    IsPaused() {
        return this._paused
    }

    GetCycleCount() {
        return this._cycleCount
    }

    ; Τρέχει τον άπειρο κύκλο στο ήδη ανοιχτό Edge window (hWnd).
    ; Επιστρέφει μόνο όταν ζητηθεί Stop (ή προκύψει εξαίρεση από caller).
    Run(hWnd, startFrom := 0) {
        if (startFrom > 0) {
            this._cycleCount := startFrom
        } else {
            this._cycleCount := 0
        }

        loop {
            this._checkAbortOrPause()
            this._cycleCount += 1

            local cycleNo := this._cycleCount
            local startTs := FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss")

            try {
                this.log.Write(Format("🔄 Κύκλος #{1} σε εξέλιξη…", cycleNo))
            } catch {
            }

            ; --- Επιλογή video μέσω VideoPicker ---
            info := 0
            try {
                info := this.picker.Pick(Settings.LIST1_PROB_PCT, this.log)
            } catch {
                info := { source: "none", id: "", url: "about:blank" }
            }
            try {
                this.log.Write(Format("📚 Κύκλος #{1} — {2}", cycleNo, info.source))
                this.log.Write(Format("🔑 ID: {1} 🕒 start={2}", info.id, startTs))
                this.log.Write(Format("🌐 Πλοήγηση σε: {1}", info.url))
            } catch {
            }

            ; Πλοήγηση
            this.edge.NavigateToUrl(hWnd, info.url)
            try {
                this.log.SleepWithLog(Settings.STEP_DELAY_MS, "μετά την πλοήγηση")
            } catch {
            }

            ; One-shot δράση μόνο στην 1η επανάληψη: ενοποιημένη σε ClickCenter()
            if (cycleNo = 1) {
                try {
                    ; μικρό human-like pre-move delay (0) και προ-κλικ καθυστέρηση 80ms
                    ClickCenter(hWnd, this.log, 0, 80)
                } catch {
                }
            }

            ; Ensure playing (με GUI-rect exclusion)
            ok := false
            try {
                ok := this.video.EnsurePlaying(hWnd, this.log, this.guiX, this.guiY, this.guiW, this.guiH)
            } catch {
                ok := false
            }

            if (ok) {
                try {
                    this.log.Write("🎵 Το βίντεο παίζει.")
                } catch {
                }
            } else {
                try {
                    this.log.Write("⛔ Το βίντεο ΔΕΝ παίζει.")
                } catch {
                }
            }

            ; Αναμονή μετά το detection
            try {
                this.log.SleepWithLog(Settings.STEP_DELAY_MS, "μετά το detection")
            } catch {
            }

            ; Δεύτερος έλεγχος για false positive
            ok2 := false
            try {
                ok2 := this.video.IsPlaying(hWnd, this.log, this.guiX, this.guiY, this.guiW, this.guiH)
            } catch {
                ok2 := false
            }

            if (!ok2) {
                try {
                    this.log.Write("⚠️ Μετά την αναμονή: δεν ανιχνεύεται κίνηση — πιθανό false positive. Προσπάθεια ανάκτησης…")
                } catch {
                }

                recOk := false
                try {
                    recOk := this.video.EnsurePlaying(hWnd, this.log, this.guiX, this.guiY, this.guiW, this.guiH)
                } catch {
                    recOk := false
                }

                if (recOk) {
                    try {
                        this.log.Write("✅ Ανάκτηση επιτυχής μετά το false positive.")
                    } catch {
                    }
                } else {
                    try {
                        this.log.Write("❌ Αποτυχία ανάκτησης μετά το false positive.")
                    } catch {
                    }
                }
            } else {
                try {
                    this.log.Write("✅ Επιβεβαίωση: το βίντεο συνεχίζει να παίζει μετά την αναμονή.")
                } catch {
                }
            }

            ; Αναμονή μεταξύ βίντεο (τυχαία εντός min/max)
            waitMs := this._computeRandomWaitMs()
            try {
                this.log.Write(Format("⏳ Αναμονή ακριβώς {1} ms ({2}) — κύκλος #{3}", waitMs, this._fmtDurationMs(waitMs), cycleNo))
            } catch {
            }

            this._sleepRespectingPauseStop(waitMs, "αναμονή μεταξύ βίντεο")

            try {
                this.log.Write(Format("🟢 Τέλος Κύκλου #{1}", cycleNo))
            } catch {
            }
        }
    }

    ; ---- Internals ----

    _computeRandomWaitMs() {
        minMs := Settings.LOOP_MIN_MS + 0
        maxMs := Settings.LOOP_MAX_MS + 0
        if (maxMs < minMs) {
            tmp := minMs
            minMs := maxMs
            maxMs := tmp
        }
        try {
            return Round(Random(minMs, maxMs))
        } catch {
        }
    }

    _fmtDurationMs(ms) {
        total := ms + 0
        if (total < 0) {
            total := 0
        }
        m := Floor(total / 60000)
        rem := Mod(total, 60000)
        s := Floor(rem / 1000)
        msRem := Mod(rem, 1000)
        sTxt := (s < 10 ? "0" s : "" s)
        msTxt := (msRem < 10 ? "00" msRem : (msRem < 100 ? "0" msRem : "" msRem))
        return m "m " sTxt "s " msTxt "ms"
    }

    _sleepRespectingPauseStop(ms, label := "") {
        chunk := 500
        elapsed := 0
        try {
            if (label != "") {
                this.log.Write(Format("⏳ Αναμονή σε εξέλιξη ({1} ms — {2})", ms, label))
            } else {
                this.log.Write(Format("⏳ Αναμονή σε εξέλιξη ({1} ms)", ms))
            }
        } catch {
        }

        while (elapsed < ms) {
            while this._paused
                Sleep(150)
            if this._stopRequested
                throw Error("Stopped by user")
            Sleep(chunk)
            elapsed += chunk
        }
    }

    _checkAbortOrPause() {
        while this._paused
            Sleep(150)
        if this._stopRequested
            throw Error("Stopped by user")
    }
}
; ==================== End Of File ====================
