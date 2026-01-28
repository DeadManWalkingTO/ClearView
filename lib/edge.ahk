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
        if (Settings.PROFILE_DIR_FORCE != "")
            return Settings.PROFILE_DIR_FORCE
        base := EnvGet("LOCALAPPDATA") "\Microsoft\Edge\User Data\"
        if !this._dirExist(base)
            return ""
        ; 1) Από "Local State"
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
        ; 2) Fallback: Default + Profile N / Preferences
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

    ; ------ Μέθοδοι Tabs/Profiles ------
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
        ; Quoted: --profile-directory="Profile N" / "Default"
        if RegExMatch(cmd, "\-\-profile\-directory=\`"([^\`"]+)\`"", &m)
            return m[1]
        ; Unquoted: --profile-directory=ProfileN / Default
        if RegExMatch(cmd, "\-\-profile\-directory=([^\s]+)", &m)
            return m[1]
        return ""
    }

    ; ROBUST: Ανίχνευση προφίλ με ανάβαση γονέων
    GetWindowProfileDirRobust(hWnd, maxDepth := 6) {
        pd := this.GetWindowProfileDir(hWnd)
        if (pd != "")
            return pd
        curPid := WinGetPID("ahk_id " hWnd)
        depth := 0
        while (depth < maxDepth) {
            depth += 1
            info := this._getProcessInfo(curPid)  ; { cmd, ppid }
            if (info = 0)
                break
            cmd := info.cmd
            if (cmd != "") {
                if RegExMatch(cmd, "\-\-profile\-directory=\`"([^\`"]+)\`"", &mm)
                    return mm[1]
                if RegExMatch(cmd, "\-\-profile\-directory=([^\s]+)", &mm)
                    return mm[1]
            }
            curPid := info.ppid
            if (curPid = 0 || curPid = "")
                break
        }
        return ""
    }

    ; --- ΝΕΟ: Επιστρέφει όλους τους browser-PIDs για ένα profileDir
    GetBrowserPidsForProfile(profileDir) {
        arr := []
        try {
            q := "SELECT ProcessId, CommandLine FROM Win32_Process WHERE Name='msedge.exe'"
            for proc in ComObjGet("winmgmts:").ExecQuery(q) {
                cmd := proc.CommandLine
                ; Φιλτράρουμε τα child processes (έχουν --type=renderer/gpu/utility κ.λπ.)
                if (cmd != "" && !RegExMatch(cmd, "\-\-type=")) {
                    ; Εντοπισμός profile
                    pd := ""
                    if RegExMatch(cmd, "\-\-profile\-directory=\`"([^\`"]+)\`"", &m)
                        pd := m[1]
                    else if RegExMatch(cmd, "\-\-profile\-directory=([^\s]+)", &m)
                        pd := m[1]
                    if (pd != "" && pd = profileDir)
                        arr.Push(proc.ProcessId)
                }
            }
        } catch as e {
            ; σιωπηλά
        }
        return arr
    }

    CloseOtherTabsInNewWindow(hWnd) {
        WinActivate("ahk_id " hWnd)
        WinWaitActive("ahk_id " hWnd, , 3)
        Send("^+{Tab}") ; στην «παλιά» καρτέλα
        Sleep(120)
        Send("^{w}") ; κλείσιμο
        Sleep(120)
        this.StepDelay()
    }

    ; --- Κλείσιμο windows ίδιου προφίλ: βασισμένο σε PIDs browser-process ---
    CloseOtherWindowsOfProfile(profileDir, hKeep) {
        ; Συγκεντρώνουμε τους browser-PIDs για το συγκεκριμένο profile
        pids := this.GetBrowserPidsForProfile(profileDir)
        if (pids.Length = 0)
            return
        ; Κλείνουμε μόνο windows που ανήκουν σε αυτούς τους PIDs
        passes := 3, closedTotal := 0
        loop passes {
            closedOne := false
            all := WinGetList(this.sel)
            for _, h in all {
                if (h = hKeep)
                    continue
                pid := WinGetPID("ahk_id " h)
                if (this._pidInList(pid, pids)) {
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
                    closedOne := true
                    closedTotal += 1
                }
            }
            if (!closedOne)
                break
        }
        ; Επιστρέφουμε πόσα έκλεισαν για logging
        return closedTotal
    }

    ; ---- Πλοήγηση σε URL στην ενεργή καρτέλα ----
    NavigateToUrl(hWnd, url) {
        WinActivate("ahk_id " hWnd)
        WinWaitActive("ahk_id " hWnd, , 3)
        Send("^{l}") ; focus address bar
        Sleep(120)
        Send(url)
        Sleep(120)
        Send("{Enter}")
        Sleep(250)
        this.StepDelay()
    }

    ; ------ Focus & Play στο YouTube ------
    FocusPage(hWnd) {
        WinActivate("ahk_id " hWnd)
        WinWaitActive("ahk_id " hWnd, , 3)
        Send("^{F6}") ; pane: page content (Edge)
        Sleep(120)
        this.StepDelay()
    }

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

    PlayYouTube(hWnd, doSecondK := false) {
        this.WaitForYouTubeTitle(hWnd) ; best-effort
        this.FocusPage(hWnd)
        CoordMode("Mouse", "Window")
        WinGetPos(, , &W, &H, "ahk_id " hWnd)
        x := Floor(W / 2), y := Floor(H * 0.45)
        Click(x, y)
        Sleep(150)
        Send("k") ; YouTube Play/Pause
        Sleep(250)
        this.StepDelay()
        if (doSecondK) {
            Send("k")
            Sleep(200)
            this.StepDelay()
        }
    }

    ; ---- Internals ----
    _getProcessInfo(pid) {
        try {
            for proc in ComObjGet("winmgmts:").ExecQuery("SELECT CommandLine, ParentProcessId FROM Win32_Process WHERE ProcessId=" pid) {
                return { cmd: proc.CommandLine, ppid: proc.ParentProcessId }
            }
        } catch as e {
            return 0
        }
        return 0
    }

    _pidInList(pid, arr) {
        for _, p in arr
            if (p = pid)
                return true
        return false
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
