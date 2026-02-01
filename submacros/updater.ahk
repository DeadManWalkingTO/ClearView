; ==================== submacros/updater.ahk ====================
#Requires AutoHotkey v2.0
#Include "..\lib\settings.ahk"
#Include "..\lib\regex.ahk"

; Updater
; - Έλεγχος Internet (NCSI-like)
; - Ανάγνωση έκδοσης τοπικά (..\lib\settings.ahk) και απομακρυσμένα (raw GitHub)
; - Σύγκριση SemVer (vX.Y.Z)
; - Skip όταν ίσες/τοπική νεότερη, Proceed μόνο όταν remote νεότερη
; - Λήψη ZIP (main.zip) και κλήση submacros\update.bat με args:
;     1) πλήρης διαδρομή ZIP, 2) πλήρης ρίζα εφαρμογής (γονικός του submacros)
; Κανόνες: AHK v2, πολυγραμμικά if, πλήρη try/catch, χωρίς &&/||.

class Updater
{
  ; -----------------------------
  ; Public API
  ; -----------------------------
  static RunUpdateFlow(logger := 0)
  {
    ; 1) Internet check (NCSI)
    if (!Updater._checkInternet())
    {
      try
      {
        MsgBox("Δεν υπάρχει σύνδεση στο Internet. Παρακαλώ δοκιμάστε ξανά.", "Έλεγχος σύνδεσης", "Iconi")
      }
      catch
      {
      }
      return
    }

    ; 2) Εκδόσεις
    localVer := Updater._readLocalVersion("..\lib\settings.ahk")
    if (localVer = "")
    {
      try
      {
        MsgBox("Αδυναμία ανάγνωσης τοπικής έκδοσης.", "Σφάλμα", "Iconx")
      }
      catch
      {
      }
      return
    }

    remoteUrl := "https://raw.githubusercontent.com/DeadManWalkingTO/ClearView/main/lib/settings.ahk"
    remoteVer := Updater._readRemoteVersion(remoteUrl)
    if (remoteVer = "")
    {
      try
      {
        MsgBox("Αδυναμία ανάγνωσης απομακρυσμένης έκδοσης.", "Σφάλμα", "Iconx")
      }
      catch
      {
      }
      return
    }

    ; 3) Σύγκριση SemVer
    cmp := Updater._compareSemVer(localVer, remoteVer)

    if (cmp = 0)
    {
      try
      {
        MsgBox("Η έκδοση της εφαρμογής είναι η τελευταία και δεν χρειάζεται αναβάθμιση.", "Εγκατάσταση νέας έκδοσης", "Iconi")
      }
      catch
      {
      }
      ; SKIP when equal
      return
    }

    if (cmp = 1)
    {
      ; local > remote → πιθανό dev build. Μην κάνεις downgrade.
      try
      {
        MsgBox("Τρέχεις νεότερη έκδοση από την απομακρυσμένη. Η αναβάθμιση παραλείπεται.", "Εγκατάσταση νέας έκδοσης", "Iconi")
      }
      catch
      {
      }
      ; SKIP when local is newer
      return
    }

    ; 4) Proceed ONLY if remote > local (cmp = -1)
    if (logger)
    {
      try
      {
        logger.Write("⬇️ Διαθέσιμη νεότερη έκδοση: local=" localVer " → remote=" remoteVer)
      }
      catch
      {
      }
    }

    ; 5) Λήψη ZIP
    zipUrl := "https://github.com/DeadManWalkingTO/ClearView/archive/refs/heads/main.zip"
    zipPath := Updater._composeTempZipPath()

    try
    {
      if FileExist(zipPath)
      {
        FileDelete(zipPath)
      }
    }
    catch
    {
    }

    try
    {
      Download(zipUrl, zipPath)  ; AHK v2: ρίχνει εξαίρεση σε αποτυχία
      if (logger)
      {
        logger.Write("⬇️ Λήψη πακέτου αναβάθμισης: " zipUrl)
      }
    }
    catch
    {
      try
      {
        MsgBox("Αποτυχία λήψης πακέτου αναβάθμισης.", "Σφάλμα", "Iconx")
      }
      catch
      {
      }
      return
    }

    ; 6) Κλήση update.bat με:
    ;    arg1 = zipPath, arg2 = appRoot (γονικός φάκελος του submacros)
    batPath := A_ScriptDir "\update.bat"   ; ⬅️ ΕΔΩ: submacros\update.bat (ίδιος φάκελος με updater.ahk)
    appRoot := Updater._getAppRoot()

    ; Quoting με RegexLib για paths με κενά
    qBat := ""
    qZip := ""
    qRoot := ""
    try
    {
      qBat := RegexLib.Str.Quote(batPath)
      qZip := RegexLib.Str.Quote(zipPath)
      qRoot := RegexLib.Str.Quote(appRoot)
    }
    catch
    {
      qBat := '"' batPath '"'
      qZip := '"' zipPath '"'
      qRoot := '"' appRoot '"'
    }

    cmd := qBat " " qZip " " qRoot

    try
    {
      if (logger)
      {
        logger.Write("🛠️ Εκτέλεση updater: " batPath " (root=" appRoot ")")
      }
      Run(cmd, A_ScriptDir)
    }
    catch
    {
    }

    ; 7) Κλείσιμο εφαρμογής για να επιτραπεί η αντικατάσταση
    ExitApp
  }

  ; -----------------------------
  ; Internals
  ; -----------------------------
  static _checkInternet(timeoutMs := 3000)
  {
    ; NCSI-like probe: περιμένουμε ακριβές "Microsoft Connect Test"
    url := "http://www.msftconnecttest.com/connecttest.txt"
    ok := false
    try
    {
      whr := ComObject("WinHttp.WinHttpRequest.5.1")
      whr.Open("GET", url, true)
      whr.SetTimeouts(timeoutMs, timeoutMs, timeoutMs, timeoutMs)
      whr.Send()
      whr.WaitForResponse(timeoutMs)
      txt := ""
      try
      {
        txt := whr.ResponseText
      }
      catch
      {
        txt := ""
      }
      if (txt = "Microsoft Connect Test")
      {
        ok := true
      }
    }
    catch
    {
      ok := false
    }
    return ok
  }

  static _readLocalVersion(settingsPath)
  {
    ver := ""
    try
    {
      txt := FileRead(settingsPath, "UTF-8")
      ver := Updater._extractAppVersion(txt)
    }
    catch
    {
      ver := ""
    }
    return ver
  }

  static _readRemoteVersion(rawUrl)
  {
    ver := ""
    tmp := A_Temp "\cv_remote_settings.ahk"
    try
    {
      Download(rawUrl, tmp)
      txt := FileRead(tmp, "UTF-8")
      ver := Updater._extractAppVersion(txt)
    }
    catch
    {
      ver := ""
    }
    try
    {
      if FileExist(tmp)
      {
        FileDelete(tmp)
      }
    }
    catch
    {
    }
    return ver
  }

  static _extractAppVersion(text)
  {
    ; Εξαγωγή του APP_VERSION με βοήθεια RegexLib.Chars για ανθεκτικό pattern:
    ; Δέχεται π.χ.  static APP_VERSION := "v6.22.20"  ή με '…'
    c := RegexLib.Chars

    quoteClass := c.RAW_LBRKT . c.BS . c.DQ . RegexLib.Chars.SQT . c.RAW_RBRKT
    versionCore := "v" . c.DIGIT . c.PLUS
    versionCore .= c.LPAREN . c.BS . c.DOT . c.DIGIT . c.PLUS . c.RPAREN . c.LBRACE . "0,2" . c.RBRACE

    grpQuote := c.LPAREN . quoteClass . c.RPAREN
    grpVer := c.LPAREN . versionCore . c.RPAREN
    backRef1 := c.BS . "1"

    pat := "m)static" . c.WS . c.PLUS . "APP_VERSION" . c.WS . c.STAR . c.COLON . c.EQUAL . c.WS . c.STAR
    pat .= grpQuote . grpVer . backRef1

    try
    {
      if RegExMatch(text, pat, &m)
      {
        return m[2]  ; vX.Y.Z
      }
    }
    catch
    {
    }
    return ""
  }

  static _compareSemVer(vLocal, vRemote)
  {
    ; returns -1 if local<remote, 0 if equal, +1 if local>remote
    a := Updater._parseSemVer(vLocal)
    b := Updater._parseSemVer(vRemote)

    if (a.major > b.major)
    {
      return 1
    }
    if (a.major < b.major)
    {
      return -1
    }
    if (a.minor > b.minor)
    {
      return 1
    }
    if (a.minor < b.minor)
    {
      return -1
    }
    if (a.patch > b.patch)
    {
      return 1
    }
    if (a.patch < b.patch)
    {
      return -1
    }
    return 0
  }

  static _parseSemVer(v)
  {
    res := { major: 0, minor: 0, patch: 0 }
    try
    {
      ver := v
      if (SubStr(ver, 1, 1) = "v")
      {
        ver := SubStr(ver, 2)
      }
      parts := StrSplit(ver, ".")
      if (parts.Length >= 1)
      {
        res.major := parts[1] + 0
      }
      if (parts.Length >= 2)
      {
        res.minor := parts[2] + 0
      }
      if (parts.Length >= 3)
      {
        res.patch := parts[3] + 0
      }
    }
    catch
    {
      res := { major: 0, minor: 0, patch: 0 }
    }
    return res
  }

  static _composeTempZipPath()
  {
    ts := ""
    try
    {
      ts := FormatTime(A_Now, "yyyyMMdd-HHmmss")
    }
    catch
    {
      ts := A_TickCount
    }
    return A_Temp "\ClearView-main-" ts ".zip"
  }

  static _getAppRoot()
  {
    ; Επιστρέφει τον γονικό φάκελο της τρέχουσας (submacros → app root).
    ; Χρησιμοποιούμε FSO για απόλυτη διαδρομή (normalize).
    p := ""
    try
    {
      fso := ComObject("Scripting.FileSystemObject")
      p := fso.GetAbsolutePathName(A_ScriptDir "\..")
    }
    catch
    {
      p := A_ScriptDir "\.."
    }
    return p
  }
}
; ==================== End Of File ====================
