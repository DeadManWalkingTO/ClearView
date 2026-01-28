; ==================== lib/flow.ahk ====================
#Requires AutoHotkey v2.0
#Include "settings.ahk"
#Include "regex.ahk"
#Include "edge.ahk"
#Include "cdp.ahk"
#Include "cdp_diag.ahk"

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

  IsRunning() => this._running

  ; Φόρτωση λιστών βίντεο (IDs)
  LoadIdLists() {
    this.list1 := this._readIdsFromFile(Settings.DATA_LIST_TXT)
    this.list2 := this._readIdsFromFile(Settings.DATA_RANDOM_TXT)
    try {
      this.log.Write(Format("📥 Φόρτωση λιστών: list1={}, list2={}", this.list1.Length, this.list2.Length))
    } catch Error as _e {
      ; no-op
    }
  }

  ; Έναρξη κύκλου ροής
  StartRun() {
    if this._running {
      try {
        this.log.SetHeadline("ℹ️ Ήδη Εκτελείται.")
        this.log.Write("ℹ️ Αγνοήθηκε")
      } catch Error as _e {
        ; no-op
      }
      return
    }

    this._running := true
    this._paused := false
    this._stopRequested := false

    try {
      this.log.ShowTimed(
        "Έναρξη",
        Format("Ξεκινάει η ροή αυτοματισμού — έκδοση: {}", Settings.APP_VERSION),
        "BH Automation — Έναρξη",
        "Iconi"
      )
      this.log.SetHeadline("▶️ Εκκίνηση Ροής…")
      this.log.Write(Format("▶️ Έναρξη Πατήθηκε — {}", Settings.APP_VERSION))
    } catch Error as _e {
      ; no-op
    }

    try {
      this._run()
    } catch Error as e {
      try {
        this.log.Write(Format("❌ Σφάλμα Ροής: {} — What={}, File={}, Line={}", e.Message, e.What, e.File, e.Line))
        this.log.SetHeadline(Format("❌ Σφάλμα: {}", e.Message))
      } catch Error as _e2 {
        ; no-op
      }
    }

    this._running := false
    this._paused := false
    this._stopRequested := false

    try {
      this.log.SetHeadline("✅ Έτοιμο.")
      this.log.Write("✨ Ροή Ολοκληρώθηκε / Διακόπηκε")
    } catch Error as _e3 {
      ; no-op
    }
  }

  TogglePause() {
    if !this._running {
      return false
    }
    this._paused := !this._paused
    return this._paused
  }

  RequestStop() {
    this._stopRequested := true
  }

  ; ---------------- Κύριος βρόχος ροής ----------------
  _run() {
    local profDir := "", profArg := "", hNew := 0

    this._checkAbortOrPause()

    try {
      this.log.SetHeadline("🔎 Εύρεση Φακέλου Προφίλ…")
      this.log.Write(Format("🔎 Εύρεση Φακέλου Προφίλ Με Βάση Το Όνομα: {}", Settings.EDGE_PROFILE_NAME))
    } catch Error as _e {
      ; no-op
    }

    ; Βρες φάκελο προφίλ
    profDir := this.edge.ResolveProfileDirByName(Settings.EDGE_PROFILE_NAME)
    if (profDir = "") {
      try {
        this.log.SetHeadline(Format("⚠️ Δεν Βρέθηκε Φάκελος Για: {}", Settings.EDGE_PROFILE_NAME))
        this.log.Write("⚠️ Ο Φάκελος Προφίλ Δεν Βρέθηκε — Θα Δοκιμάσω Με Χρήση Του Εμφανιζόμενου Ονόματος Ως Φάκελο")
      } catch Error as _e {
        ; no-op
      }

      profArg := "--profile-directory=" RegexLib.Str.Quote(Settings.EDGE_PROFILE_NAME)

      ; Ασφαλής quoted εμφάνιση ονόματος με RegexLib.Str.Quote(...)
      quotedName := RegexLib.Str.Quote(Settings.EDGE_PROFILE_NAME)
      warnMsg := Format("Δεν βρέθηκε φάκελος προφίλ για {}. Θα δοκιμάσω με: {}", quotedName, profArg)

      try {
        this.log.ShowTimed("Προειδοποίηση Προφίλ", warnMsg, "BH Automation — Προειδοποίηση", "Iconi")
      } catch Error as _e2 {
        ; no-op
      }
    } else {
      try {
        this.log.SetHeadline(Format("📁 Βρέθηκε Φάκελος: {}", profDir))
        this.log.Write(Format("📁 Φάκελος Προφίλ: {}", profDir))
      } catch Error as _e {
        ; no-op
      }
      profArg := "--profile-directory=" RegexLib.Str.Quote(profDir)
    }

    ; Νέο παράθυρο + Remote Debugging αν είναι ενεργό
    profArg .= " --new-window"
    if (Settings.CDP_ENABLED) {
      profArg .= " --remote-debugging-port=" Settings.CDP_PORT
    }

    this.edge.StepDelay()
    this._checkAbortOrPause()

    try {
      this.log.SetHeadline("⏩ Άνοιγμα Νέου Παραθύρου Edge…")
      this.log.Write(Format("⏩ Edge New Window: {}", profArg))
    } catch Error as _e {
      ; no-op
    }

    hNew := this.edge.OpenNewWindow(profArg)
    if (!hNew) {
      try {
        this.log.SetHeadline("❌ Αποτυχία Ανοίγματος Edge.")
        this.log.Write("❌ Αποτυχία Ανοίγματος Νέου Παραθύρου Edge")
      } catch Error as _e {
        ; no-op
      }
      return
    }

    ; Προετοιμασία νέου παραθύρου
    WinActivate("ahk_id " hNew)
    WinWaitActive("ahk_id " hNew, , 5)
    WinMaximize("ahk_id " hNew)
    Sleep(200)
    this.edge.StepDelay()

    try {
      quotedName := RegexLib.Str.Quote(Settings.EDGE_PROFILE_NAME)
      readyMsg := Format("Edge έτοιμο για χρήση ({}).", quotedName)

      this.log.SetHeadline(Format("✅ Edge Έτοιμο ({})", Settings.EDGE_PROFILE_NAME))
      this.log.Write("✅ Edge Ready")
      this.log.ShowTimed("EdgeReady", readyMsg, "BH Automation — Edge", "Iconi")
    } catch Error as _e {
      ; no-op
    }

    ; Νέα καρτέλα & καθαρισμός
    this.edge.StepDelay()
    this.edge.NewTab(hNew)
    try {
      this.log.SetHeadline("➡️ Νέα Καρτέλα Ανοιχτή")
      this.log.Write("➡️ Νέα Καρτέλα (Κενή)")
    } catch Error as _e {
      ; no-op
    }
    this.edge.CloseOtherTabsInNewWindow(hNew)
    try {
      this.log.Write("🧹 Καθαρισμός tabs: έκλεισα την άλλη καρτέλα στο νέο παράθυρο (παραμένει η τρέχουσα).")
    } catch Error as _e {
      ; no-op
    }

    if (Settings.CLOSE_ALL_OTHER_WINDOWS) {
      this.edge.CloseAllOtherWindows(hNew)
      try {
        this.log.Write("🛠️ Κλείσιμο άλλων παραθύρων: ολοκληρώθηκε (CLOSE_ALL_OTHER_WINDOWS=true).")
      } catch Error as _e {
        ; no-op
      }
    }

    ; --- Πλοήγηση + σταθεροποίηση για Play ---
    this._navigateWithRandomId(hNew)

    ; --- (Προαιρετικό) Διαγνωστικό πριν το CDP connect ---
    try {
      CDP_DiagProbe(Settings.CDP_PORT, this.log, 8000, 300)
    } catch Error as _eProbe {
      ; no-op
    }

    ; --- Προαιρετικό CDP: υπολογισμός διάρκειας βίντεο ---
    local cdpInst := 0, dur := -1
    if (Settings.CDP_ENABLED) {
      try {
        cdpInst := CDP_Create(Settings.CDP_PORT)  ; factory για linters
        if (cdpInst.ConnectToYouTubeTab()) {
          dur := cdpInst.GetYouTubeDurationSeconds()
          if (dur >= 0) {
            this.log.Write(Format("⏱️ Διάρκεια βίντεo (s): {}", dur))
          } else {
            this.log.Write("⚠️ CDP: δεν βρέθηκε διάρκεια (ytp-time-duration)")
          }
          cdpInst.Disconnect()
        } else {
          this.log.Write("⚠️ CDP: αποτυχία σύνδεσης στο YouTube tab")
        }
      } catch Error as e {
        this.log.SafeErrorLog("⚠️ CDP σφάλμα:", e)
        cdpInst := 0
        dur := -1
      }
    }

    ; Τερματισμός κύκλου
    if (!Settings.KEEP_EDGE_OPEN) {
      WinClose("ahk_id " hNew)
      WinWaitClose("ahk_id " hNew, , 5)
      this.edge.StepDelay()
      try {
        this.log.SetHeadline("✨ Κύκλος Ολοκληρώθηκε.")
        this.log.Write("✨ Ολοκλήρωση Κύκλου")
      } catch Error as _e {
        ; no-op
      }
    } else {
      try {
        this.log.SetHeadline("✨ Κύκλος Ολοκληρώθηκε (Edge Παραμένει Ανοιχτός).")
        this.log.Write("✨ Ολοκλήρωση Κύκλου (Παραμονή Παραθύρου)")
      } catch Error as _e {
        ; no-op
      }
    }
  }

  ; ---------------- Βοηθητικά ----------------

  ; Ανάγνωση IDs από αρχείο (ένα ανά γραμμή, UTF-8)
  _readIdsFromFile(path) {
    arr := []
    txt := ""
    try {
      txt := FileRead(path, "UTF-8")
    } catch Error as _e {
      txt := ""
    }
    if (txt != "") {
      txt := StrReplace(txt, "`r")
      for line in StrSplit(txt, "`n") {
        id := Trim(line)
        if (id != "") {
          arr.Push(id)
        }
      }
    }
    return arr
  }

  ; Επιλογή τυχαίου ID και πλοήγηση στο YouTube
  _navigateWithRandomId(hWnd) {
    prob := Settings.LIST1_PROB_PCT
    r := Random(0, 100)
    useList1 := (r < prob)

    sel := (useList1 ? this.list1 : this.list2)
    if (sel.Length = 0) {
      sel := (useList1 ? this.list2 : this.list1)
    }
    if (sel.Length = 0) {
      try {
        this.log.Write("⚠️ Καμία λίστα διαθέσιμη (list1/list2 κενές) — παραμένω στην κενή καρτέλα.")
      } catch Error as _e {
        ; no-op
      }
      return
    }

    idx := Random(1, sel.Length)
    pick := sel[idx]

    ; Σύνθεση URL
    url := "https://www.youtube.com/watch?v=" pick

    try {
      this.log.Write(Format("🎲 Επιλέχθηκε λίστα: {} (rand={}, prob={}%), id={}", (useList1 ? "list1" : "list2"), r, prob, pick))
    } catch Error as _e {
      ; no-op
    }

    this.edge.NavigateToUrl(hWnd, url)

    try {
      this.log.Write(Format("🌐 Πλοήγηση σε: {}", url))
    } catch Error as _e {
      ; no-op
    }

    ; Επιπλέον σταθεροποίηση πριν το Play
    try {
      this.log.SleepWithLog(Settings.STEP_DELAY_MS, "μετά την πλοήγηση")
    } catch Error as _e {
      ; no-op
    }

    ; Play με 2 φάσεις για αξιοπιστία
    this.edge.PlayYouTube(hWnd, true)

    try {
      this.log.Write("▶️ Αποστολή εντολής Play (k) με pre-click")
      this.log.SleepWithLog(Settings.STEP_DELAY_MS, "μετά το play")
    } catch Error as _e {
      ; no-op
    }
  }

  ; Έλεγχος παύσης/τερματισμού
  _checkAbortOrPause() {
    while this._paused {
      Sleep(150)
    }
    if this._stopRequested {
      throw Error("Stopped by user")
    }
  }
}
; ==================== End Of File ====================
