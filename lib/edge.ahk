; ==================== lib/edge.ahk ====================
#Requires AutoHotkey v2.0
#Include "settings.ahk"
#Include "regex.ahk"

class EdgeService {
  __New(edgeExe, winSelector := "ahk_exe msedge.exe") {
    this.exe := edgeExe
    this.sel := winSelector
  }

  ; ---- Public API ----
  ResolveProfileDirByName(displayName) {
    ; Άμεσο bypass αν έχει οριστεί force
    if (Settings.PROFILE_DIR_FORCE != "")
      return Settings.PROFILE_DIR_FORCE

    base := EnvGet("LOCALAPPDATA") "\Microsoft\Edge\User Data\"
    if !this._dirExist(base)
      return ""

    ; 1) Προσπάθεια από Local State (info_cache)
    localState := base "Local State"
    if FileExist(localState) {
      txt := ""
      try {
        txt := FileRead(localState, "UTF-8")
      } catch as e {
        txt := ""
      }
      dirFromLocal := RegexLib.FindProfileDirInLocalState(txt, displayName)
      if (dirFromLocal != "")
        return dirFromLocal
    }

    ; 2) Fallback: διατρέχουμε "Default" + "Profile N" και κοιτάμε Preferences
    candidates := ["Default"]
    Loop Files, base "*", "D" {
      d := A_LoopFileName
      if RegexLib.IsProfileFolderName(d)
        candidates.Push(d)
    }
    for _, cand in candidates {
      pref := base cand "\Preferences"
      if !FileExist(pref)
        continue
      txt2 := ""
      try {
        txt2 := FileRead(pref, "UTF-8")
      } catch as e {
        txt2 := ""
      }
      if (txt2 = "")
        continue
      if RegexLib.PreferencesContainsProfileName(txt2, displayName)
        return cand
    }
    return ""
  }

  OpenNewWindow(profileArg) {
    before := WinGetList(this.sel)
    try {
      Run('"' this.exe '" ' profileArg)
    } catch as e {
      return 0
    }
    tries := 40
    loop tries {
      Sleep(250)
      after := WinGetList(this.sel)
      hNew := this._findNewWindow(before, after)
      if (hNew)
        return hNew
    }
    return 0
  }

  NewTab(hWnd) {
    WinActivate("ahk_id " hWnd)
    WinWaitActive("ahk_id " hWnd, , 3)
    Send("^t")
    Sleep(250)
  }

  ; ------ Μέθοδοι Tabs/Profiles ------
  ; Επιστρέφει το profile-directory του παραθύρου (π.χ. "Profile 3" ή "Default").
  ; Αν δεν βρεθεί, επιστρέφει κενό "" και ΔΕΝ αγγίζουμε το παράθυρο.
  GetWindowProfileDir(hWnd) {
    pid := WinGetPID("ahk_id " hWnd)
    cmd := ""
    try {
      for proc in ComObjGet("winmgmts:").ExecQuery("SELECT CommandLine FROM Win32_Process WHERE ProcessId=" pid) {
        cmd := proc.CommandLine
        break
      }
    } catch as e {
      cmd := ""
    }
    if (cmd = "")
      return ""

    ; Quoted: --profile-directory="Profile N" | "Default"
    if RegExMatch(cmd, "--profile-directory=`"([^`"]+)`"", &m)
      return m[1]

    ; Unquoted: --profile-directory=ProfileN | Default
    if RegExMatch(cmd, "--profile-directory=([^\s]+)", &m)
      return m[1]

    return ""
  }

  CloseOtherTabsInNewWindow(hWnd) {
    WinActivate("ahk_id " hWnd)
    WinWaitActive("ahk_id " hWnd, , 3)
    Send("^+{Tab}") ; στην «παλιά» καρτέλα
    Sleep(120)
    Send("^{w}")    ; κλείσιμο
    Sleep(120)
  }

  CloseOtherWindowsOfProfile(profileDir, hKeep) {
    all := WinGetList(this.sel)
    for _, h in all {
      if (h = hKeep)
        continue
      pd := this.GetWindowProfileDir(h)
      if (pd = "")
        continue
      if (pd = profileDir) {
        WinClose("ahk_id " h)
        WinWaitClose("ahk_id " h, , 3)
        if WinExist("ahk_id " h) {
          WinActivate("ahk_id " h)
          WinWaitActive("ahk_id " h, , 2)
          Send("^+w")
          Sleep(120)
          WinWaitClose("ahk_id " h, , 2)
        }
      }
    }
  }

  ; --- Πλοήγηση σε URL στην ενεργή καρτέλα ---
  NavigateToUrl(hWnd, url) {
    WinActivate("ahk_id " hWnd)
    WinWaitActive("ahk_id " hWnd, , 3)
    Send("^{l}")     ; focus address bar
    Sleep(120)
    Send(url)
    Sleep(120)
    Send("{Enter}")
    Sleep(250)
  }

  ; ------ ΝΕΕΣ ΜΕΘΟΔΟΙ: Focus & Play στο YouTube ------
  ; Εστίαση στο περιεχόμενο της σελίδας (όχι στη γραμμή διευθύνσεων).
  FocusPage(hWnd) {
    WinActivate("ahk_id " hWnd)
    WinWaitActive("ahk_id " hWnd, , 3)
    ; Edge: F6/Shift+F6 εναλλάσσει focus μεταξύ πανέλων (chrome UI ↔ page)
    Send("{F6}")
    Sleep(120)
    Send("{F6}")
    Sleep(80)
  }

  ; Αναμονή (best-effort) μέχρι ο τίτλος να περιέχει "YouTube".
  WaitForYouTubeTitle(hWnd, timeoutMs := 6000) {
    tries := Ceil(timeoutMs / 250.0)
    loop tries {
      t := WinGetTitle("ahk_id " hWnd)
      if InStr(t, "YouTube")
        return true
      Sleep(250)
    }
    return false
  }

  ; Πάτημα Play στο YouTube:
  ; 1) Focus στη σελίδα + 'k'  (επίσημο Play/Pause του YouTube)
  ; 2) Fallback: click στο κέντρο περιεχομένου + ξανά 'k'
  PlayYouTube(hWnd, doClickFallback := true) {
    ; 0) Best-effort αναμονή τίτλου
    this.WaitForYouTubeTitle(hWnd)

    ; 1) Focus & 'k'
    this.FocusPage(hWnd)
    Send("k")
    Sleep(350)

    ; 2) Fallback click + 'k' (αν χρειαστεί λόγω overlay/focus)
    if (doClickFallback) {
      CoordMode("Mouse", "Window")
      WinGetPos(, , &W, &H, "ahk_id " hWnd)
      x := Floor(W / 2)
      y := Floor(H * 0.45)   ; λίγο πάνω από το απόλυτο κέντρο
      Click(x, y)
      Sleep(150)
      Send("k")
      Sleep(200)
    }
  }

  ; ---- Internals ----
  _findNewWindow(beforeArr, afterArr) {
    seen := Map()
    for _, h in beforeArr
      seen[h] := true
    for _, h in afterArr
      if !seen.Has(h)
        return h
    return 0
  }

  _dirExist(path) => InStr(FileExist(path), "D") > 0
}
; ==================== End Of File ====================