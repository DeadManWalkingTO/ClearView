; ==================== lib/flow.ahk ====================
#Requires AutoHotkey v2.0
#Include "settings.ahk"
#Include "regex.ahk"
#Include "edge.ahk"
; ❌ Δεν υπάρχει λογική διάρκειας (έχει αφαιρεθεί)

class FlowController {
  __New(log, edge, settings) {
    this.log := log
    this.edge := edge
    this.settings := settings
    this._running := false
    this._paused := false
    this._stopRequested := false
    this._cycleCount := 0            ; Μετρητής κύκλων
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
      }
      return
    }

    this._running := true
    this._paused := false
    this._stopRequested := false
    this._cycleCount := 0

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
    }

    try {
      this._run()
    } catch Error as e {
      try {
        this.log.Write(Format("❌ Σφάλμα Ροής: {} — What={}, File={}, Line={}", e.Message, e.What, e.File, e.Line))
        this.log.SetHeadline(Format("❌ Σφάλμα: {}", e.Message))
      } catch Error as _e2 {
      }
    }

    this._running := false
    this._paused := false
    this._stopRequested := false

    try {
      this.log.SetHeadline("✅ Έτοιμο.")
      this.log.Write("✨ Ροή Ολοκληρώθηκε / Διακόπηκε")
    } catch Error as _e3 {
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
    }

    ; Βρες φάκελο προφίλ
    profDir := this.edge.ResolveProfileDirByName(Settings.EDGE_PROFILE_NAME)
    if (profDir = "") {
      try {
        this.log.SetHeadline(Format("⚠️ Δεν Βρέθηκε Φάκελος Για: {}", Settings.EDGE_PROFILE_NAME))
        this.log.Write("⚠️ Ο Φάκελος Προφίλ Δεν Βρέθηκε — Θα Δοκιμάσω Με Χρήση Του Εμφανιζόμενου Ονόματος Ως Φάκελο")
      } catch Error as _e {
      }

      profArg := "--profile-directory=" RegexLib.Str.Quote(Settings.EDGE_PROFILE_NAME)

      quotedName := RegexLib.Str.Quote(Settings.EDGE_PROFILE_NAME)
      warnMsg := Format("Δεν βρέθηκε φάκελος προφίλ για {}. Θα δοκιμάσω με: {}", quotedName, profArg)
      try {
        this.log.ShowTimed("Προειδοποίηση Προφίλ", warnMsg, "BH Automation — Προειδοποίηση", "Iconi")
      } catch Error as _e2 {
      }
    } else {
      try {
        this.log.SetHeadline(Format("📁 Βρέθηκε Φάκελος: {}", profDir))
        this.log.Write(Format("📁 Φάκελος Προφίλ: {}", profDir))
      } catch Error as _e {
      }
      profArg := "--profile-directory=" RegexLib.Str.Quote(profDir)
    }

    ; Νέο παράθυρο
    profArg .= " --new-window"

    this.edge.StepDelay()
    this._checkAbortOrPause()

    try {
      this.log.SetHeadline("⏩ Άνοιγμα Νέου Παραθύρου Edge…")
      this.log.Write(Format("⏩ Edge New Window: {}", profArg))
    } catch Error as _e {
    }

    hNew := this.edge.OpenNewWindow(profArg)
    if (!hNew) {
      try {
        this.log.SetHeadline("❌ Αποτυχία Ανοίγματος Edge.")
        this.log.Write("❌ Αποτυχία Ανοίγματος Νέου Παραθύρου Edge")
      } catch Error as _e {
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
    }

    ; Νέα καρτέλα & καθαρισμός
    this.edge.StepDelay()
    this.edge.NewTab(hNew)
    try {
      this.log.SetHeadline("➡️ Νέα Καρτέλα Ανοιχτή")
      this.log.Write("➡️ Νέα Καρτέλα (Κενή)")
    } catch Error as _e {
    }
    this.edge.CloseOtherTabsInNewWindow(hNew)
    try {
      this.log.Write("🧹 Καθαρισμός tabs: έκλεισα την άλλη καρτέλα στο νέο παράθυρο (παραμένει η τρέχουσα).")
    } catch Error as _e {
    }

    if (Settings.CLOSE_ALL_OTHER_WINDOWS) {
      this.edge.CloseAllOtherWindows(hNew)
      try {
        this.log.Write("🛠️ Κλείσιμο άλλων παραθύρων: ολοκληρώθηκε (CLOSE_ALL_OTHER_WINDOWS=true).")
      } catch Error as _e {
      }
    }

    ; ---------------- Continuous loop: Πλοήγηση+Play → Αναμονή → επανάληψη ----------------
    try {
      loop {
        this._checkAbortOrPause()

        ; Πληροφορίες κύκλου
        this._cycleCount += 1
        cycleNo := this._cycleCount
        startTs := FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss")

        ; Επικεφαλίδα GUI με αρίθμηση κύκλου
        try {
          this.log.SetHeadline(Format("🔄 Κύκλος #{} σε εξέλιξη…", cycleNo))
        } catch Error as _eHead1 {
        }

        ; Επιλογή τυχαίου βίντεο & logs
        info := this._pickRandomVideo(hNew)  ; {useList1, id, url, r, prob}
        try {
          lst := (info.useList1 ? "list1" : "list2")
          this.log.Write(Format("📑 Κύκλος #{} — {} | rand={} | prob={}%", cycleNo, lst, info.r, info.prob))
          this.log.Write(Format("🆔 ID: {} | 🕒 start={}", info.id, startTs))
          this.log.Write(Format("🌐 Πλοήγηση σε: {}", info.url))
        } catch Error as _eHdr {
        }

        ; Πλοήγηση & Play
        this.edge.NavigateToUrl(hNew, info.url)
        try {
          this.log.SleepWithLog(Settings.STEP_DELAY_MS, "μετά την πλοήγηση")
        } catch Error as _eSlp1 {
        }
        this.edge.PlayYouTube(hNew, true)
        try {
          this.log.Write("▶️ Αποστολή εντολής Play (k) με pre-click")
          this.log.SleepWithLog(Settings.STEP_DELAY_MS, "μετά το play")
        } catch Error as _eSlp2 {
        }

        ; --- Τυχαία αναμονή ακριβώς σε ms ---
        waitMs := this._computeRandomWaitMs()
        try {
          this.log.Write(Format("⏳ Αναμονή ακριβώς {} ms ({}) — κύκλος #{}", waitMs, this._fmtDurationMs(waitMs), cycleNo))
          this.log.SetHeadline(Format("⏳ Αναμονή {} ms ({}) — Κύκλος #{}", waitMs, this._fmtDurationMs(waitMs), cycleNo))
        } catch Error as _eLogWait {
        }
        this._sleepRespectingPauseStop(waitMs, "αναμονή μεταξύ βίντεο")

        ; Τέλος κύκλου — ενημέρωση header
        try {
          this.log.Write(Format("🟢 Τέλος Κύκλου #{}", cycleNo))
          this.log.SetHeadline(Format("🟢 Τέλος Κύκλου #{}", cycleNo))
        } catch Error as _eEnd {
        }
      }
    } catch Error as _eLoop {
      ; Σπάσιμο βρόχου: "Stopped by user" ή άλλο σφάλμα — StartRun() θα γράψει λεπτομέρειες.
    }

    ; Τερματισμός κύκλου: κλείσιμο ή παραμονή παραθύρου
    if (!Settings.KEEP_EDGE_OPEN) {
      WinClose("ahk_id " hNew)
      WinWaitClose("ahk_id " hNew, , 5)
      this.edge.StepDelay()
      try {
        this.log.SetHeadline("✨ Κύκλος Ολοκληρώθηκε.")
        this.log.Write("✨ Ολοκλήρωση Κύκλου")
      } catch Error as _e {
      }
    } else {
      try {
        this.log.SetHeadline("✨ Κύκλος Ολοκληρώθηκε (Edge Παραμένει Ανοιχτός).")
        this.log.Write("✨ Ολοκλήρωση Κύκλου (Παραμονή Παραθύρου)")
      } catch Error as _e {
      }
    }
  }

  ; ---------------- Βοηθητικά ----------------

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

  _pickRandomVideo(hWnd) {
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
      }
      return { useList1: false, id: "", url: "about:blank", r: r, prob: prob }
    }

    idx := Random(1, sel.Length)
    pick := sel[idx]
    url := "https://www.youtube.com/watch?v=" pick
    return { useList1: useList1, id: pick, url: url, r: r, prob: prob }
  }

  ; Υπολογισμός τυχαίας αναμονής σε ms (ακριβές, με fallback στα λεπτά)
  _computeRandomWaitMs() {
    minMs := 0, maxMs := 0
    ; Πρώτα δοκίμασε τα Settings σε ms
    try {
      minMs := Settings.LOOP_MIN_MS + 0
    } catch Error as _e1 {
      minMs := 0
    }
    try {
      maxMs := Settings.LOOP_MAX_MS + 0
    } catch Error as _e2 {
      maxMs := 0
    }

    if (minMs > 0) {
      if (maxMs > 0) {
        if (maxMs < minMs) {
          tmp := minMs, minMs := maxMs, maxMs := tmp
        }
        try {
          return Round(Random(minMs, maxMs))
        } catch Error as _eRandMs {
          ; θα συνεχίσουμε με fallback στα λεπτά
        }
      }
    }

    ; Fallback: υπολόγισε από λεπτά
    minMin := 0, maxMin := 0
    try {
      minMin := Settings.LOOP_MIN_MINUTES + 0
    } catch Error as _e3 {
      minMin := 5
    }
    try {
      maxMin := Settings.LOOP_MAX_MINUTES + 0
    } catch Error as _e4 {
      maxMin := 10
    }
    if (maxMin < minMin) {
      tmp2 := minMin, minMin := maxMin, maxMin := tmp2
    }
    try {
      rndMin := Random(minMin, maxMin)
    } catch Error as _eRandMin {
      rndMin := minMin
    }
    return Floor(rndMin * 60000)
  }

  ; Μορφοποίηση ms σε "Mm Ss mmmms" (π.χ. "8m 57s 428ms")
  _fmtDurationMs(ms) {
    total := ms + 0
    if (total < 0) {
      total := 0
    }
    m := Floor(total / 60000)
    rem := Mod(total, 60000)
    s := Floor(rem / 1000)
    msRem := Mod(rem, 1000)

    ; Μηδενικά για αναγνωσιμότητα
    sTxt := s < 10 ? "0" s : "" s
    msTxt := ""
    if (msRem < 10) {
      msTxt := "00" msRem
    } else {
      if (msRem < 100) {
        msTxt := "0" msRem
      } else {
        msTxt := "" msRem
      }
    }
    return m "m " sTxt "s " msTxt "ms"
  }

  ; Αναμονή που σέβεται Παύση/Τερματισμό
  _sleepRespectingPauseStop(ms, label := "") {
    chunk := 500
    elapsed := 0
    try {
      if (label != "") {
        this.log.Write(Format("⏳ Αναμονή σε εξέλιξη ({} ms — {})", ms, label))
      } else {
        this.log.Write(Format("⏳ Αναμονή σε εξέλιξη ({} ms)", ms))
      }
    } catch Error as _eStartLog {
    }

    while (elapsed < ms) {
      while this._paused {
        Sleep(150)
      }
      if this._stopRequested {
        throw Error("Stopped by user")
      }
      Sleep(chunk)
      elapsed += chunk
    }
  }

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
