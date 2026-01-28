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

    ; ------ ΝΕΕΣ ΜΕΘΟΔΟΙ (Tabs/Profiles) ------

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

        ; Μορφή 1 (quoted): --profile-directory="Profile N"  ή  --profile-directory="Default"
        ; ΣΗΜΑΝΤΙΚΟ: Στο AHK v2, τα διπλά εισαγωγικά μέσα σε string διαφεύγουν με backtick: `"
        if RegExMatch(cmd, "--profile-directory=`"([^`"]+)`"", &m)
            return m[1]

        ; Μορφή 2 (unquoted): --profile-directory=ProfileN  ή  --profile-directory=Default
        if RegExMatch(cmd, "--profile-directory=([^\s]+)", &m)
            return m[1]

        ; Ασφάλεια: αν δεν βρεθεί ρητό arg, δεν το κλείνουμε
        return ""
    }

    ; Σενάριο νέου παραθύρου: υπάρχουν ακριβώς δύο καρτέλες (η default + η νέα).
    ; Κρατάμε την νέα ενεργή καρτέλα, κλείνουμε την άλλη.
    CloseOtherTabsInNewWindow(hWnd) {
        WinActivate("ahk_id " hWnd)
        WinWaitActive("ahk_id " hWnd, , 3)
        ; Μετακίνηση στην «παλιά» καρτέλα (μία αριστερά)
        Send("^+{Tab}")
        Sleep(120)
        ; Κλείσιμο της «παλιάς» καρτέλας
        Send("^{w}")
        Sleep(120)
        ; Απομένει η νέα καρτέλα ως μοναδική
    }

    ; Κλείνει ΟΛΑ τα άλλα παράθυρα του ΙΔΙΟΥ προφίλ (άρα και τις καρτέλες τους)
    CloseOtherWindowsOfProfile(profileDir, hKeep) {
        all := WinGetList(this.sel)
        for _, h in all {
            if (h = hKeep)
                continue
            pd := this.GetWindowProfileDir(h)
            if (pd = "")
                continue
            if (pd = profileDir) {
                ; Ευγενικό κλείσιμο παραθύρου (κλείνουν όλες οι καρτέλες του)
                WinClose("ahk_id " h)
                WinWaitClose("ahk_id " h, , 3)
                if WinExist("ahk_id " h) {
                    ; Fallback: Ctrl+Shift+W (κλείσιμο window με tabs)
                    WinActivate("ahk_id " h)
                    WinWaitActive("ahk_id " h, , 2)
                    Send("^+w")
                    Sleep(120)
                    WinWaitClose("ahk_id " h, , 2)
                }
            }
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
