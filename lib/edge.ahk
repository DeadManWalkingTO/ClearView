; ==================== lib/edge.ahk ====================
#Requires AutoHotkey v2.0
#Include "settings.ahk"
#Include "regex.ahk"

class EdgeService {
  __New(edgeExe, winSelector := "ahk_exe msedge.exe") {
    this.exe := edgeExe
    this.sel := winSelector
  }

  ; ---------------- Profile resolve ----------------
  ResolveProfileDirByName(displayName) {
    if (Settings.PROFILE_DIR_FORCE != "") {
      return Settings.PROFILE_DIR_FORCE
    }
    c := RegexLib.Chars
    base := EnvGet("LOCALAPPDATA") . c.BS "Microsoft" c.BS "Edge" c.BS "User Data" c.BS
    if (!this._dirExist(base)) {
      return ""
    }

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

    candidates := ["Default"]
    try {
      Loop Files, base "*", "D" {
        d := A_LoopFileName
        if RegexLib.IsProfileFolderName(d) {
          candidates.Push(d)
        }
      }
    } catch Error as e {
      ; no-op
    }

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

  ; ---------------- Window/Tab ops ----------------
  OpenNewWindow(profileArg) {
    before := WinGetList(this.sel)
    try {
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

  NewTab(hWnd) {
    WinActivate("ahk_id " hWnd)
    WinWaitActive("ahk_id " hWnd, , 3)
    Send("^t")
    Sleep(250)
    this.StepDelay()
  }

  CloseOtherTabsInNewWindow(hWnd) {
    WinActivate("ahk_id " hWnd)
    WinWaitActive("ahk_id " hWnd, , 3)
    Send("^+{Tab}")
    Sleep(120)
    Send("^{w}")
    Sleep(150)
    this.StepDelay()
  }

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

  FocusPage(hWnd) {
    WinActivate("ahk_id " hWnd)
    WinWaitActive("ahk_id " hWnd, , 3)
    Send("^{F6}")
    Sleep(120)
    this.StepDelay()
  }

  ; --- ΝΕΟ: πιο «επιθετικό» focus στο web content
  FocusPageStrong(hWnd) {
    try {
      WinActivate("ahk_id " hWnd)
      WinWaitActive("ahk_id " hWnd, , 3)
      ; Δύο διαδοχικά Ctrl+F6 (μερικές φορές χρειάζονται πολλαπλά «άλματα»)
      Send("^{F6}")
      Sleep(120)
      Send("^{F6}")
      Sleep(120)
      ; Επιπλέον F6 βοηθά σε ορισμένες εκδόσεις Chromium
      Send("{F6}")
      Sleep(120)
    } catch Error as _eFP {
      ; no-op
    }
  }

  WaitForYouTubeTitle(hWnd, timeoutMs := 8000) {
    tries := Ceil(timeoutMs / 250.0)
    loop tries {
      t := ""
      try {
        t := WinGetTitle("ahk_id " hWnd)
      } catch Error as _eT {
        t := ""
      }
      if InStr(t, "YouTube") {
        return true
      }
      Sleep(250)
    }
    return false
  }

  ; ---------------- Robust Play ----------------
  /**
   * Ισχυρό Play για YouTube:
   * - FocusPageStrong → Esc (κλείνει overlays)
   * - Attempt 1: center click + 'k'
   * - Attempt 2: Home + top click + 'k'
   * - Attempt 3: double center click + Space + 'k'
   * Προαιρετικά δέχεται logger για αναλυτικά logs.
   */
  PlayYouTube(hWnd, doSecondK := false, logger := 0) {
    this.WaitForYouTubeTitle(hWnd)
    this.FocusPageStrong(hWnd)

    ; Υπολογισμός βασικών συντεταγμένων
    CoordMode("Mouse", "Window")
    WinGetPos(, , &W, &H, "ahk_id " hWnd)
    cx := Floor(W / 2)
    cy := Floor(H * 0.45)
    topY := 220   ; Κορυφαία «ζώνη» που συνήθως καλύπτει τον player (μετά από Home)

    ; Attempt 1
    if (logger) {
      try {
        logger.Write("🎯 Play attempt 1: center click + 'k'")
      } catch Error as _eL1 {
      }
    }
    try {
      Send("{Esc}")
      Sleep(120)
      Click(cx, cy)
      Sleep(150)
      Send("k")
      Sleep(220)
      if (doSecondK) {
        Send("k")
        Sleep(160)
      }
    } catch Error as _eA1 {
      ; no-op
    }

    ; Attempt 2 (Home + top click + 'k')
    if (logger) {
      try {
        logger.Write("🎯 Play attempt 2: Home + top click + 'k'")
      } catch Error as _eL2 {
      }
    }
    try {
      this.FocusPageStrong(hWnd)
      Send("{Home}")
      Sleep(200)
      Click(cx, topY)
      Sleep(140)
      Send("k")
      Sleep(220)
    } catch Error as _eA2 {
      ; no-op
    }

    ; Attempt 3 (double center click + Space + 'k')
    if (logger) {
      try {
        logger.Write("🎯 Play attempt 3: double center click + Space + 'k'")
      } catch Error as _eL3 {
      }
    }
    try {
      this.FocusPageStrong(hWnd)
      Click(cx, cy)
      Sleep(100)
      Click(cx, cy)
      Sleep(120)
      Send(" ")
      Sleep(180)
      Send("k")
      Sleep(200)
    } catch Error as _eA3 {
      ; no-op
    }

    ; Σταθεροποίηση
    this.StepDelay()
  }

  ; ---------------- Internals ----------------
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

  _dirExist(path) => InStr(FileExist(path), "D") > 0

  StepDelay() {
    Sleep(Settings.EDGE_STEP_DELAY_MS)
  }
}
; ==================== End Of File ====================
