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
        this.log.SetHeadline("✅ Edge Έτοιμο (" Settings.EDGE_PROFILE_NAME ")"), this.log.Write("✅ Edge Ready")

        ; Popup (T=3s)
        readyMsg := Format('Edge έτοιμο για χρήση ("{ }").', Settings.EDGE_PROFILE_NAME)
        this.log.ShowTimed("EdgeReady", readyMsg, "BH Automation — Edge", "Iconi")

        ; 3) Νέα καρτέλα
        this.edge.NewTab(hNew)
        this.log.SetHeadline("➡️ Νέα Καρτέλα Ανοιχτή — Φόρτωση ID"), this.log.Write("➡️ Νέα Καρτέλα (Κενή)")

        ; 3.1) Επιλογή λίστας με πιθανότητα & τυχαίο id, πλοήγηση
        this._navigateWithRandomId(hNew)

        ; 3.2) Λογική tabs: ΜΟΝΟ όταν έχουμε το σωστό προφίλ (βρέθηκε φάκελος)
        if (profileFound) {
            this.log.Write("🧹 Βρέθηκε προφίλ — κρατώ τη νέα καρτέλα στο νέο παράθυρο & κλείνω όλες τις καρτέλες των άλλων παραθύρων του ίδιου προφίλ.")
            this.edge.CloseOtherTabsInNewWindow(hNew)
            this.edge.CloseOtherWindowsOfProfile(profDir, hNew)
        } else {
            this.log.Write("ℹ️ Δεν βρέθηκε φάκελος — ΔΕΝ κλείνω άλλες καρτέλες/παράθυρα.")
        }

        ; 4) Κλείσιμο/Παραμονή παραθύρου
        if (!Settings.KEEP_EDGE_OPEN) {
            WinClose("ahk_id " hNew)
            WinWaitClose("ahk_id " hNew, , 5)
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
            ; Normalize CRLF/CR/LF -> LF
            txt := StrReplace(txt, "`r")
            for line in StrSplit(txt, "`n") {
                id := Trim(line)
                if (id != "")
                    arr.Push(id)
            }
        } catch as e {
            this.log.Write("❌ Σφάλμα ανάγνωσης " path ": " e.Message)
        }
        return arr
    }

    _navigateWithRandomId(hWnd) {
        ; Επιλογή λίστας με πιθανότητα LIST1_PROB_PCT (0–100)
        prob := Settings.LIST1_PROB_PCT
        r := Random(0, 100)
        useList1 := (r < prob)

        sel := (useList1 ? this.list1 : this.list2)
        if (sel.Length = 0) {
            ; Αν η επιλεγμένη λίστα είναι κενή, δοκίμασε την άλλη
            sel := (useList1 ? this.list2 : this.list1)
        }
        if (sel.Length = 0) {
            this.log.Write("⚠️ Καμία λίστα διαθέσιμη (list1/list2 κενές) — παραμένω στην κενή καρτέλα.")
            return
        }

        idx := Random(1, sel.Length)  ; integer index
        pick := sel[idx]
        url := "https://www.youtube.com/watch?v=" pick

        this.log.Write(Format("🎲 Επιλέχθηκε λίστα: { } (rand={ }, prob={ }%), id={ }"
            , (useList1 ? "list1" : "list2"), r, prob, pick))

        ; Πλοήγηση
        this.edge.NavigateToUrl(hWnd, url)
        this.log.Write("🌐 Πλοήγηση σε: " url)

        ; --- ΝΕΟ: Focus & Play στο YouTube (k), με fallback click ---
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
