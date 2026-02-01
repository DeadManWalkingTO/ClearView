; ==================== lib/versions.ahk ====================
#Requires AutoHotkey v2.0
#Include "regex.ahk"

; Στόχος: SSOT για έλεγχο εκδόσεων.
; Κανόνες: AHK v2, πολυγραμμικά if, πλήρη try/catch, χωρίς &&/||.
class Versions
{
  ; ---------------- Paths ----------------
  static GetAppRoot()
  {
    p := ""
    try {
      fso := ComObject("Scripting.FileSystemObject")
      p := fso.GetAbsolutePathName(A_ScriptDir "\..")
    } catch {
      p := A_ScriptDir "\.."
    }
    return p
  }

  static GetLocalSettingsPath()
  {
    p := ""
    try {
      p := Versions.GetAppRoot() "\lib\settings.ahk"
    } catch {
      p := ".\lib\settings.ahk"
    }
    return p
  }

  ; ---------------- I/O helpers ----------------
  static _TryReadText(path)
  {
    try {
      return FileRead(path, "UTF-8")
    } catch {
      return ""
    }
  }

  static TryDownloadText(url, timeoutMs := 4000, logger := 0)
  {
    try {
      if (logger) {
        try {
          logger.Write("🌐 GET " url " (timeout=" timeoutMs "ms)")
        } catch {
        }
      }
      whr := ComObject("WinHttp.WinHttpRequest.5.1")
      whr.Open("GET", url, true)
      whr.SetTimeouts(timeoutMs, timeoutMs, timeoutMs, timeoutMs)
      whr.Send()
      whr.WaitForResponse(timeoutMs)
      txt := ""
      try {
        txt := whr.ResponseText
      } catch {
        txt := ""
      }
      return txt
    } catch Error as e {
      try {
        if (logger) {
          logger.SafeErrorLog("⚠️ TryDownloadText failed.", e)
        }
      } catch {
      }
      return ""
    }
  }

  ; ---------------- Version extraction ----------------
  ; Εξαγωγή APP_VERSION από κείμενο settings.ahk.
  ; Χρησιμοποιεί ασφαλή patterns από RegexLib.Chars (ίδια λογική με παλιό updater).

  static ExtractAppVersion(text, logger := 0)
  {
    if (text = "") {
      return ""
    }
    c := RegexLib.Chars

    ; (1) STRICT
    quoteClass := c.RAW_LBRKT . c.BS . c.DQ . RegexLib.Chars.SQT . c.RAW_RBRKT  ; ["']
    versionCore := "v" . c.DIGIT . c.PLUS
    ; ΠΡΙΝ:  versionCore .= c.LPAREN . c.BS . c.DOT . c.DIGIT . c.PLUS . c.RPAREN . c.LBRACE . "0,2" . c.RBRACE
    ; META:  ωμές αγκύλες για quantifier
    versionCore .= c.LPAREN . c.BS . c.DOT . c.DIGIT . c.PLUS . c.RPAREN . "{0,2}"

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

    ; (2) FALLBACK (χωρίς απαίτηση ίδιου quote)
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

    ; (3) Σάρωση γραμμής -> match του core "vX.Y[.Z]"
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
        ; ΠΡΙΝ: patVer .= c.LBRACE . "1,2" . c.RBRACE
        ; META: ωμές αγκύλες
        patVer := "m)v" . c.DIGIT . c.PLUS
        patVer .= c.LPAREN . c.QMARK . c.COLON . c.BS . c.DOT . c.DIGIT . c.PLUS . c.RPAREN
        patVer .= "{1,2}"
        if RegExMatch(core, patVer, &mV) {
          return mV[0]
        }
      }
    } catch {
      ; ignore
    }

    ; (4) Τελευταίο fallback: ίδιο pattern στο πλήρες κείμενο
    ; ΠΡΙΝ: pat3 .= c.LBRACE . "1,2" . c.RBRACE
    ; META: ωμές αγκύλες
    pat3 := "m)v" . c.DIGIT . c.PLUS
    pat3 .= c.LPAREN . c.QMARK . c.COLON . c.BS . c.DOT . c.DIGIT . c.PLUS . c.RPAREN
    pat3 .= "{1,2}"
    try {
      if RegExMatch(text, pat3, &m3) {
        return m3[0]
      }
    } catch {
      ; ignore
    }

    return ""
  }


  static TryReadLocalAppVersion(settingsPath, logger := 0)
  {
    if (logger) {
      try {
        logger.Write("📄 Διαβάζω τοπική έκδοση από: " settingsPath)
      } catch {
      }
    }
    txt := Versions._TryReadText(settingsPath)
    if (txt = "") {
      return ""
    }
    return Versions.ExtractAppVersion(txt, logger)
  }

  static TryGetRemoteAppVersion(rawUrl, timeoutMs := 4000, logger := 0)
  {
    if (logger) {
      try {
        logger.Write("🌐 Ανάκτηση απομακρυσμένης έκδοσης από: " rawUrl)
      } catch {
      }
    }
    txt := Versions.TryDownloadText(rawUrl, timeoutMs, logger)
    if (txt = "") {
      return ""
    }
    return Versions.ExtractAppVersion(txt, logger)
  }

  ; ---------------- SemVer ----------------
  static ParseSemVer(v)
  {
    res := { major: 0, minor: 0, patch: 0 }
    try {
      s := v
      if (SubStr(s, 1, 1) = "v") {
        s := SubStr(s, 2)
      }
      p := StrSplit(s, ".")
      if (p.Length >= 1) {
        res.major := p[1] + 0
      }
      if (p.Length >= 2) {
        res.minor := p[2] + 0
      }
      if (p.Length >= 3) {
        res.patch := p[3] + 0
      }
    } catch {
      res := { major: 0, minor: 0, patch: 0 }
    }
    return res
  }

  static CompareSemVer(aV, bV)
  {
    a := Versions.ParseSemVer(aV)
    b := Versions.ParseSemVer(bV)

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
}
; ==================== End Of File ====================
