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

        if RegExMatch(cmd, "--profile-directory=`"([^`"]+)`"", &m)
            return m[1]
        if RegExMatch(cmd, "--profile-directory=([^\s]+)", &m)
            return m[1]
        return ""
    }

    CloseOtherTabsInNewWindow(hWnd) {
        WinActivate("ahk_id " hWnd)
        WinWaitActive("ahk_id " hWnd, , 3)
        Send("^+{Tab}")  ; στην «παλιά» καρτέλα
        Sleep(120)
        Send("^{w}")     ; κλείσιμο
        Sleep(120)
        this.StepDelay()
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
                this.StepDelay()
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
        this.StepDelay()
    }

    ; ------ ΝΕΕΣ ΜΕΘΟΔΟΙ: Focus & Play στο YouTube ------
    ; Εστίαση στο περιεχόμενο της σελίδας (Edge: Ctrl+F6 = move focus στο page pane)
    ; Βλ. τεκμηρίωση Edge shortcuts. [1](https://tkcomputerservice.com/edge-keyboard-shortcuts.htm)
    FocusPage(hWnd) {
        WinActivate("ahk_id " hWnd)
        WinWaitActive("ahk_id " hWnd, , 3)
        Send("^{F6}")    ; Ctrl+F6 → pane: page content
        Sleep(120)
        this.StepDelay()
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
    ; 1) Focus στη σελίδα (Ctrl+F6) + PRE-CLICK στον player (για να μην γραφτεί το 'k' στην address bar)
    ; 2) Μετά στέλνουμε 'k' (επίσημο Play/Pause του YouTube). [2](https://vind-works.io/resources/youtube-keyboard-shortcuts)
    ; 3) Προαιρετικά δεύτερο 'k' αν θες «double assurance».
    PlayYouTube(hWnd, doSecondK := false) {
        this.WaitForYouTubeTitle(hWnd)   ; best-effort
        ; 1) Focus σε page + click στον player
        this.FocusPage(hWnd)
        CoordMode("Mouse", "Window")
        WinGetPos(, , &W, &H, "ahk_id " hWnd)
        x := Floor(W / 2)
        y := Floor(H * 0.45)
        Click(x, y)
        Sleep(150)

        ; 2) 'k' (τώρα με page focus → δεν μένει στη γραμμή διεύθυνσης)
        Send("k")
        Sleep(250)
        this.StepDelay()

        ; 3) (προαιρετικό) δεύτερο 'k'
        if (doSecondK) {
            Send("k")
            Sleep(200)
            this.StepDelay()
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

    ; ---- ΝΕΟ: Κεντρική καθυστέρηση βήματος ----
    StepDelay() {
        Sleep(Settings.EDGE_STEP_DELAY_MS)
    }
}
; ==================== End Of File ====================
