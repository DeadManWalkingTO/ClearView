; ==================== lib/edge.ahk ====================
#Requires AutoHotkey v2.0
#Include "settings.ahk"
#Include "regex.ahk"

class EdgeService {
  __New(edgeExe, winSelector := "ahk_exe msedge.exe") {
    this.exe := edgeExe
    this.sel := winSelector
  }

  /**
   * Εντοπίζει φάκελο προφίλ του Edge με βάση το εμφανιζόμενο όνομα (displayName).
   * Προτεραιότητα: Settings.PROFILE_DIR_FORCE → Local State → Preferences → Default/Profile N.
   */
  ResolveProfileDirByName(displayName) {
    if (Settings.PROFILE_DIR_FORCE != "") {
      return Settings.PROFILE_DIR_FORCE
    }

    c := RegexLib.Chars
    base := EnvGet("LOCALAPPDATA")
      . c.BS "Microsoft" c.BS "Edge" c.BS "User Data" c.BS

    if (!this._dirExist(base)) {
      return ""
    }

    ; --- Διαβάζουμε "Local State" (JSON-σαν κείμενο) και ψάχνουμε στο info_cache ---
    localState := base "Local State"
    if FileExist(localState) {
      txt := ""
      try {
        txt := FileRead(localState, "UTF-8")
      } catch Error as e {
        txt := ""
      }
      dirFromLocal := RegexLib.FindProfileDirInLocalState(txt, displayName)
      if (dirFromLocal != "") {
        return dirFromLocal
      }
    }

    ; --- Υποψήφιοι φάκελοι: Default + Profile N ---
    candidates := ["Default"]
    try {
      Loop Files, base "*", "D" {
        d := A_LoopFileName
        if RegexLib.IsProfileFolderName(d) {
          candidates.Push(d)
        }
      }
    } catch Error as e {
      ; σιωπηλά
    }

    ; --- Έλεγχος Preferences ανά υποψήφιο φάκελο ---
    for _, cand in candidates {
      pref := base cand c.BS "Preferences"
      if !FileExist(pref) {
        continue
      }
      txt2 := ""
      try {
        txt2 := FileRead(pref, "UTF-8")
      } catch Error as e {
        txt2 := ""
      }
      if (txt2 = "") {
        continue
      }
      if RegexLib.PreferencesContainsProfileName(txt2, displayName) {
        return cand
      }
    }

    return ""
  }

  /**
   * Ανοίγει νέο παράθυρο Edge με δοθέντα arguments. Επιστρέφει νέο hwnd ή 0.
   */
  OpenNewWindow(profileArg) {
    before := WinGetList(this.sel)
    try {
      ; Περνάμε το εκτελέσιμο σε quotes για ασφάλεια (διαστήματα στο path)
      Run('"' this.exe '" ' profileArg)
    } catch Error as e {
      return 0
    }

    tries := 40
    loop tries {
      Sleep(250)
      after := WinGetList(this.sel)
      hNew := this._findNewWindow(before, after)
      if (hNew) {
        this.StepDelay()
        return hNew
      }
    }
    return 0
  }

  /**
   * Άνοιγμα νέας καρτέλας.
   */
  NewTab(hWnd) {
    WinActivate("ahk_id " hWnd)
    WinWaitActive("ahk_id " hWnd, , 3)
    Send("^t")
    Sleep(250)
    this.StepDelay()
  }

  /**
   * Κλείνει την άλλη καρτέλα στο καινούριο παράθυρο (κρατά την τρέχουσα).
   */
  CloseOtherTabsInNewWindow(hWnd) {
    WinActivate("ahk_id " hWnd)
    WinWaitActive("ahk_id " hWnd, , 3)
    Send("^+{Tab}")
    Sleep(120)
    Send("^{w}")
    Sleep(150)
    this.StepDelay()
  }

  /**
   * Κλείνει όλα τα άλλα παράθυρα Edge εκτός από το hKeep (best-effort).
   */
  CloseAllOtherWindows(hKeep) {
    all := WinGetList(this.sel)
    for _, h in all {
      if (h = hKeep) {
        continue
      }
      WinClose("ahk_id " h)
      WinWaitClose("ahk_id " h, , 3)
      if WinExist("ahk_id " h) {
        WinActivate("ahk_id " h)
        WinWaitActive("ahk_id " h, , 2)
        Send("^+w")
        Sleep(150)
        WinWaitClose("ahk_id " h, , 3)
      }
      this.StepDelay()
    }
  }

  /**
   * Πλοήγηση σε URL (εστίαση address bar, εισαγωγή, Enter).
   */
  NavigateToUrl(hWnd, url) {
    WinActivate("ahk_id " hWnd)
    WinWaitActive("ahk_id " hWnd, , 3)
    Send("^{l}")
    Sleep(120)
    Send(url)
    Sleep(120)
    Send("{Enter}")
    Sleep(250)
    this.StepDelay()
  }

  /**
   * Εστίαση στη σελίδα (Ctrl+F6).
   */
  FocusPage(hWnd) {
    WinActivate("ahk_id " hWnd)
    WinWaitActive("ahk_id " hWnd, , 3)
    Send("^{F6}")
    Sleep(120)
    this.StepDelay()
  }

  /**
   * Περιμένει μέχρι ο τίτλος του παραθύρου να περιέχει "YouTube".
   */
  WaitForYouTubeTitle(hWnd, timeoutMs := 8000) {
    tries := Ceil(timeoutMs / 250.0)
    loop tries {
      t := WinGetTitle("ahk_id " hWnd)
      if InStr(t, "YouTube") {
        return true
      }
      Sleep(250)
    }
    return false
  }

  /**
   * Πιο ανθεκτικό Play στο YouTube:
   * - WaitForYouTubeTitle → FocusPage → Esc (overlays) → center-click → 'k' → fallback Space → δεύτερο 'k' (προαιρετικό) → μικρή καθυστέρηση.
   */
  PlayYouTube(hWnd, doSecondK := false) {
    this.WaitForYouTubeTitle(hWnd)
    this.FocusPage(hWnd)

    ; 1) Κλείσε πιθανά overlays (cookie / login / mini-dialogues)
    Send("{Esc}")
    Sleep(120)

    ; 2) Click στο κέντρο του player
    CoordMode("Mouse", "Window")
    WinGetPos(, , &W, &H, "ahk_id " hWnd)
    x := Floor(W / 2), y := Floor(H * 0.45)
    Click(x, y)
    Sleep(150)

    ; 3) Κύριο πλήκτρο Play/Pause
    Send("k")
    Sleep(200)

    ; 4) Fallback: Space
    Send(" ")
    Sleep(150)

    ; 5) Προαιρετικό δεύτερο 'k'
    if (doSecondK) {
      Send("k")
      Sleep(180)
    }

    ; 6) Μικρή σταθεροποίηση
    this.StepDelay()
  }

  ; ---------------- Internals ----------------

  /**
   * Εντοπίζει νέο hwnd ανάμεσα στις λίστες before/after.
   */
  _findNewWindow(beforeArr, afterArr) {
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

  /**
   * Έλεγχος αν path είναι directory.
   */
  _dirExist(path) => InStr(FileExist(path), "D") > 0

  /**
   * Μικρή καθυστέρηση βημάτων Edge (ρυθμίσιμη από Settings).
   */
  StepDelay() {
    Sleep(Settings.EDGE_STEP_DELAY_MS)
  }
}
; ==================== End Of File ====================
