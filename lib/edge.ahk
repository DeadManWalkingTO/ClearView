; ==================== lib/edge.ahk ====================
#Requires AutoHotkey v2.0
#Include "settings.ahk"

class EdgeService {
    __New(edgeExe, winSelector := "ahk_exe msedge.exe") {
        this.exe := edgeExe
        this.sel := winSelector
    }

    ; ---- Public API ----
    ResolveProfileDirByName(displayName) {
        ; Bypass αν έχεις καρφωμένη τιμή
        if (Settings.PROFILE_DIR_FORCE != "")
            return Settings.PROFILE_DIR_FORCE

        base := EnvGet("LOCALAPPDATA") "\Microsoft\Edge\User Data\"
        if !this._dirExist(base)
            return ""

        esc := this._regexEscape(displayName)

        ; 1) Local State (info_cache)
        localState := base "Local State"
        if FileExist(localState) {
            txt := ""
            try {
                txt := FileRead(localState, "UTF-8")
            } catch as e {
                txt := ""
            }
            if (txt != "") {
                pat := '"profile"\s*:\s*\{\s*"info_cache"\s*:\s*\{([\s\S]*?)\}\s*\}'
                if RegExMatch(txt, pat, &m) {
                    cache := m[1], pos := 1
                    while RegExMatch(cache, '"([^"]+)"\s*:\s*\{[^}]*"name"\s*:\s*"([^"]+)"', &mm, pos) {
                        dir := mm[1], nm := mm[2]
                        if (nm = displayName)
                            return dir
                        pos := mm.Pos(0) + mm.Len(0)
                    }
                }
            }
        }

        ; 2) Fallback: Preferences σε Default + Profile N
        candidates := ["Default"]
        Loop Files, base "*", "D" {
            d := A_LoopFileName
            if RegExMatch(d, "^Profile\s+\d+$")
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

            if RegExMatch(txt2, '"profile"\s*:\s*\{[^}]*"name"\s*:\s*"' esc '"')
                return cand

            if RegExMatch(txt2, '"name"\s*:\s*"' esc '"')
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

    ; Ασφαλές regex-escape σε μία γραμμή
    _regexEscape(str) => RegExReplace(str, "([\\.^$*+?()\\[\\]{}|])", "\\$1")
}
; ==================== End Of File ====================
