; ==================== lib/flow.ahk ====================
#Requires AutoHotkey v2.0
#Include "settings.ahk"
#Include "regex.ahk"
#Include "edge.ahk"
#Include "video.ahk"
#Include "moves.ahk"
#Include "lists.ahk"
#Include "videopicker.ahk"
#Include "flow_loop.ahk"

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
    }

    IsRunning() => this._running

    ; Setter για GUI rect (screen coords)
    SetGuiRect(x, y, w, h) {
        try {
            this.guiX := x + 0
        } catch Error as _e1 {
            this.guiX := 0
        }
        try {
            this.guiY := y + 0
        } catch Error as _e2 {
            this.guiY := 0
        }
        try {
            this.guiW := w + 0
        } catch Error as _e3 {
            this.guiW := 0
        }
        try {
            this.guiH := h + 0
        } catch Error as _e4 {
            this.guiH := 0
        }
        try {
            if (this.log) {
                this.log.Write(Format("🧭 GUI rect set: x={1} y={2} w={3} h={4}", this.guiX, this.guiY, this.guiW, this.guiH))
            }
        } catch Error as _e5 {
        }
        ; Αν υπάρχει ήδη loop, συγχρονίζουμε το rect και εκεί
        try {
            if (this._loop) {
                this._loop.SetGuiRect(this.guiX, this.guiY, this.guiW, this.guiH)
            }
        } catch Error as _e6 {
        }
    }

    ; --- ΝΕΟ: φόρτωση λιστών + init VideoPicker ---
    _loadListsAndPicker() {
        try {
            this.lists.Load(this.log)
        } catch Error as eList {
            throw eList
        }
        try {
            this.picker := VideoPicker(this.lists)
        } catch Error as ePicker {
            throw Error("VideoPicker init failed: " ePicker.Message)
        }
    }

    StartRun() {
        if this._running {
            try {
                this.log.Write("ℹ️ Αγνοήθηκε")
            } catch Error as _eStartAlready {
            }
            return
        }

        this._running := true
        this._paused := false
        this._stopRequested := false
        this._cycleCount := 0

        ; Φόρτωση λιστών πριν τη ροή
        this._loadListsAndPicker()

        try {
            this.log.ShowTimed(
                "Έναρξη",
                Format("Ξεκινάει η ροή αυτοματισμού — έκδοση: {1}", Settings.APP_VERSION),
                "BH Automation — Έναρξη",
                "Iconi"
            )
            this.log.Write(Format("▶️ Έναρξη Πατήθηκε — {1}", Settings.APP_VERSION))
        } catch Error as _eShow {
        }

        try {
            this._run()
        } catch Error as eRun {
            try {
                this.log.Write(
                    Format("❌ Σφάλμα Ροής: {1} — What={2}, File={3}, Line={4}", eRun.Message, eRun.What, eRun.File, eRun.Line)
                )
            } catch Error as _eLog {
            }
        }

        this._running := false
        this._paused := false
        this._stopRequested := false
        try {
            this.log.Write("✨ Ροή Ολοκληρώθηκε / Διακόπηκε")
        } catch Error as _eEnd {
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
        } catch Error as _eT {
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
        } catch Error as _eS {
        }
    }

    _run() {
        local profDir := "", profArg := "", hNew := 0
        this._checkAbortOrPause()

        ; Εύρεση φακέλου προφίλ
        try {
            this.log.Write(Format("🔎 Εύρεση Φακέλου Προφίλ Με Βάση Το Όνομα: {1}", Settings.EDGE_PROFILE_NAME))
        } catch Error as _eL1 {
        }

        profDir := this.edge.ResolveProfileDirByName(Settings.EDGE_PROFILE_NAME)
        if (profDir = "") {
            try {
                this.log.Write("⚠️ Ο Φάκελος Προφίλ Δεν Βρέθηκε — Θα Δοκιμάσω Με Χρήση Του Εμφανιζόμενου Ονόματος Ως Φάκελο")
            } catch Error as _eWarn1 {
            }
            profArg := "--profile-directory=" RegexLib.Str.Quote(Settings.EDGE_PROFILE_NAME)
            quotedName := RegexLib.Str.Quote(Settings.EDGE_PROFILE_NAME)
            warnMsg := Format("Δεν βρέθηκε φάκελος προφίλ για {1}. Θα δοκιμάσω με: {2}", quotedName, profArg)
            try {
                this.log.ShowTimed("Προειδοποίηση Προφίλ", warnMsg, "BH Automation — Προειδοποίηση", "Iconi")
            } catch Error as _eWarnPopup {
            }
        } else {
            try {
                this.log.Write(Format("📁 Φάκελος Προφίλ: {1}", profDir))
            } catch Error as _eL2 {
            }
            profArg := "--profile-directory=" RegexLib.Str.Quote(profDir)
        }
        profArg .= " --new-window"

        this.edge.StepDelay()
        this.edge.StepDelay()
        this._checkAbortOrPause()

        try {
            this.log.Write(Format("⏩ Edge New Window: {1}", profArg))
        } catch Error as _eL3 {
        }

        ; Άνοιγμα νέου παραθύρου
        hNew := this.edge.OpenNewWindow(profArg)
        if (!hNew) {
            try {
                this.log.Write("❌ Αποτυχία Ανοίγματος Νέου Παραθύρου Edge")
            } catch Error as _eL4 {
            }
            return
        }

        ; Καθυστέρηση μετά το Edge New Window
        try {
            this.log.SleepWithLog(Settings.MID_DELAY_MS, "μετά το Edge New Window")
        } catch Error as _eAfterOpen {
        }

        ; Προετοιμασία παραθύρου
        WinActivate("ahk_id " hNew)
        WinWaitActive("ahk_id " hNew, , 5)
        WinMaximize("ahk_id " hNew)
        Sleep(200)
        this.edge.StepDelay()

        try {
            quotedName := RegexLib.Str.Quote(Settings.EDGE_PROFILE_NAME)
            readyMsg := Format("Edge έτοιμο για χρήση ({1}).", quotedName)
            this.log.Write("✅ Edge Ready")
            this.log.ShowTimed("EdgeReady", readyMsg, "BH Automation — Edge", "Iconi")
        } catch Error as _eL5 {
        }

        this.edge.StepDelay()
        this.edge.NewTab(hNew)
        try {
            this.log.Write("➡️ Νέα Καρτέλα (Κενή)")
        } catch Error as _eL6 {
        }
        this.edge.CloseOtherTabsInNewWindow(hNew)
        try {
            this.log.Write("🧹 Καθαρισμός tabs: έκλεισα την άλλη καρτέλα στο νέο παράθυρο (παραμένει η τρέχουσα).")
        } catch Error as _eL7 {
        }

        ; Καθυστέρηση μετά τον καθαρισμό tabs
        try {
            this.log.SleepWithLog(Settings.MID_DELAY_MS, "μετά τον καθαρισμό tabs")
        } catch Error as _eAfterClean {
        }

        if (Settings.CLOSE_ALL_OTHER_WINDOWS) {
            this.edge.CloseAllOtherWindows(hNew)
            try {
                this.log.Write("🛠️ Κλείσιμο άλλων παραθύρων: ολοκληρώθηκε (CLOSE_ALL_OTHER_WINDOWS=true).")
            } catch Error as _eL8 {
            }
        }

        ; ενημερωτικό log για αποκλεισμό GUI κατά το sampling
        try {
            if (this.guiW > 0) {
                if (this.guiH > 0) {
                    this.log.Write(Format("🧭 Ενεργός αποκλεισμός GUI στο sampling: x={1} y={2} w={3} h={4}", this.guiX, this.guiY, this.guiW, this.guiH))
                }
            }
        } catch Error as _eLogGui {
        }

        ; =========================
        ; 🔁 Continuous loop (με FlowLoop)
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
        } catch Error as _eLoopBreak {
            ; stop/pause/exception καταλήγει εδώ
        }

        ; Μετά το τέλος του loop, χειρισμός παραθύρου
        if (!Settings.KEEP_EDGE_OPEN) {
            WinClose("ahk_id " hNew)
            WinWaitClose("ahk_id " hNew, , 5)
            this.edge.StepDelay()
            try {
                this.log.Write("✨ Ολοκλήρωση Κύκλου")
            } catch Error as _eLogEnd1 {
            }
        } else {
            try {
                this.log.Write("✨ Ολοκλήρωση Κύκλου (Παραμονή Παραθύρου)")
            } catch Error as _eLogEnd2 {
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
