; ==================== lib/edge_profile.ahk ====================
#Requires AutoHotkey v2.0
#Include "settings.ahk"
#Include "regex.ahk"
#Include "edge.ahk" ; Χρειαζόμαστε EdgeService για resolve & άνοιγμα παραθύρου

; ------------------------------- ΙΔΙΩΤΙΚΑ ΒΟΗΘΗΤΙΚΑ (DRY) -------------------------------

; Επιστρέφει το path του Edge από τα Settings ή "".
_edgep__GetEdgeExe_() {
  exe := ""
  try {
    exe := Settings.EDGE_EXE
  } catch {
    exe := ""
  }
  return exe
}

; Επιστρέφει το εμφανιζόμενο όνομα προφίλ από τα Settings ή "".
_edgep__GetDisplayName_() {
  dn := ""
  try {
    dn := Settings.EDGE_PROFILE_NAME
  } catch {
    dn := ""
  }
  return dn
}

; Ασφαλές double-quote με fallback.
_edgep__QuoteSafe_(text) {
  try {
    return RegexLib.Str.Quote(text)
  } catch {
    return '"' text '"'
  }
}

; Κοινή λογική κατασκευής του --profile-directory=...
; - Προσπάθεια εύρεσης φακέλου προφίλ (ResolveProfileDirByName)
; - Fallback στο εμφανιζόμενο όνομα (displayName)
; - ΠΑΝΤΑ ασφαλές quoting
_edgep__BuildProfileArg_(edgeSvc, displayName) {
  profDir := ""
  try {
    profDir := edgeSvc.ResolveProfileDirByName(displayName)
  } catch {
    profDir := ""
  }
  if (profDir != "") {
    return "--profile-directory=" _edgep__QuoteSafe_(profDir)
  }
  return "--profile-directory=" _edgep__QuoteSafe_(displayName)
}

; Προσάρτηση του --new-window όπου ζητείται.
_edgep__AppendNewWindowIfNeeded_(profArg, newWindow) {
  if (newWindow) {
    return profArg " --new-window"
  }
  return profArg
}

; Προετοιμασία νέου παραθύρου + (προαιρετικά) αρχική πλοήγηση, με logging/sleep
_edgep__PrewarmWindow_(edgeSvc, hWnd, url := "", logger := 0) {
  ; Βήμα: Activate/Wait/Maximize
  try {
    if (logger) {
      logger.Write("🪟 Προθέρμανση: Activate/Wait/Maximize")
    }
  } catch {
  }
  try {
    WinActivate("ahk_id " hWnd)
    WinWaitActive("ahk_id " hWnd, , 5)
    WinMaximize("ahk_id " hWnd)
  } catch {
  }
  ; Barrier: μικρή αναμονή μετά το Maximize
  try {
    if (logger) {
      logger.SleepWithLog(Settings.SMALL_DELAY_MS, "μετά το Maximize")
    } else {
      Sleep(Settings.SMALL_DELAY_MS)
    }
  } catch {
  }

  ; Προαιρετική κενή καρτέλα για ασφαλές περιβάλλον
  try {
    if (logger) {
      logger.Write("📑 Άνοιγμα κενής καρτέλας (NewTab)")
    }
  } catch {
  }
  try {
    edgeSvc.NewTab(hWnd)
  } catch {
  }
  ; Barrier: μικρή αναμονή μετά το NewTab
  try {
    if (logger) {
      logger.SleepWithLog(Settings.SMALL_DELAY_MS, "μετά το NewTab")
    } else {
      Sleep(Settings.SMALL_DELAY_MS)
    }
  } catch {
  }

  ; Αν δόθηκε url, αρχική πλοήγηση (το flow θα κάνει αργότερα τη δική του)
  if (url != "") {
    try {
      if (logger) {
        logger.Write("🌐 Αρχική πλοήγηση pre-warm → " url)
        logger.SleepWithLog(Settings.SMALL_DELAY_MS, "πριν το NavigateToUrl")
      } else {
        Sleep(Settings.SMALL_DELAY_MS)
      }
    } catch {
    }
    try {
      edgeSvc.NavigateToUrl(hWnd, url)
    } catch {
    }
    ; Προαιρετική μικρή αναμονή μετά την πλοήγηση
    try {
      if (logger) {
        logger.SleepWithLog(Settings.SMALL_DELAY_MS, "μετά το NavigateToUrl")
      } else {
        Sleep(Settings.SMALL_DELAY_MS)
      }
    } catch {
    }
  }
}

; ----------------------------------- ΔΗΜΟΣΙΟ API -----------------------------------

; Υπάρχουσα: κρατιέται για setup actions (δεν χρειάζονται hWnd).
; Ανοίγει Edge με το προφίλ της εφαρμογής στο δοθέν URL (προεπιλογή: new window).
StartEdgeWithAppProfile(url, newWindow := true, logger := 0)
{
  edgeExe := _edgep__GetEdgeExe_()
  if (edgeExe = "")
  {
    ; Fallback: άνοιγμα στο προεπιλεγμένο browser
    try {
      Run(url)
    } catch {
    }
    return
  }

  displayName := _edgep__GetDisplayName_()

  ; EdgeService για resolve και εκτέλεση
  edgeSvc := 0
  try {
    edgeSvc := EdgeService(edgeExe, Settings.EDGE_WIN_SEL)
  } catch {
    edgeSvc := 0
  }

  ; Κατασκευή ασφαλούς profile-arg (DRY helper)
  profArg := _edgep__BuildProfileArg_(edgeSvc, displayName)

  ; --new-window (αν ζητείται)
  winArg := ""
  if (newWindow) {
    winArg := "--new-window"
  }

  ; Τελική εντολή Run + Log
  try {
    if (logger) {
      logger.Write("🚀 Εκκίνηση Edge (profile) → " url)
    }
  } catch {
  }

  cmd := ""
  try {
    if (winArg != "") {
      cmd := '"' edgeExe '" ' profArg ' ' winArg ' ' url
    } else {
      cmd := '"' edgeExe '" ' profArg ' ' url
    }
  } catch {
    cmd := '"' edgeExe '" ' url
  }
  try {
    Run(cmd)
  } catch {
  }
}

; Έκδοση που ΕΠΙΣΤΡΕΦΕΙ hWnd (για ροές που θέλουν πλήρη έλεγχο παραθύρου)
; - Χρησιμοποιεί EdgeService.OpenNewWindow(profArg) → hWnd
; - url: προεπιλογή "about:blank" (το flow αργότερα κάνει δική του πλοήγηση)
StartEdgeWithAppProfileEx(edgeSvc, url := "about:blank", newWindow := true, logger := 0)
{
  ; Προαιρετικός έλεγχος ύπαρξης exe από Settings (συμβατότητα με παλαιό κώδικα)
  edgeExe := _edgep__GetEdgeExe_()
  if (edgeExe = "")
  {
    try {
      Run(url)
    } catch {
    }
    return 0
  }

  displayName := _edgep__GetDisplayName_()

  ; DRY: κοινή κατασκευή profile-arg
  profArg := _edgep__BuildProfileArg_(edgeSvc, displayName)

  ; --new-window (αν ζητείται)
  profArg := _edgep__AppendNewWindowIfNeeded_(profArg, newWindow)

  ; Άνοιγμα νέου παραθύρου και λήψη hWnd
  hNew := 0
  try {
    if (logger) {
      logger.Write("🆕 Άνοιγμα νέου παραθύρου Edge (Ex) με προφίλ")
    }
  } catch {
  }
  try {
    hNew := edgeSvc.OpenNewWindow(profArg)
  } catch {
    hNew := 0
  }
  if (!hNew)
  {
    return 0
  }

  ; Προετοιμασία παραθύρου + (προαιρετικά) αρχική πλοήγηση (με logger)
  _edgep__PrewarmWindow_(edgeSvc, hNew, url, logger)
  return hNew
}
; ==================== End Of File ====================
