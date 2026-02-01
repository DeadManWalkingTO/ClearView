; ==================== lib/flow_loop.ahk ====================
#Requires AutoHotkey v2.0
#Include "settings.ahk"
#Include "videopicker.ahk"
#Include "moves.ahk"       ; ← ClickCenter(), MoveMouseRandom4()
#Include "utils.ahk"       ; ← Utils.FormatDurationMs(), Utils.MsToSec(), Utils.RandomInt()

; FlowLoop:
; - Τρέχει τον συνεχόμενο κύκλο: Pick -> Navigate -> Ensure -> Wait.
; - Δεν ανοίγει/κλείνει Edge· δέχεται ήδη έτοιμο hWnd.
; - Διατηρεί pause/stop state, cycle counter και GUI-rect για exclusion στο VideoService.
; - Κανόνες: AHK v2, πολυγραμμικά if, πλήρη try/catch, χωρίς &&/||.

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
            this.guiX := Utils.TryParseInt(x, 0)
        } catch {
            this.guiX := 0
        }
        try {
            this.guiY := Utils.TryParseInt(y, 0)
        } catch {
            this.guiY := 0
        }
        try {
            this.guiW := Utils.TryParseInt(w, 0)
        } catch {
            this.guiW := 0
        }
        try {
            this.guiH := Utils.TryParseInt(h, 0)
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

            ; Σήμανση κύκλου
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

            try {
                Settings.CLICK_OCCURRED_THIS_VIDEO := false
            } catch {
            }


            ; Πλοήγηση
            this.edge.NavigateToUrl(hWnd, info.url)
            try {
                this.log.SleepWithLog(Settings.STEP_DELAY_MS, "μετά την πλοήγηση")
            } catch {
            }

            ; Προ-κλικ ελεγχόμενο από Settings.PRE_CLICK_ENABLED
            if (Settings.PRE_CLICK_ENABLED) {
                try {
                    ClickCenter(hWnd, this.log, 0, 80)
                    ; ΝΕΟ: σημείωσε ότι έγινε click στο ΤΡΕΧΟΝ βίντεο
                    try {
                        Settings.CLICK_OCCURRED_THIS_VIDEO := true
                    } catch {
                    }
                } catch {
                }
            } else {
                try {
                    this.log.Write("↪️ Skip προ-κλικ (PRE_CLICK_ENABLED=false).")
                } catch {
                }
            }

            ; --- Ensure-only flow (χωρίς guards/IsPlaying εκτός video.ahk) ---
            attempt := 0
            maxAttempts := 3      ; 1η + έως 2 ανακτήσεις (προσαρμόσιμο)

            while (attempt < maxAttempts) {
                this._checkAbortOrPause()
                attempt := attempt + 1

                ok := false
                try {
                    ok := this.video.EnsurePlaying(hWnd, this.log, this.guiX, this.guiY, this.guiW, this.guiH)
                } catch {
                    ok := false
                }

                ; Ενδιάμεση αναμονή πριν την επόμενη προσπάθεια Ensure (αν χρειαστεί)
                if (attempt < maxAttempts) {
                    try {
                        this.log.SleepWithLog(Settings.STEP_DELAY_MS, "αναμονή πριν τον έλεγχο αναπαραγωγής")
                    } catch {
                    }
                }
            }

            ; --- Αναμονή μεταξύ βίντεο (τυχαία εντός min/max) ---
            waitMs := this._computeRandomWaitMs()
            SleepMessage := (Format("({1}) — κύκλος #{2}", Utils.FormatDurationMs(waitMs), cycleNo))

            ; Προτιμούμε sec στα runtime logs
            this._sleepRespectingPauseStop(waitMs, SleepMessage)

            ; Τέλος κύκλου
            try {
                this.log.Write(Format("🟢 Τέλος Κύκλου #{1}", cycleNo))
            } catch {
            }
        }
    }

    ; ---- Internals ----

    _computeRandomWaitMs() {
        minMs := 0
        maxMs := 0
        try {
            minMs := Settings.LOOP_MIN_MS + 0
        } catch {
            minMs := 0
        }
        try {
            maxMs := Settings.LOOP_MAX_MS + 0
        } catch {
            maxMs := minMs
        }
        ; Utils.RandomInt χειρίζεται τυχόν αντιστροφή ορίων
        try {
            return Utils.RandomInt(minMs, maxMs)
        } catch {
            return minMs
        }
    }

    ; Χρήση sec στα logs (1 δεκαδικό). Ο ύπνος εκτελείται σε «κομμάτια»,
    ; σεβόμενος pause/stop, ώστε να μπορεί να διακοπεί έγκαιρα.
    _sleepRespectingPauseStop(ms, label := "") {
        chunk := 500
        elapsed := 0

        ; Log έναρξης σε s
        try {
            sec := Utils.MsToSec(ms)  ; default 1 δεκαδικό
            if (label != "") {
                this.log.Write(Format("⏳ Αναμονή σε εξέλιξη ({1} s — {2})", sec, label))
            } else {
                this.log.Write(Format("⏳ Αναμονή σε εξέλιξη ({1} s)", sec))
            }
        } catch {
        }

        ; -------- ΝΕΟ: αντίστροφος μετρητής ανά 30s --------
        tickWindowMs := Settings.WAIT_TICK_MS   ; κάθε 30.000 ms
        nextTickAt := tickWindowMs              ; πότε θα "χτυπήσει" το επόμενο ενημερωτικό
        ; -----------------------------------------------

        while (elapsed < ms) {

            ; Σεβασμός Pause
            while this._paused
                Sleep(150)

            ; Σεβασμός Stop
            if this._stopRequested
                throw Error("Stopped by user")

            ; Κοιμήσου μικρά κομμάτια
            Sleep(chunk)
            elapsed += chunk

            ; Αν πέρασαν 30s (ή πολλαπλάσια), δώσε ενημέρωση
            ; Προσοχή: μπορεί να "ξεπεράσουμε" το nextTickAt λόγω chunk → while για catch-up
            while (elapsed >= nextTickAt) {
                remaining := ms - elapsed
                if (remaining < 0) {
                    remaining := 0
                }
                remSec := Utils.MsToSec(remaining)   ; 1 δεκαδικό
                try {
                    if (label != "") {
                        this.log.Write(Format("⏳ 30s πέρασαν · απομένουν {1} s — {2}", remSec, label))
                    } else {
                        this.log.Write(Format("⏳ 30s πέρασαν · απομένουν {1} s", remSec))
                    }
                } catch {
                }
                ; ετοιμάσου για το επόμενο "χτύπημα"
                nextTickAt += tickWindowMs
            }
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
