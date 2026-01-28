; ==================== lib/flow.ahk ====================
#Requires AutoHotkey v2.0
#Include "settings.ahk"
#Include "cdp.ahk"

class FlowController {
    __New(log, edge, settings) {
        this.log := log
        this.edge := edge
        this.settings := settings
        this._running := false
        this._paused := false
        this._stopRequested := false
        this.list1 := []
        this.list2 := []
    }

    ; ---- Public API ----
    IsRunning() => this._running

    LoadIdLists() {
        this.list1 := this._readIdsFromFile(Settings.DATA_LIST_TXT)
        this.list2 := this._readIdsFromFile(Settings.DATA_RANDOM_TXT)
        this.log.Write("📥 Φόρτωση λιστών: list1=" this.list1.Length ", list2=" this.list2.Length)
    }

    StartRun() {
        if this._running
            return
        this._running := true
        this._paused := false
        this._stopRequested := false

        this.log.ShowTimed("Έναρξη"
            , Format("Ξεκινάει η ροή αυτοματισμού — έκδοση: {}", Settings.APP_VERSION)
            , "BH Automation — Έναρξη", "Iconi")
        this.log.SetHeadline("▶️ Εκκίνηση Ροής…"), this.log.Write("▶️ Έναρξη Πατήθηκε — " Settings.APP_VERSION)

        try {
            this._run()
        } catch as e {
            this.log.Write("❌ Σφάλμα: " e.Message)
            this.log.SetHeadline("❌ Σφάλμα: " e.Message)
        }

        this._running := false
        this._paused := false
        this._stopRequested := false
        this.log.SetHeadline("✅ Έτοιμο."), this.log.Write("✨ Ροή Ολοκληρώθηκε / Διακόπηκε")
    }

    TogglePause() {
        if !this._running
            return false
        this._paused := !this._paused
        return this._paused
    }

    RequestStop() {
        this._stopRequested := true
    }

    ; ---- Core flow ----
    _run() {
        ; 1) Εντοπισμός φακέλου προφίλ
        this._checkAbortOrPause()
        this.log.SetHeadline("🔎 Εύρεση Φακέλου Προφίλ…"), this.log.Write("🔎 Εύρεση Φακέλου Προφίλ Με Βάση Το Όνομα: " Settings.EDGE_PROFILE_NAME)
        profDir := this.edge.ResolveProfileDirByName(Settings.EDGE_PROFILE_NAME)
        if (profDir = "") {
            this.log.SetHeadline("⚠️ Δεν Βρέθηκε Φάκελος Για: " Settings.EDGE_PROFILE_NAME)
            this.log.Write("⚠️ Ο Φάκελος Προφίλ Δεν Βρέθηκε — Θα Δοκιμάσω Με Χρήση Του Εμφανιζόμενου Ονόματος Ως Φάκελο")
            profArg := '--profile-directory="' Settings.EDGE_PROFILE_NAME '"'
            warnMsg := Format('Δεν βρέθηκε φάκελος προφίλ για "{}". Θα δοκιμάσω με: {}', Settings.EDGE_PROFILE_NAME, profArg)
            this.log.ShowTimed("Προειδοποίηση Προφίλ", warnMsg, "BH Automation — Προειδοποίηση", "Icon!")
        } else {
            this.log.SetHeadline("📁 Βρέθηκε Φάκελος: " profDir), this.log.Write("📁 Φάκελος Προφίλ: " profDir)
            profArg := '--profile-directory="' profDir '"'
        }
        profArg .= " --new-window"
        this.edge.StepDelay()

        ; 2) Άνοιγμα νέου παραθύρου Edge
        this._checkAbortOrPause()
        this.log.SetHeadline("⏩ Άνοιγμα Νέου Παραθύρου Edge…"), this.log.Write("⏩ Edge New Window: " profArg)
        hNew := this.edge.OpenNewWindow(profArg)
        if (!hNew) {
            this.log.SetHeadline("❌ Αποτυχία Ανοίγματος Edge."), this.log.Write("❌ Αποτυχία Ανοίγματος Νέου Παραθύρου Edge")
            return
        }
        WinActivate("ahk_id " hNew)
        WinWaitActive("ahk_id " hNew, , 5)
        WinMaximize("ahk_id " hNew)
        Sleep(200)
        this.edge.StepDelay()
        this.log.SetHeadline("✅ Edge Έτοιμο (" Settings.EDGE_PROFILE_NAME ")"), this.log.Write("✅ Edge Ready")
        readyMsg := Format('Edge έτοιμο για χρήση ("{}").', Settings.EDGE_PROFILE_NAME)
        this.log.ShowTimed("EdgeReady", readyMsg, "BH Automation — Edge", "Iconi")
        this.edge.StepDelay()

        ; 3) Νέα καρτέλα (το νέο παράθυρο έχει τώρα 2 tabs)
        this.edge.NewTab(hNew)
        this.log.SetHeadline("➡️ Νέα Καρτέλα Ανοιχτή"), this.log.Write("➡️ Νέα Καρτέλα (Κενή)")

        ; 3.1) Ασφαλής καθαρισμός — κλείνω ΜΟΝΟ την «άλλη» καρτέλα
        this.edge.CloseOtherTabsInNewWindow(hNew)
        this.log.Write("🧹 Καθαρισμός tabs: έκλεισα την άλλη καρτέλα στο νέο παράθυρο (παραμένει η τρέχουσα).")

        ; 3.2) Προαιρετικά: κλείσιμο όλων των άλλων παραθύρων
        if (Settings.CLOSE_ALL_OTHER_WINDOWS) {
            this.edge.CloseAllOtherWindows(hNew)
            this.log.Write("🛠️ Κλείσιμο άλλων παραθύρων: ολοκληρώθηκε (CLOSE_ALL_OTHER_WINDOWS=true).")
        }

        ; 3.3) Επιλογή λίστας & πλοήγηση + play
        this._navigateWithRandomId(hNew)

        ; --- CDP: Ανάγνωση διάρκειας από το ενεργό YouTube tab
        if (Settings.CDP_ENABLED) {
            try {
                cdp := CDP(Settings.CDP_PORT)
                if (cdp.ConnectToYouTubeTab()) {
                    dur := cdp.GetYouTubeDurationSeconds()
                    if (dur >= 0) {
                        this.log.Write("⏱️ Διάρκεια βίντεο (s): " dur)
                    } else {
                        this.log.Write("⚠️ CDP: δεν βρέθηκε διάρκεια (ytp-time-duration)")
                    }
                    cdp.Disconnect()
                } else {
                    this.log.Write("⚠️ CDP: αποτυχία σύνδεσης στο YouTube tab")
                }
            } catch Error as e {
                this.log.Write("⚠️ CDP σφάλμα: " e.Message)
            }
        }

        ; 4) Κλείσιμο/Παραμονή παραθύρου
        if (!Settings.KEEP_EDGE_OPEN) {
            WinClose("ahk_id " hNew)
            WinWaitClose("ahk_id " hNew, , 5)
            this.edge.StepDelay()
            this.log.SetHeadline("✨ Κύκλος Ολοκληρώθηκε."), this.log.Write("✨ Ολοκλήρωση Κύκλου")
        } else {
            this.log.SetHeadline("✨ Κύκλος Ολοκληρώθηκε (Edge Παραμένει Ανοιχτός).")
            this.log.Write("✨ Ολοκλήρωση Κύκλου (Παραμονή Παραθύρου)")
        }
    }

    ; ---- Internals ----
    _readIdsFromFile(path) {
        arr := []
        try {
            txt := FileRead(path, "UTF-8")
        } catch Error as e {
            txt := ""
        }
        if (txt != "") {
            txt := StrReplace(txt, "`r")
            for line in StrSplit(txt, "`n") {
                id := Trim(line)
                if (id != "")
                    arr.Push(id)
            }
        }
        return arr
    }

    _navigateWithRandomId(hWnd) {
        prob := Settings.LIST1_PROB_PCT
        r := Random(0, 100)
        useList1 := (r < prob)
        sel := (useList1 ? this.list1 : this.list2)
        if (sel.Length = 0)
            sel := (useList1 ? this.list2 : this.list1)
        if (sel.Length = 0) {
            this.log.Write("⚠️ Καμία λίστα διαθέσιμη (list1/list2 κενές) — παραμένω στην κενή καρτέλα.")
            return
        }
        idx := Random(1, sel.Length)
        pick := sel[idx]
        url := "https://www.youtube.com/watch?v=" pick

        this.log.Write(Format("🎲 Επιλέχθηκε λίστα: {} (rand={}, prob={}% ), id={}"
            , (useList1 ? "list1" : "list2"), r, prob, pick))

        ; --- Πλοήγηση ---
        this.edge.NavigateToUrl(hWnd, url)
        this.log.Write("🌐 Πλοήγηση σε: " url)

        ; >>> Καθυστέρηση με logging (μεγάλο step) <<<
        this.log.SleepWithLog(Settings.STEP_DELAY_MS, "μετά την πλοήγηση")

        ; --- Play ---
        this.edge.PlayYouTube(hWnd)
        this.log.Write("▶️ Αποστολή εντολής Play (k) με pre-click")

        ; >>> Καθυστέρηση με logging (μεγάλο step) <<<
        this.log.SleepWithLog(Settings.STEP_DELAY_MS, "μετά το play")
    }

    _checkAbortOrPause() {
        while this._paused {
            Sleep(150)
        }
        if this._stopRequested
            throw Error("Stopped by user")
    }
}
; ==================== End Of File ====================
