; ==================== lib/flow.ahk ====================
#Requires AutoHotkey v2.0
#Include "..\core\system\utils.ahk"  ; ← χρήση Utils.TryParseInt για καθάρισμα SetGuiRect
#Include "..\core\system\regex.ahk"
#Include "settings.ahk"
#Include "edge.ahk"
#Include "edge_profile.ahk" ; ⬅️ Χρησιμοποιούμε StartEdgeWithAppProfile / Ex
#Include "video.ahk"
#Include "moves.ahk"
#Include "lists.ahk"
#Include "videopicker.ahk"
#Include "flow_loop.ahk"     
#Include "initialize.ahk"   ; ⬅️ Helpers εκκίνησης (helpLine + version check)

class FlowController {
    __New(log, edge, video, settings) {
        this.log := log
        this.edge := edge
        this.video := video
        this.settings := settings

        this._running := false
        this._paused := false
        this._stopRequested := false
        this._cycleCount := 0

        ; Νέα services για λίστες/επιλογή video και αντικείμενο loop
        this.lists := ListsService()
        this.picker := 0
        this._loop := 0

        ; ορθογώνιο GUI για αποκλεισμό sampling (screen coords)
        this.guiX := 0
        this.guiY := 0
        this.guiW := 0
        this.guiH := 0

        ; ⬇️ ΝΕΟ: αποθηκεύουμε αναφορά στο UI window
        this._wnd := 0
    }

    IsRunning() => this._running

    ; Setter για GUI rect (screen coords)
    SetGuiRect(x, y, w, h) {
        ; Καθαρή μετατροπή με Utils.TryParseInt
        try {
            this.guiX := Utils.TryParseInt(x, 0)
        } catch Error as e {
            this.guiX := 0
        }
        try {
            this.guiY := Utils.TryParseInt(y, 0)
        } catch Error as e {
            this.guiY := 0
        }
        try {
            this.guiW := Utils.TryParseInt(w, 0)
        } catch Error as e {
            this.guiW := 0
        }
        try {
            this.guiH := Utils.TryParseInt(h, 0)
        } catch Error as e {
            this.guiH := 0
        }
        try {
            if (this.log) {
                this.log.Write(Format("🧭 GUI rect set: x={1} y={2} w={3} h={4}", this.guiX, this.guiY, this.guiW, this.guiH))
            }
        } catch Error as e {
        }
        ; Αν υπάρχει ήδη loop, συγχρονίζουμε το rect και εκεί
        try {
            if (this._loop) {
                this._loop.SetGuiRect(this.guiX, this.guiY, this.guiW, this.guiH)
            }
        } catch Error as e {
        }
    }

    ; ⬇️ ΝΕΟ: Setter για το UI window (για χρήση σε boot init)
    SetWindow(wnd) {
        try {
            this._wnd := wnd
        } catch {
            this._wnd := 0
        }
    }

    ; ⬇️ ΝΕΟ: Εκτελεί update helpLine + ελαφρύ version-check, χρησιμοποιώντας this._wnd.
    PerformBootInitialization() {
        wnd := 0
        try {
            wnd := this._wnd
        } catch {
            wnd := 0
        }

        if (wnd) {
            online := false
            try {
                online := Initializer.UpdateConnectivityHelp(wnd, 3000)
            } catch {
                online := false
            }
            try {
                if (online) {
                    Initializer.BootVersionCheck(this.log, 3000, wnd)
                }
            } catch {
            }
        }
    }

    ; --- Φόρτωση λιστών + init VideoPicker ---
    _loadListsAndPicker() {
        try {
            this.lists.Load(this.log)
        } catch Error as e {
            throw e
        }
        try {
            this.picker := VideoPicker(this.lists)
        } catch Error as e {
            throw Error("VideoPicker init failed: " e.Message)
        }
    }

    StartRun() {
        if this._running {
            try {
                this.log.Write("ℹ️ Αγνοήθηκε")
            } catch Error as e {
            }
            return
        }

        this._running := true
        this._paused := false
        this._stopRequested := false
        this._cycleCount := 0

        ; Φόρτωση λιστών πριν τη ροή
        this._loadListsAndPicker()
        this.log.Write(Format("▶️ Ξεκινάει η ροή αυτοματισμού — έκδοση: {1}", Settings.APP_VERSION))

        ; Καθυστέρηση
        this.log.SleepWithLog(Settings.SMALL_DELAY_MS)

        try {
            this._run()
        } catch Error as eRun {
            try {
                this.log.Write(
                    Format("❌ Σφάλμα Ροής: {1} — What={2}, File={3}, Line={4}", eRun.Message, eRun.What, eRun.File, eRun.Line)
                )
            } catch Error as e {
            }
        }

        this._running := false
        this._paused := false
        this._stopRequested := false
        try {
            this.log.Write("✨ Ροή Ολοκληρώθηκε / Διακόπηκε")
        } catch Error as e {
        }
    }

    TogglePause() {
        if !this._running
            return false
        this._paused := !this._paused
        ; Προώθηση στο ενεργό loop, αν υπάρχει
        try {
            if (this._loop) {
                this._loop.TogglePause()
            }
        } catch Error as e {
        }
        return this._paused
    }

    RequestStop() {
        this._stopRequested := true
        ; Προώθηση στο ενεργό loop, αν υπάρχει
        try {
            if (this._loop) {
                this._loop.RequestStop()
            }
        } catch Error as e {
        }
    }

    _run() {
        local hNew := 0
        this._checkAbortOrPause()

        ; ----------------------------------------------
        ; 1) Άνοιγμα ΝΕΟΥ παραθύρου Edge με το προφίλ της εφαρμογής (SSOT):
        ;    - Προσπάθησε πρώτα με StartEdgeWithAppProfileEx (επιστρέφει hWnd).
        ;    - Αν δεν υπάρχει ακόμη, fallback σε StartEdgeWithAppProfile + ανίχνευση νέου hWnd.
        ; ----------------------------------------------
        this.log.Write(Format("🔎 Προσπάθεια εκκίνησης Edge με προφίλ: {1}", Settings.EDGE_PROFILE_NAME))
        try {
            ; Πρώτη επιλογή: έκδοση που επιστρέφει hWnd (περνάμε logger)
            hNew := StartEdgeWithAppProfileEx(this.edge, "about:blank", true, this.log)
        } catch {
            hNew := 0
        }

        if (!hNew) {
            ; Fallback: κάλεσε την απλή StartEdgeWithAppProfile και βρες το νέο παράθυρο
            ; με σύγκριση λίστας πριν/μετά.
            try {
                before := WinGetList(Settings.EDGE_WIN_SEL)
            } catch {
                before := []
            }
            try {
                StartEdgeWithAppProfile("about:blank", true, this.log)
            } catch {
                ; no-op
            }
            tries := 40
            loop tries {
                Sleep(250)
                after := WinGetList(Settings.EDGE_WIN_SEL)
                hNew := FlowController._findNewWindow_(before, after)
                if (hNew) {
                    break
                }
            }
        }

        if (!hNew) {
            try {
                this.log.Write("❌ Αποτυχία Ανοίγματος Νέου Παραθύρου Edge")
            } catch Error as e {
            }
            return
        }

        ; Προετοιμασία παραθύρου (σε περίπτωση που η Ex δεν το έτρεξε ήδη)
        try {
            WinActivate("ahk_id " hNew)
            WinWaitActive("ahk_id " hNew, , 5)
            WinMaximize("ahk_id " hNew)
            this.log.Write("✅ Edge Ready")
        } catch {
        }

        ; Καθυστέρηση
        this.log.SleepWithLog(Settings.SMALL_DELAY_MS)

        ; Κλείνω τις άλλες καρτέλες (μένει μόνο η active από το pre-warm)
        try {
            this.edge.CloseOtherTabsInNewWindow(hNew)
            this.log.Write("🧹 Καθαρισμός tabs: έκλεισα την άλλη καρτέλα στο νέο παράθυρο (παραμένει η τρέχουσα).")
        } catch {
        }

        ; Κλείσιμο άλλων Edge windows (αν ζητηθεί)
        this.log.SleepWithLog(Settings.SMALL_DELAY_MS)
        if (Settings.CLOSE_ALL_OTHER_WINDOWS) {
            this.edge.CloseAllOtherWindows(hNew)
            this.log.Write("🛠️ Κλείσιμο άλλων παραθύρων: ολοκληρώθηκε (CLOSE_ALL_OTHER_WINDOWS=true).")
            this.log.SleepWithLog(Settings.SMALL_DELAY_MS)
        }

        ; ενημερωτικό log για αποκλεισμό GUI κατά το sampling
        try {
            if (this.guiW > 0) {
                if (this.guiH > 0) {
                    this.log.Write(
                        Format("🧭 Ενεργός αποκλεισμός GUI στο sampling: x={1} y={2} w={3} h={4}", this.guiX, this.guiY, this.guiW, this.guiH)
                    )
                }
            }
        } catch {
        }

        ; Μικρή αναμονή
        this.log.SleepWithLog(Settings.SMALL_DELAY_MS)

        ; =========================
        ; 🔁 Continuous loop (FlowLoop)
        ; =========================
        this._loop := 0
        try {
            this._loop := FlowLoop(this.log, this.edge, this.video, this.picker, Settings)
            ; Συγχρονισμός GUI-rect και αρχικής κατάστασης pause
            this._loop.SetGuiRect(this.guiX, this.guiY, this.guiW, this.guiH)
            if (this._paused) {
                this._loop.TogglePause()
            }
        } catch Error as _eNewLoop {
            this._loop := 0
        }

        try {
            if (this._loop) {
                this._loop.Run(hNew)
            }
        } catch Error as e {
            ; stop/pause/exception καταλήγει εδώ
        }

        ; Μετά το τέλος του loop, χειρισμός παραθύρου
        if (!Settings.KEEP_EDGE_OPEN) {
            WinClose("ahk_id " hNew)
            WinWaitClose("ahk_id " hNew, , 5)
            ; Καθυστέρηση
            this.log.SleepWithLog(Settings.SMALL_DELAY_MS)
            try {
                this.log.Write("✨ Ολοκλήρωση Κύκλου")
            } catch Error as e {
            }
        } else {
            try {
                this.log.Write("✨ Ολοκλήρωση Κύκλου (Παραμονή Παραθύρου)")
            } catch Error as e {
            }
        }
    }

    _checkAbortOrPause() {
        while this._paused
            Sleep(150)
        if this._stopRequested
            throw Error("Stopped by user")
    }

    ; --- Βοηθητικό: εύρεση νέου hWnd (diff) ---
    static _findNewWindow_(beforeArr, afterArr) {
        seen := Map()
        for _, h in beforeArr {
            seen[h] := true
        }
        for _, h in afterArr {
            if !seen.Has(h) {
                return h
            }
        }
        return 0
    }
}
; ==================== End Of File ====================
