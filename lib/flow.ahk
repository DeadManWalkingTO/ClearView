; ==================== lib/flow.ahk ====================
#Requires AutoHotkey v2.0
#Include "settings.ahk"

class FlowController {
    __New(log, edge, settings) {
        this.log := log
        this.edge := edge
        this.settings := settings
        this._running := false
        this._paused := false
        this._stopRequested := false
        ; Πίνακες λιστών IDs (φορτώνονται από LoadIdLists)
        this.list1 := []
        this.list2 := []
    }

    ; ---- Public API ----
    IsRunning() => this._running

    ; Φόρτωση IDs από τα αρχεία (καλείται στην εκκίνηση από main.ahk)
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

        this.log.ShowTimed(
            "Έναρξη",
            Format("Ξεκινάει η ροή αυτοματισμού — έκδοση: { }", Settings.APP_VERSION),
            "BH Automation — Έναρξη",
            "Iconi"
        )
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
        profileFound := (profDir != "")  ; σήμανση: βρέθηκε συγκεκριμένος φάκελος;

        if (profDir = "") {
            this.log.SetHeadline("⚠️ Δεν Βρέθηκε Φάκελος Για: " Settings.EDGE_PROFILE_NAME)
            this.log.Write("⚠️ Ο Φάκελος Προφίλ Δεν Βρέθηκε — Θα Δοκιμάσω Με Χρήση Του Εμφανιζόμενου Ονόματος Ως Φάκελο")
            profArg := '--profile-directory="' Settings.EDGE_PROFILE_NAME '"'
            warnMsg := Format('Δεν βρέθηκε φάκελος προφίλ για "{ }". Θα δοκιμάσω με: { }', Settings.EDGE_PROFILE_NAME, profArg)
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

        ; Popup (T=3s)
        readyMsg := Format('Edge έτοιμο για χρήση ("{ }").', Settings.EDGE_PROFILE_NAME)
        this.log.ShowTimed("EdgeReady", readyMsg, "BH Automation — Edge", "Iconi")
        this.edge.StepDelay()

        ; 3) Νέα καρτέλα (άρα το νέο παράθυρο έχει 2 tabs: default + νέα)
        this.edge.NewTab(hNew)
        this.log.SetHeadline("➡️ Νέα Καρτέλα Ανοιχτή — Προκαταρκτικός καθαρισμός"), this.log.Write("➡️ Νέα Καρτέλα (Κενή)")

        ; 3.1) ΠΡΩΤΑ: Κλείσιμο καρτελών/παραθύρων του ίδιου προφίλ (αν βρέθηκε)
        if (profileFound) {
            this.log.Write("🧹 Προκαταρκτικός καθαρισμός: κλείνω την «άλλη» καρτέλα στο νέο παράθυρο και όλα τα άλλα παράθυρα του ίδιου προφίλ.")
            ; i) Κλείσε την «άλλη» καρτέλα στο νέο παράθυρο (κρατά τη νέα)
            this.edge.CloseOtherTabsInNewWindow(hNew)
            ; ii) Κλείσε όλα τα άλλα παράθυρα του ίδιου profDir (άρα όλες οι καρτέλες τους)
            this.edge.CloseOtherWindowsOfProfile(profDir, hNew)
        } else {
            this.log.Write("ℹ️ Δεν βρέθηκε φάκελος — παραλείπω προκαταρκτικό κλείσιμο καρτελών/παραθύρων.")
        }

        ; 3.2) ΕΠΕΙΤΑ: Επιλογή λίστας με πιθανότητα & τυχαίο id, πλοήγηση + play
        this._navigateWithRandomId(hNew)

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
            txt := StrReplace(txt, "`r") ; Normalize CRLF/CR/LF -> LF
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

        this.log.Write(Format("🎲 Επιλέχθηκε λίστα: { } (rand={ }, prob={ }%), id={ }"
            , (useList1 ? "list1" : "list2"), r, prob, pick))

        ; Πλοήγηση
        this.edge.NavigateToUrl(hWnd, url)
        this.log.Write("🌐 Πλοήγηση σε: " url)

        ; Focus & Play με fallback
        this.edge.PlayYouTube(hWnd)
        this.log.Write("▶️ Αποστολή εντολής Play (k) με fallback")
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
