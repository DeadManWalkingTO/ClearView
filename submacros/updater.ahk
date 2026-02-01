; ==================== submacros/updater.ahk ====================
#Requires AutoHotkey v2.0
#Include "..\lib\settings.ahk"
#Include "..\lib\regex.ahk"
#Include "..\lib\utils.ahk"

; Updater
; - Έλεγχος Internet (NCSI-like) μέσω Utils.CheckInternet (SSOT)
; - Ανάγνωση έκδοσης τοπικά (..\lib\settings.ahk) και απομακρυσμένα (raw GitHub)
; - Σύγκριση SemVer (vX.Y.Z)
; - Skip όταν ίσες/τοπική νεότερη, Proceed μόνο όταν remote νεότερη
; - Λήψη ZIP (main.zip) και κλήση submacros\update.bat με args:
;   1) πλήρης διαδρομή ZIP, 2) πλήρης ρίζα εφαρμογής (γονικός του submacros)
; Κανόνες: AHK v2, πολυγραμμικά if, πλήρη try/catch, χωρίς &&/\\.

class Updater
{
  ; ---------------------------- Public API ----------------------------
  static RunUpdateFlow(logger := 0)
  {
    ; 1) Internet check (NCSI) μέσω SSOT
    if (!Utils.CheckInternet()) {
      try {
        MsgBox("Δεν υπάρχει σύνδεση στο Internet. Παρακαλώ δοκιμάστε ξανά.", "Έλεγχος σύνδεσης", "Iconi")
      } catch {
      }
      return
    }

    ; 2) Εκδόσεις: υπολόγισε απόλυτο path του settings.ahk από το app root
    local settingsPath := Updater._getLocalSettingsPath()
    if (logger)
    {
      try {
        logger.Write("🔎 settings.ahk (local): " settingsPath)
        if FileExist(settingsPath) {
          logger.Write("✅ settings.ahk υπάρχει στο δίσκο.")
        } else {
          logger.Write("❌ settings.ahk ΔΕΝ βρέθηκε στο δίσκο.")
        }
      } catch {
      }
    }

    localVer := Updater._readLocalVersion(settingsPath, logger)
    if (localVer = "")
    {
      try {
        MsgBox("Αδυναμία ανάγνωσης τοπικής έκδοσης.", "Σφάλμα", "Iconx")
      } catch {
      }
      return
    }

    remoteUrl := "https://raw.githubusercontent.com/DeadManWalkingTO/ClearView/main/lib/settings.ahk"
    remoteVer := Updater._readRemoteVersion(remoteUrl, logger)
    if (remoteVer = "")
    {
      try {
        MsgBox("Αδυναμία ανάγνωσης απομακρυσμένης έκδοσης.", "Σφάλμα", "Iconx")
      } catch {
      }
      return
    }

    ; 3) Σύγκριση SemVer
    cmp := Updater._compareSemVer(localVer, remoteVer)
    if (cmp = 0)
    {
      try {
        MsgBox("Η έκδοση της εφαρμογής είναι η τελευταία και δεν χρειάζεται αναβάθμιση.", "Εγκατάσταση νέας έκδοσης", "Iconi")
      } catch {
      }
      ; SKIP when equal
      return
    }
    if (cmp = 1)
    {
      ; local > remote → πιθανό dev build. Μην κάνεις downgrade.
      try {
        MsgBox("Τρέχεις νεότερη έκδοση από την απομακρυσμένη. Η αναβάθμιση παραλείπεται.", "Εγκατάσταση νέας έκδοσης", "Iconi")
      } catch {
      }
      ; SKIP when local is newer
      return
    }

    ; 4) Proceed ONLY if remote > local (cmp = -1)
    if (logger)
    {
      try {
        logger.Write("⬇️ Διαθέσιμη νεότερη έκδοση: local=" localVer " → remote=" remoteVer)
      } catch {
      }
    }

    zipUrl := "https://github.com/DeadManWalkingTO/ClearView/archive/refs/heads/main.zip"
    tmpZip := Updater._composeTempZipPath()
    try {
      if FileExist(tmpZip) {
        FileDelete(tmpZip)
      }
    } catch {
    }

    ; Download ZIP (AHK v2: throws on error)
    try {
      Download(zipUrl, tmpZip)
      if (logger) {
        logger.Write("⬇️ Λήψη πακέτου αναβάθμισης: " zipUrl)
      }
    } catch {
      try {
        MsgBox("Αποτυχία λήψης πακέτου αναβάθμισης.", "Σφάλμα", "Iconx")
      } catch {
      }
      return
    }

    ; 5) Κλήση update.bat με:
    ; arg1 = zipPath, arg2 = appRoot (γονικός φάκελος του submacros)
    batPath := A_ScriptDir "\update.bat"
    appRoot := Updater._getAppRoot()

    ; Quoting με RegexLib για paths με κενά
    qBat := ""
    qZip := ""
    qRoot := ""
    try {
      qBat := RegexLib.Str.Quote(batPath)
      qZip := RegexLib.Str.Quote(tmpZip)
      qRoot := RegexLib.Str.Quote(appRoot)
    } catch {
      qBat := '"' batPath '"'
      qZip := '"' tmpZip '"'
      qRoot := '"' appRoot '"'
    }

    cmd := qBat " " qZip " " qRoot
    try {
      if (logger) {
        logger.Write("🛠️ Εκτέλεση updater: " batPath " (root=" appRoot ")")
      }
      Run(cmd, A_ScriptDir)
    } catch {
    }

    ; 6) Κλείσιμο εφαρμογής για να επιτραπεί η αντικατάσταση
    ExitApp
  }

  ; ---------------------------- Internals ----------------------------
  static _readLocalVersion(settingsPath, logger := 0) {
    ver := ""
    try {
      ; Προαιρετικό logging πριν το διάβασμα
      if (logger) {
        try {
          logger.Write("📄 Διαβάζω τοπική έκδοση από: " settingsPath)
        } catch {
        }
      }
      txt := ""
      try {
        txt := FileRead(settingsPath, "UTF-8")
      } catch Error as eRead {
        txt := ""
        if (logger) {
          try {
            logger.SafeErrorLog("⚠️ Αποτυχία FileRead(settings.ahk).", eRead)
          } catch {
          }
        }
      }
      if (txt != "") {
        ver := Updater._extractAppVersion(txt, logger)
      }
    } catch {
      ver := ""
    }
    if (ver = "") {
      if (logger) {
        try {
          logger.Write("⚠️ Δεν εξήχθη APP_VERSION από το settings.ahk.")
        } catch {
        }
      }
    }
    return ver
  }

  static _readRemoteVersion(rawUrl, logger := 0) {
    ver := ""
    tmp := A_Temp "\cv_remote_settings.ahk"
    try {
      if (logger) {
        try {
          logger.Write("🌐 Ανάκτηση απομακρυσμένης έκδοσης από: " rawUrl)
        } catch {
        }
      }
      Download(rawUrl, tmp)
      txt := FileRead(tmp, "UTF-8")
      ver := Updater._extractAppVersion(txt, logger)
    } catch {
      ver := ""
    }
    try {
      if FileExist(tmp) {
        FileDelete(tmp)
      }
    } catch {
    }
    return ver
  }

  static _extractAppVersion(text, logger := 0) {
    ; Εξαγωγή APP_VERSION με 4 βήματα (strict → fallback → γραμμή → οπουδήποτε)
    c := RegexLib.Chars

    ; (1) STRICT  — static APP_VERSION := "<vX.Y[.Z]>" με ίδιο quote αριστερά/δεξιά
    quoteClass := c.RAW_LBRKT . c.BS . c.DQ . RegexLib.Chars.SQT . c.RAW_RBRKT ; ["']
    versionCore := "v" . c.DIGIT . c.PLUS
    versionCore .= c.LPAREN . c.BS . c.DOT . c.DIGIT . c.PLUS . c.RPAREN . c.LBRACE . "0,2" . c.RBRACE
    grpQuote := c.LPAREN . quoteClass . c.RPAREN
    grpVer := c.LPAREN . versionCore . c.RPAREN
    backRef1 := c.BS . "1"
    pat1 := "m)static" . c.WS . c.PLUS . "APP_VERSION" . c.WS . c.STAR . c.COLON . c.EQUAL . c.WS . c.STAR
    pat1 .= grpQuote . grpVer . backRef1
    try {
      if RegExMatch(text, pat1, &m1) {
        return m1[2]
      }
    } catch {
      ; ignore
    }

    ; (2) FALLBACK — χωρίς απαίτηση ίδιου quote
    grpQuoteOpt := quoteClass . c.QMARK
    pat2 := "m)APP_VERSION" . c.WS . c.STAR . c.COLON . c.EQUAL . c.WS . c.STAR
    pat2 .= c.LPAREN . grpQuoteOpt . c.RPAREN
    pat2 .= grpVer
    pat2 .= c.LPAREN . grpQuoteOpt . c.RPAREN
    try {
      if RegExMatch(text, pat2, &m2) {
        return m2[2]
      }
    } catch {
      ; ignore
    }

    ; (3) Σάρωση γραμμής APP_VERSION (ασφαλής σύνθεση "m)^.*APP_VERSION.*$")
    patLine := "m)^" . c.DOT . c.STAR . "APP_VERSION" . c.DOT . c.STAR . "$"
    try {
      if RegExMatch(text, patLine, &mLine) {
        line := mLine[0]
        line := StrReplace(line, "`r")
        parts := StrSplit(line, ";")
        core := Trim(parts.Length >= 1 ? parts[1] : line)
        if (logger) {
          try {
            shown := core
            if (StrLen(shown) > 200) {
              shown := SubStr(shown, 1, 200) "…"
            }
            logger.Write("🔬 APP_VERSION line: " shown)
          } catch {
          }
        }
        ; Ασφαλής σύνθεση "m)v\d+(?:\.\d+){1,2}"
        patVer := "m)v" . c.DIGIT . c.PLUS
        patVer .= c.LPAREN . c.QMARK . c.COLON . c.BS . c.DOT . c.DIGIT . c.PLUS . c.RPAREN
        patVer .= c.LBRACE . "1,2" . c.RBRACE
        if RegExMatch(core, patVer, &mV) {
          return mV[0]
        }
      }
    } catch {
      ; ignore
    }

    ; (4) Last resort — ίδιο ασφαλές μοτίβο σε ολόκληρο το κείμενο
    pat3 := "m)v" . c.DIGIT . c.PLUS
    pat3 .= c.LPAREN . c.QMARK . c.COLON . c.BS . c.DOT . c.DIGIT . c.PLUS . c.RPAREN
    pat3 .= c.LBRACE . "1,2" . c.RBRACE
    try {
      if RegExMatch(text, pat3, &m3) {
        return m3[0]
      }
    } catch {
      ; ignore
    }
    return ""
  }

  static _compareSemVer(vLocal, vRemote) {
    a := Updater._parseSemVer(vLocal)
    b := Updater._parseSemVer(vRemote)
    if (a.major > b.major) {
      return 1
    }
    if (a.major < b.major) {
      return -1
    }
    if (a.minor > b.minor) {
      return 1
    }
    if (a.minor < b.minor) {
      return -1
    }
    if (a.patch > b.patch) {
      return 1
    }
    if (a.patch < b.patch) {
      return -1
    }
    return 0
  }

  static _parseSemVer(v) {
    res := { major: 0, minor: 0, patch: 0 }
    try {
      ver := v
      if (SubStr(ver, 1, 1) = "v") {
        ver := SubStr(ver, 2)
      }
      parts := StrSplit(ver, ".")
      if (parts.Length >= 1) {
        res.major := parts[1] + 0
      }
      if (parts.Length >= 2) {
        res.minor := parts[2] + 0
      }
      if (parts.Length >= 3) {
        res.patch := parts[3] + 0
      }
    } catch {
      res := { major: 0, minor: 0, patch: 0 }
    }
    return res
  }

  static _composeTempZipPath() {
    ts := ""
    try {
      ts := FormatTime(A_Now, "yyyyMMdd-HHmmss")
    } catch {
      ts := A_TickCount
    }
    return A_Temp "\ClearView-main-" ts ".zip"
  }

  static _getAppRoot() {
    ; Επιστρέφει τον γονικό φάκελο της τρέχουσας (submacros → app root).
    ; Χρησιμοποιούμε FSO για απόλυτη διαδρομή (normalize).
    p := ""
    try {
      fso := ComObject("Scripting.FileSystemObject")
      p := fso.GetAbsolutePathName(A_ScriptDir "\..")
    } catch {
      p := A_ScriptDir "\.."
    }
    return p
  }

  static _getLocalSettingsPath() {
    p := ""
    try {
      p := Updater._getAppRoot() "\lib\settings.ahk"
    } catch {
      p := ".\lib\settings.ahk" ; έσχατο fallback
    }
    return p
  }
}
; ==================== End Of File ====================
