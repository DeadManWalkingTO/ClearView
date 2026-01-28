; ==================== lib/regex.ahk ====================
#Requires AutoHotkey v2.0

class RegexLib {
  ; --- Υφιστάμενα ---
  static Escape(str) {
    ; Escape ειδικών regex χαρακτήρων
    return RegExReplace(str, "([\.^$*+?(){}\[\]\-\\])", "\\$1")
  }

  static FindProfileDirInLocalState(localStateText, displayName) {
    if (localStateText == "")
      return ""
    ; "profile": { "info_cache": { ... } }
    pat := '"profile"\s*:\s*\{\s*"info_cache"\s*:\s*\{([\s\S]*?)\}\s*\}'
    if !RegExMatch(localStateText, pat, &m)
      return ""
    cache := m[1], pos := 1
    escName := RegexLib.Escape(displayName)
    ; "Profile X": {"name": "Display Name", ...}
    while RegExMatch(cache, '"([^"\\]+)"\s*:\s*\{[^}]*"name"\s*:\s*"([^"\\]+)"', &mm, pos) {
      dir := mm[1], nm := mm[2]
      if (nm == displayName)
        return dir
      pos := mm.Pos(0) + mm.Len(0)
    }
    return ""
  }

  static PreferencesContainsProfileName(prefsText, displayName) {
    if (prefsText == "")
      return false
    escName := RegexLib.Escape(displayName)
    if RegExMatch(prefsText, '"profile"\s*:\s*\{[^}]*"name"\s*:\s*"' escName '"')
      return true
    if RegExMatch(prefsText, '"name"\s*:\s*"' escName '"')
      return true
    return false
  }

  static IsProfileFolderName(name) {
    return RegExMatch(name, "^Profile\s+\d+$") ? true : false
  }

  ; --- ΝΕΑ: Δομικά στοιχεία ανά χαρακτήρα (για σύνθεση regex) ---
  class Chars {
    ; Βασικοί χαρακτήρες/μετα-χαρακτήρες (για regex)
    static BS := "\"                  ; backslash
    static DQ := Chr(34)             ; double-quote
    static LBRACE := "{"
    static RBRACE := "}"
    static LBRKT := "["
    static RBRKT := "]"
    static LPAREN := "("
    static RPAREN := ")"
    static CARET := "^"
    static DASH := "-"
    static DOT := "."
    static STAR := "*"
    static PLUS := "+"
    static QMARK := "?"
    static COLON := ":"
    ; Σύνθετα (regex tokens)
    static WS := "\s"
    static BIGS := "\S"
    static DIGIT := "\d"
  }

  ; --- ΝΕΑ: Helpers για ασφαλή σύνθεση ΑΠΛΩΝ STRINGS (όχι regex) ---
  class Str {
    ; Ασφαλές διπλό-εισαγωγικό: χρησιμοποιούμε Chr(34) αντί να γράφουμε " μέσα σε string
    static DQ() {
      return Chr(34)
    }
    ; Ασφαλές backslash για απλά strings
    static BS() {
      return "\"
    }
    ; Γρήγορο wrapper: περιβάλλει κείμενο με "..."
    static Quote(text) {
      ; Εδώ δεν πειράζουμε το περιεχόμενο, απλά βάζουμε DQ στην αρχή/τέλος
      return RegexLib.Str.DQ() . text . RegexLib.Str.DQ()
    }
    ; Escape για JSON string (αν θες να αποφύγεις εντελώς JsonEscape)
    static JsonEscape(s) {
      ; Ίδια λογική με JsonEscape του cdp: \ -> \\, `n -> \n, `r -> \r, " -> \"
      s := StrReplace(s, RegexLib.Str.BS(), RegexLib.Str.BS() RegexLib.Str.BS())
      s := StrReplace(s, "`n", "\n")
      s := StrReplace(s, "`r", "\r")
      s := StrReplace(s, RegexLib.Str.DQ(), RegexLib.Str.BS() RegexLib.Str.DQ())
      return s
    }
  }

  ; --- Helpers για CDP (regex) ---

  ; Ελάχιστο αντικείμενο JSON: \{[\s\S]*?\}
  static Pat_JsonObjectMinimal() {
    c := RegexLib.Chars
    return c.BS . c.LBRACE
      . c.LBRKT . c.WS . c.BIGS . c.RBRKT
      . c.STAR . c.QMARK
      . c.BS . c.RBRACE
  }

  ; "key": "value"  -> "\"key\"\s*:\s*\"([^\"]*)\""
  static Pat_JsonKeyQuotedString(key) {
    c := RegexLib.Chars
    return c.BS . c.DQ . key . c.BS . c.DQ
      . c.WS . c.STAR . c.COLON . c.WS . c.STAR
      . c.BS . c.DQ
      . c.LPAREN . c.LBRKT . c.CARET . c.BS . c.DQ . c.RBRKT . c.STAR . c.RPAREN
      . c.BS . c.DQ
  }

  ; "key": -?\d+(?:\.\d+)?  -> "\"key\"\s*:\s*(-?\d+(?:\.\d+)?)"
  static Pat_JsonKeyNumber(key) {
    c := RegexLib.Chars
    return c.BS . c.DQ . key . c.BS . c.DQ
      . c.WS . c.STAR . c.COLON . c.WS . c.STAR
      . c.LPAREN
      . c.DASH . "?"            ; optional '-'
      . c.DIGIT . c.PLUS        ; integer part
      . c.LPAREN . "?" . c.COLON ; (?: ... )
      . c.BS . c.DOT          ; \.
      . c.DIGIT . c.PLUS      ; \d+
      . c.RPAREN . c.QMARK      ; )?
      . c.RPAREN
  }
}
; ==================== End Of File ====================
