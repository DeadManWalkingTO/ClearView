; ==================== lib/edge.ahk ====================
#Requires AutoHotkey v2.0
#Include "settings.ahk"
#Include "regex.ahk"
#Include "moves.ahk"

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

  ; ---------------- Simple Play ----------------
  /**
   * Απλοποιημένο Play για YouTube:
   * WinActivate → WinMaximize → (προαιρετικά 1× Ctrl+F6) → (προαιρετικό click) → 'k'
   * @param {Integer} hWnd
   * @param {Object} logger (optional)
   */
  PlayYouTubeSimple(hWnd, logger := 0) {
    try {
      if (logger) {
        try {
          logger.Write("🎯 SimplePlay: WinActivate → Maximize → (optional focus) → (optional click) → (optional 'k')")
        } catch Error as _eLog0 {
          ; no-op
        }
      }

      ; 1) Activate/Maximize
      WinActivate("ahk_id " hWnd)
      WinWaitActive("ahk_id " hWnd, , 3)
      WinMaximize("ahk_id " hWnd)
      Sleep(150)

      ; 2) Προαιρετικό focus (Ctrl+F6)
      try {
        if (Settings.SIMPLE_PLAY_FOCUS) {
          Send("^{F6}")
          Sleep(120)
        }
      } catch Error as _eFocus {
        ; no-op
      }

      ; 2b) Προαιρετικό Home (επιστροφή κορυφής)
      try {
        if (Settings.SIMPLE_PLAY_HOME) {
          Send("{Home}")
          Sleep(120)
        }
      } catch Error as _eHome {
        ; no-op
      }

      ; 3) Προαιρετικό Click για Play (ΝΕΟ: ελέγχεται από Settings.CLICK_TO_PLAY)
      try {
        if (Settings.CLICK_TO_PLAY) {
          CoordMode("Mouse", "Window")
          WinGetPos(, , &W, &H, "ahk_id " hWnd)
          cx := Floor(W / 2)

          yFactor := 0.50
          try {
            yFactor := Settings.SIMPLE_PLAY_Y_FACTOR + 0
          } catch Error as _eYF {
            yFactor := 0.50
          }
          if (yFactor < 0) {
            yFactor := 0
          }
          if (yFactor > 1) {
            yFactor := 1
          }

          cy := Floor(H * yFactor)
          MoveMouseRandom4(cx, cy)
          Click(cx, cy)
          Sleep(150)

          if (logger) {
            try {
              logger.Write("🖱️ SimplePlay: click εκτελέστηκε (CLICK_TO_PLAY=true)")
            } catch Error as _eLogClick {
              ; no-op
            }
          }
        } else {
          if (logger) {
            try {
              logger.Write("▶️ SimplePlay: παράλειψη click (CLICK_TO_PLAY=false, υποθέτω autoplay)")
            } catch Error as _eLogNoClick {
              ; no-op
            }
          }
        }
      } catch Error as _eClick {
        ; no-op
      }

      ; 4) 'k' για Play/Pause (όπως πριν)
      if (Settings.SEND_K_KEY) {
        Send("k")
        Sleep(200)
      }

      if (logger) {
        try {
          logger.Write("✅ SimplePlay: done")
        } catch Error as _eLog1 {
          ; no-op
        }
      }

      this.StepDelay()
    } catch Error as _e {
      if (logger) {
        try {
          logger.Write("⚠️ SimplePlay: exception during play")
        } catch Error as _eLog2 {
          ; no-op
        }
      }
    }
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
