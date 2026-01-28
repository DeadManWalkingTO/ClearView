; ==================== lib/settings.ahk ====================
#Requires AutoHotkey v2.0

class Settings {
    ; ------- Defaults (authoritative) -------
    static APP_TITLE := "BH Automation — Edge/Chryseis"
    static APP_VERSION := "v2.0.2"
    static POPUP_T := 3
    static KEEP_EDGE_OPEN := true

    ; Ουδέτερο εικονίδιο σε emoji (άμεσο χαρακτήρα)
    static ICON_NEUTRAL := "🔵"

    static EDGE_WIN_SEL := "ahk_exe msedge.exe"
    static EDGE_EXE := "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
    static EDGE_PROFILE_NAME := "Chryseis"
    static PROFILE_DIR_FORCE := ""  ; π.χ. "Profile 3" για bypass

    ; Προαιρετικά data paths
    static DATA_LIST_TXT := ""
    static DATA_RANDOM_TXT := ""

    ; ------- API -------
    static LoadFromIni(iniPath) {
        if !FileExist(iniPath) {
            try Settings.SaveToIni(iniPath)
        }

        ; App (επιτρέπουμε override της έκδοσης από INI — όπως ζήτησες)
        Settings.APP_TITLE := Settings._IniRead(iniPath, "App", "Title", Settings.APP_TITLE)
        Settings.APP_VERSION := Settings._IniRead(iniPath, "App", "Version", Settings.APP_VERSION)
        Settings.POPUP_T := Settings._IniReadInt(iniPath, "App", "PopupTimeout", Settings.POPUP_T)
        Settings.KEEP_EDGE_OPEN := Settings._IniReadBool(iniPath, "App", "KeepEdgeOpen", Settings.KEEP_EDGE_OPEN)
        Settings.ICON_NEUTRAL := Settings._IniRead(iniPath, "App", "NeutralIcon", Settings.ICON_NEUTRAL)

        ; Edge
        Settings.EDGE_EXE := Settings._IniRead(iniPath, "Edge", "Exe", Settings.EDGE_EXE)
        Settings.EDGE_PROFILE_NAME := Settings._IniRead(iniPath, "Edge", "ProfileDisplayName", Settings.EDGE_PROFILE_NAME)
        Settings.PROFILE_DIR_FORCE := Settings._IniRead(iniPath, "Edge", "ProfileDirForce", Settings.PROFILE_DIR_FORCE)

        ; Data
        Settings.DATA_LIST_TXT := Settings._IniRead(iniPath, "Data", "ListTxt", Settings.DATA_LIST_TXT)
        Settings.DATA_RANDOM_TXT := Settings._IniRead(iniPath, "Data", "RandomTxt", Settings.DATA_RANDOM_TXT)
    }

    static SaveToIni(iniPath) {
        ; App
        IniWrite(Settings.APP_TITLE, iniPath, "App", "Title")
        IniWrite(Settings.APP_VERSION, iniPath, "App", "Version")
        IniWrite(Settings.POPUP_T, iniPath, "App", "PopupTimeout")
        IniWrite(Settings._BoolToStr(Settings.KEEP_EDGE_OPEN), iniPath, "App", "KeepEdgeOpen")
        IniWrite(Settings.ICON_NEUTRAL, iniPath, "App", "NeutralIcon")
        ; Edge
        IniWrite(Settings.EDGE_EXE, iniPath, "Edge", "Exe")
        IniWrite(Settings.EDGE_PROFILE_NAME, iniPath, "Edge", "ProfileDisplayName")
        IniWrite(Settings.PROFILE_DIR_FORCE, iniPath, "Edge", "ProfileDirForce")
        ; Data
        IniWrite(Settings.DATA_LIST_TXT, iniPath, "Data", "ListTxt")
        IniWrite(Settings.DATA_RANDOM_TXT, iniPath, "Data", "RandomTxt")
    }

    ; ------- Helpers (INI parsing) -------

    static _IniRead(ini, sec, key, def) {
        try {
            return IniRead(ini, sec, key, def)
        } catch {
            return def
        }
    }

    static _IniReadInt(ini, sec, key, def) {
        try {
            val := IniRead(ini, sec, key, def)
            return (val + 0)
        } catch {
            return def
        }
    }
    static _IniReadBool(ini, sec, key, def) {
        try {
            val := IniRead(ini, sec, key, Settings._BoolToStr(def))
            return Settings._StrToBool(val)
        } catch {
            return def
        }
    }
    static _BoolToStr(b) => b ? "true" : "false"
    static _StrToBool(s) {
        s := Trim(StrLower(s))
        return (s = "1" or s = "true" or s = "yes" or s = "y")
    }
}
; ==================== End Of File ====================
