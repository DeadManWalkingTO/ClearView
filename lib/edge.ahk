; ==================== lib/edge.ahk ====================
#Requires AutoHotkey v2.0
#Include "settings.ahk"
#Include "regex.ahk"

class EdgeService {
    __New(edgeExe, winSelector := "ahk_exe msedge.exe") {
        this.exe := edgeExe
        this.sel := winSelector
    }

    ResolveProfileDirByName(displayName) {
        if (Settings.PROFILE_DIR_FORCE != "")
            return Settings.PROFILE_DIR_FORCE
        base := EnvGet("LOCALAPPDATA") "\Microsoft\Edge\User Data\"
        if (!this._dirExist(base))
            return ""
        localState := base "Local State"
        if FileExist(localState) {
            txt := ""
            try {
                txt := FileRead(localState, "UTF-8")
            } catch Error as e {
                txt := ""
            }
            dirFromLocal := RegexLib.FindProfileDirInLocalState(txt, displayName)
            if (dirFromLocal != "")
                return dirFromLocal
        }
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
            } catch Error as e {
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
        ; --- CDP flag όταν είναι ενεργό ---
        try {
            if (Settings.CDP_ENABLED) {
                profileArg .= " --remote-debugging-port=" Settings.CDP_PORT
            }
        } catch Error as e {
            ; ignore
        }

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
            if (h = hKeep)
                continue
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
            t := WinGetTitle("ahk_id " hWnd)
            if InStr(t, "YouTube")
                return true
            Sleep(250)
        }
        return false
    }

    PlayYouTube(hWnd, doSecondK := false) {
        this.WaitForYouTubeTitle(hWnd)
        this.FocusPage(hWnd)
        CoordMode("Mouse", "Window")
        WinGetPos(, , &W, &H, "ahk_id " hWnd)
        x := Floor(W / 2), y := Floor(H * 0.45)
        Click(x, y)
        Sleep(150)
        Send("k")
        Sleep(250)
        this.StepDelay()
        if (doSecondK) {
            Send("k")
            Sleep(200)
            this.StepDelay()
        }
    }

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

    StepDelay() {
        Sleep(Settings.EDGE_STEP_DELAY_MS)
    }
}
; ==================== End Of File ====================
