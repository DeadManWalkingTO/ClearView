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
    }

    ; ---- Public API ----
    IsRunning() => this._running

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
        profileFound := (profDir != "")  ; ΝΕΟ: Σήμανση αν όντως βρέθηκε προφίλ

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

        ; 3) Κύρια λογική (νέα καρτέλα)
        this.edge.NewTab(hNew)
        this.log.SetHeadline("➡️ Νέα Καρτέλα Ανοιχτή — Καμία Άλλη Ενέργεια."), this.log.Write("➡️ Νέα Καρτέλα (Κενή)")

        ; 3.1) ΝΕΑ ΛΟΓΙΚΗ ΓΙΑ ΚΑΡΤΕΛΕΣ/ΠΑΡΑΘΥΡΑ ΙΔΙΟΥ ΠΡΟΦΙΛ
        if (profileFound) {
            this.log.Write("🧹 Βρέθηκε προφίλ — κρατώ τη νέα καρτέλα στο νέο παράθυρο & κλείνω όλες τις καρτέλες των άλλων παραθύρων του ίδιου προφίλ.")
            ; i) Κλείσε την «άλλη» καρτέλα στο νέο παράθυρο (κρατά τη νέα)
            this.edge.CloseOtherTabsInNewWindow(hNew)
            ; ii) Κλείσε όλα τα άλλα παράθυρα του ίδιου profDir (άρα όλες οι καρτέλες τους)
            this.edge.CloseOtherWindowsOfProfile(profDir, hNew)
        } else {
            this.log.Write("ℹ️ Δεν βρέθηκε προφίλ — ΔΕΝ κλείνω άλλες καρτέλες/παράθυρα.")
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

    _checkAbortOrPause() {
        while this._paused {
            Sleep(150)
        }
        if this._stopRequested
            throw Error("Stopped by user")
    }
}
; ==================== End Of File ====================
