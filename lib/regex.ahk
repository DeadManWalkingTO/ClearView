; ==================== lib/regex.ahk ====================
#Requires AutoHotkey v2.0

class RegexLib {
  ; ---------------------------------------------------------------------------
  ; Γενικά helpers
  ; ---------------------------------------------------------------------------

  /**
   * Escape ειδικών regex χαρακτήρων μέσα σε απλό κείμενο.
   * Παράδειγμα: RegexLib.Escape("a.b[c]") -> "a\.b\[c\]"
   * Υλοποίηση: σύνθεση του pattern με RegexLib.Chars (χωρίς ωμά "\").
   */
  static Escape(str) {
    c := RegexLib.Chars
    ; Χτίζουμε "([\.\^\$\*\+\?\(\)\{\}\[\]\-\\])" ως δηλωτικό pattern:
    pat := c.LPAREN . c.LBRKT
      . c.DOT
      . c.BS . c.CARET
      . c.BS . c.DOLLAR
      . c.STAR
      . c.PLUS
      . c.QMARK
      . c.LPAREN . c.RPAREN
      . c.LBRACE . c.RBRACE
      . c.LBRKT . c.RBRKT
      . c.BS . c.DASH
      . c.BS . c.BS
      . c.RBRKT . c.RPAREN
    repl := c.BS . c.BS . "$1"       ; ισοδύναμο του "\\$1"
    return RegExReplace(str, pat, repl)
  }

  /**
   * Επιστρέφει true αν το όνομα φακέλου ταιριάζει σε μορφή "Profile N" (N=αριθμός).
   */
  static IsProfileFolderName(name) {
    c := RegexLib.Chars
    ; "Profile\s+\d+$"
    pat := "^Profile" . c.WS . "+" . "\d" . "+" . "$"
    return RegExMatch(name, pat) ? true : false
  }

  ; ---------------------------------------------------------------------------
  ; Δομικά στοιχεία για σύνθεση Regex — ανά χαρακτήρα / token
  ; ---------------------------------------------------------------------------
  class Chars {
    ; Βασικοί χαρακτήρες (για regex ΚΑΙ απλά strings)
    static BS := "\"           ; backslash
    static DQ := Chr(34)       ; double-quote
    static SQT := "'"           ; single-quote
    static BACKTICK := Chr(96)       ; backtick (AHK escape)  ⟵ ΔΙΟΡΘΩΣΗ: ΟΧΙ "`"
    static LBRACE := "{"
    static RBRACE := "}"
    static LBRKT := "["
    static RBRKT := "]"
    static LPAREN := "("
    static RPAREN := ")"
    static LT := "<"
    static GT := ">"
    static CARET := "^"
    static DASH := "-"
    static DOT := "."
    static STAR := "*"
    static PLUS := "+"
    static QMARK := "?"
    static COLON := ":"
    static COMMA := ","
    static SLASH := "/"
    static SPACE := " "
    static EQUAL := "="
    static DOLLAR := "$"
    static PIPE := "|"

    ; Regex tokens (PCRE)
    static WS := "\s"          ; whitespace
    static BIGS := "\S"          ; non-whitespace
    static DIGIT := "\d"          ; digit
    static NDIGIT := "\D"          ; non-digit
    static WORD := "\w"          ; [A-Za-z0-9_]
    static NWORD := "\W"
  }

  ; ---------------------------------------------------------------------------
  ; Δομικά στοιχεία για σύνθεση ΑΠΛΩΝ STRINGS (όχι regex)
  ; ---------------------------------------------------------------------------
  class Str {
    /**
     * Ασφαλές διπλό-εισαγωγικό.
     */
    static DQ() {
      return Chr(34)
    }

    /**
     * Ασφαλές backslash για απλά strings.
     */
    static BS() {
      return "\"
    }

    /**
     * Περιβάλλει κείμενο με "..."
     */
    static Quote(text) {
      return RegexLib.Str.DQ() . text . RegexLib.Str.DQ()
    }

    /**
     * JSON-escape για απλό string:
     * \ -> \\ · `n -> \n · `r -> \r · " -> \"
     */
    static JsonEscape(s) {
      s := StrReplace(s, RegexLib.Str.BS(), RegexLib.Str.BS() RegexLib.Str.BS())
      s := StrReplace(s, RegexLib.Chars.BACKTICK . "n", "\n")
      s := StrReplace(s, RegexLib.Chars.BACKTICK . "r", "\r")
      s := StrReplace(s, RegexLib.Str.DQ(), RegexLib.Str.BS() RegexLib.Str.DQ())
      return s
    }

    /**
     * PCRE \Q...\E literal quoting για ΟΛΟ το string (χρήσιμο εκτός character classes).
     */
    static EscapeQuoted(s) {
      return RegexLib.Chars.BS . "Q" . s . RegexLib.Chars.BS . "E"
    }
  }

  ; ---------------------------------------------------------------------------
  ; Βοηθητικά Regex Patterns για JSON (CDP / WinHttp σενάρια)
  ; ---------------------------------------------------------------------------

  /**
   * Ελάχιστο αντικείμενο JSON: \{[\s\S]*?\}
   */
  static Pat_JsonObjectMinimal() {
    c := RegexLib.Chars
    return c.BS . c.LBRACE
      . c.LBRKT . c.WS . c.BIGS . c.RBRKT
      . c.STAR . c.QMARK
      . c.BS . c.RBRACE
  }

  /**
   * "key": "value"  -> "\"key\"\s*:\s*\"([^\"]*)\""
   */
  static Pat_JsonKeyQuotedString(key) {
    c := RegexLib.Chars
    return c.BS . c.DQ . key . c.BS . c.DQ
      . c.WS . c.STAR . c.COLON . c.WS . c.STAR
      . c.BS . c.DQ
      . c.LPAREN . c.LBRKT . c.CARET . c.BS . c.DQ . c.RBRKT . c.STAR . c.RPAREN
      . c.BS . c.DQ
  }

  /**
   * "key": -?\d+(?:\.\d+)?  -> "\"key\"\s*:\s*(-?\d+(?:\.\d+)?)"
   */
  static Pat_JsonKeyNumber(key) {
    c := RegexLib.Chars
    return c.BS . c.DQ . key . c.BS . c.DQ
      . c.WS . c.STAR . c.COLON . c.WS . c.STAR
      . c.LPAREN
      . c.DASH . c.QMARK          ; optional '-'
      . c.DIGIT . c.PLUS          ; integer part
      . c.LPAREN . c.QMARK . c.COLON  ; (?: ... )
      . c.BS . c.DOT            ; \.
      . c.DIGIT . c.PLUS        ; \d+
      . c.RPAREN
      . c.RPAREN
  }

  ; ---------------------------------------------------------------------------
  ; Βοηθητικά για Edge προφίλ (parsing JSON-σαν κείμενα από αρχεία)
  ; ---------------------------------------------------------------------------

  /**
   * Από το περιεχόμενο του "Local State" (JSON ως string), βρίσκει το όνομα
   * φακέλου προφίλ (π.χ. "Default" ή "Profile 2") που έχει "name" == displayName.
   */
  static FindProfileDirInLocalState(localStateText, displayName) {
    if (localStateText = "")
      return ""
    c := RegexLib.Chars
    ; "profile": { "info_cache": { ... } }
    pat := c.BS . c.DQ . "profile" . c.BS . c.DQ
      . c.WS . c.STAR . c.COLON . c.WS . c.STAR
      . c.BS . c.LBRACE . c.WS . c.STAR
      . c.BS . c.DQ . "info_cache" . c.BS . c.DQ
      . c.WS . c.STAR . c.COLON . c.WS . c.STAR
      . c.BS . c.LBRACE
      . c.LBRKT . c.WS . c.BIGS . c.RBRKT . c.STAR . c.QMARK
      . c.BS . c.RBRACE . c.WS . c.STAR
      . c.BS . c.RBRACE
    try {
      if !RegExMatch(localStateText, pat, &m) {
        return ""
      }
    } catch Error as e {
      return ""
    }
    cache := m[0]
    pos := 1
    ; "Profile X": {"name": "Display Name", ...}
    p2 := c.BS . c.DQ
      . c.LPAREN . c.LBRKT . c.CARET . c.BS . c.DQ . c.RBRKT . c.PLUS . c.RPAREN
      . c.BS . c.DQ . c.WS . c.STAR . c.COLON . c.WS . c.STAR
      . c.BS . c.LBRACE
      . c.LBRKT . c.WS . c.BIGS . c.RBRKT . c.STAR
      . c.BS . c.DQ . "name" . c.BS . c.DQ . c.WS . c.STAR . c.COLON . c.WS . c.STAR
      . c.BS . c.DQ
      . c.LPAREN . c.LBRKT . c.CARET . c.BS . c.DQ . c.RBRKT . c.PLUS . c.RPAREN
      . c.BS . c.DQ
    try {
      while RegExMatch(cache, p2, &mm, pos) {
        dir := mm[1]
        nm := mm[2]
        if (nm = displayName) {
          return dir
        }
        pos := mm.Pos(0) + mm.Len(0)
      }
    } catch Error as e {
      ; ignore
    }
    return ""
  }

  /**
   * Ελέγχει αν κάποιο JSON-σαν κείμενο (π.χ. Preferences) περιέχει όνομα προφίλ.
   */
  static PreferencesContainsProfileName(prefsText, displayName) {
    if (prefsText = "")
      return false
    c := RegexLib.Chars
    escName := RegexLib.Escape(displayName)
    ; "profile": {... "name": "..." ...}
    p1 := c.BS . c.DQ . "profile" . c.BS . c.DQ
      . c.WS . c.STAR . c.COLON . c.WS . c.STAR
      . c.BS . c.LBRACE
      . c.LBRKT . c.WS . c.BIGS . c.RBRKT . c.STAR
      . c.BS . c.DQ . "name" . c.BS . c.DQ
      . c.WS . c.STAR . c.COLON . c.WS . c.STAR
      . c.BS . c.DQ . escName . c.BS . c.DQ
    if RegExMatch(prefsText, p1) {
      return true
    }
    ; fallback: οποιοδήποτε "name": "..."
    p2 := c.BS . c.DQ . "name" . c.BS . c.DQ
      . c.WS . c.STAR . c.COLON . c.WS . c.STAR
      . c.BS . c.DQ . escName . c.BS . c.DQ
    if RegExMatch(prefsText, p2) {
      return true
    }
    return false
  }
}
; ==================== End Of File ====================
