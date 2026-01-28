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

        ; Popup + log (T=3s)
        this.log.ShowTimed(
            "Start",
            Format("Ξεκινάει η ροή αυτοματισμού — έκδοση: {}", Settings.APP_VERSION),
            "BH Automation — Έναρξη",
            "Iconi"
        )
        this.log.SetHeadline("Εκκίνηση ροής…"), this.log.Write("Start pressed — " Settings.APP_VERSION)

        try {
            this._run()
        } catch as e {
            this.log.Write("Σφάλμα: " e.Message)
            this.log.SetHeadline("Σφάλμα: " e.Message)
        }

        this._running := false
        this._paused := false
        this._stopRequested := false
        this.log.SetHeadline("Έτοιμο."), this.log.Write("Ροή ολοκληρώθηκε / διακόπηκε")
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
        this.log.SetHeadline("Εύρεση φακέλου προφίλ…"), this.log.Write("Εύρεση φακέλου προφίλ με βάση το όνομα: " Settings.EDGE_PROFILE_NAME)

        profDir := this.edge.ResolveProfileDirByName(Settings.EDGE_PROFILE_NAME)
        if (profDir = "") {
            this.log.SetHeadline("⚠️ Δεν βρέθηκε φάκελος για: " Settings.EDGE_PROFILE_NAME)
            this.log.Write("Ο φάκελος προφίλ δεν βρέθηκε — θα δοκιμάσω με χρήση του εμφανιζόμενου ονόματος ως φάκελο")
            profArg := '--profile-directory="' Settings.EDGE_PROFILE_NAME '"'
            warnMsg := Format('Δεν βρέθηκε φάκελος προφίλ για "{}". Θα δοκιμάσω με: {}', Settings.EDGE_PROFILE_NAME, profArg)
            this.log.ShowTimed("ProfileWarn", warnMsg, "BH Automation — Προειδοποίηση", "Icon!")
        } else {
            this.log.SetHeadline("Βρέθηκε φάκελος: " profDir), this.log.Write("Φάκελος προφίλ: " profDir)
            profArg := '--profile-directory="' profDir '"'
        }
        profArg .= " --new-window"

        ; 2) Άνοιγμα νέου παραθύρου Edge
        this._checkAbortOrPause()
        this.log.SetHeadline("Άνοιγμα νέου παραθύρου Edge…"), this.log.Write("Open Edge New Window: " profArg)
        hNew := this.edge.OpenNewWindow(profArg)
        if (!hNew) {
            this.log.SetHeadline("❌ Αποτυχία ανοίγματος Edge."), this.log.Write("Αποτυχία ανοίγματος νέου παραθύρου Edge")
            return
        }

        WinActivate("ahk_id " hNew)
        WinWaitActive("ahk_id " hNew, , 5)
        WinMaximize("ahk_id " hNew)
        Sleep(200)
        this.log.SetHeadline("Edge έτοιμο (" Settings.EDGE_PROFILE_NAME ")"), this.log.Write("Edge Ready")

        ; Popup (T=3s)
        readyMsg := Format('Edge έτοιμο για χρήση ("{}").', Settings.EDGE_PROFILE_NAME)
        this.log.ShowTimed("EdgeReady", readyMsg, "BH Automation — Edge", "Iconi")

        ; 3) --- Κύρια λογική (παράδειγμα: άνοιγμα κενής καρτέλας) ---
        this.edge.NewTab(hNew)
        this.log.SetHeadline("Νέα καρτέλα ανοιχτή — καμία άλλη ενέργεια."), this.log.Write("Νέα Καρτέλα (Κενή)")

        ; 4) Κλείσιμο/Παραμονή παραθύρου
        if (!Settings.KEEP_EDGE_OPEN) {
            WinClose("ahk_id " hNew)
            WinWaitClose("ahk_id " hNew, , 5)
            this.log.SetHeadline("Κύκλος ολοκληρώθηκε."), this.log.Write("Ολοκλήρωση Κύκλου")
        } else {
            this.log.SetHeadline("Κύκλος ολοκληρώθηκε (Edge παραμένει ανοιχτός).")
            this.log.Write("Ολοκλήρωση Κύκλου (Keep Window Open)")
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
