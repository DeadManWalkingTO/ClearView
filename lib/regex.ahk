; ==================== lib/regex.ahk ====================
#Requires AutoHotkey v2.0

class RegexLib
{
  ; --------------------------------------------------------------------------------------
  ; Escape ειδικών regex χαρακτήρων μέσα σε απλό κείμενο.
  ; Παράδειγμα: RegexLib.Escape("a.b[c]") -> "a\.b\[c\]"
  ; --------------------------------------------------------------------------------------
  static Escape(str)
  {
    c := RegexLib.Chars
    ; Χτίζουμε: ([.\^\$\*\+\?\(\)\{\}\[\]\-\\])
    ; ΣΗΜ.: Για άνοιγμα/κλείσιμο character class χρησιμοποιούμε RAW_[LR]BRKT (ωμές αγκύλες)
    pat := c.LPAREN . c.RAW_LBRKT
      . c.DOT
      . c.BS . c.CARET
      . c.BS . c.DOLLAR
      . c.STAR                ; * μέσα σε character class είναι literal
      . c.PLUS                ; + μέσα σε character class είναι literal
      . c.QMARK
      . c.LPAREN . c.RPAREN
      . c.LBRACE . c.RBRACE   ; \{ \}
      . c.LBRKT . c.RBRKT    ; \[ \]
      . c.BS . c.DASH         ; \-
      . c.BS . c.BS           ; \\
      . c.RAW_RBRKT . c.RPAREN
    repl := c.BS . c.BS . "$1"  ; "\\$1" — προτάσσει μια ανάποδη κάθετο
    return RegExReplace(str, pat, repl)
  }

  ; --------------------------------------------------------------------------------------
  ; "Profile N" (N = αριθμός)
  ; --------------------------------------------------------------------------------------
  static IsProfileFolderName(name)
  {
    c := RegexLib.Chars
    pat := "^Profile" . c.WS . c.PLUS . c.DIGIT . c.PLUS . "$"
    return RegExMatch(name, pat) ? true : false
  }

  ; --------------------------------------------------------------------------------------
  ; Tokens για σύνθεση REGEX
  ; --------------------------------------------------------------------------------------
  class Chars
  {
    ; Απλοί χαρακτήρες
    static BS := Chr(92)   ; "\"
    static DQ := Chr(34)   ; "
    static SQT := Chr(39)  ; '
    static BACKTICK := Chr(96) ; `

    ; Escaped literals
    static LBRACE := Chr(92) . Chr(123) ; \{
    static RBRACE := Chr(92) . Chr(125) ; \}
    static LBRKT := Chr(92) . Chr(91)  ; \[
    static RBRKT := Chr(92) . Chr(93)  ; \]

    ; --- Raw bracket tokens (για χρήση σε character classes) ---
    static RAW_LBRKT := "["  ; raw '[' (για άνοιγμα character class)
    static RAW_RBRKT := "]"  ; raw ']' (για κλείσιμο character class)

    ; ΠΑΡΕΝΘΕΣΕΙΣ: χωρίς backslash για κανονικά groups
    static LPAREN := Chr(40) ; (
    static RPAREN := Chr(41) ; )

    static LT := Chr(92) . Chr(60) ; \<
    static GT := Chr(92) . Chr(62) ; \>
    static CARET := Chr(94)        ; ^
    static DASH := Chr(92) . Chr(45) ; \-
    static DOT := Chr(46)        ; .

    ; Quantifiers (μη-escaped)
    static STAR := Chr(42) ; *
    static PLUS := Chr(43) ; +
    ; Προαιρετικά literal-εκδόσεις
    static LIT_STAR := Chr(92) . Chr(42) ; \*
    static LIT_PLUS := Chr(92) . Chr(43) ; \+

    static QMARK := Chr(63)  ; ?
    static COLON := Chr(58)  ; :
    static COMMA := Chr(44)  ; ,
    static SLASH := Chr(47)  ; /
    static SPACE := Chr(32)  ; space
    static EQUAL := Chr(61)  ; =
    static DOLLAR := Chr(36) ; $
    static PIPE := Chr(92) . Chr(124) ; \|

    ; Regex tokens
    static WS := Chr(92) . Chr(115) ; \s
    static BIGS := Chr(92) . Chr(83)  ; \S
    static DIGIT := Chr(92) . Chr(100) ; \d
    static NDIGIT := Chr(92) . Chr(68) ; \D
    static WORD := Chr(92) . Chr(119) ; \w
    static NWORD := Chr(92) . Chr(87)  ; \W
  }

  ; --------------------------------------------------------------------------------------
  ; Δομικά στοιχεία για απλά STRINGS (όχι regex)
  ; --------------------------------------------------------------------------------------
  class Str
  {
    static DQ() {
      return Chr(34)
    }
    static BS() {
      return Chr(92)
    }
    static Quote(text)
    {
      return RegexLib.Str.DQ() . text . RegexLib.Str.DQ()
    }
    static JsonEscape(s)
    {
      s := StrReplace(s, RegexLib.Str.BS(), RegexLib.Str.BS() RegexLib.Str.BS())
      s := StrReplace(s, RegexLib.Chars.BACKTICK . "n", RegexLib.Chars.BS . "n")
      s := StrReplace(s, RegexLib.Chars.BACKTICK . "r", RegexLib.Chars.BS . "r")
      s := StrReplace(s, RegexLib.Str.DQ(), RegexLib.Str.BS() RegexLib.Str.DQ())
      return s
    }
    static EscapeQuoted(s)
    {
      return RegexLib.Chars.BS . "Q" . s . RegexLib.Chars.BS . "E"
    }
  }

  ; --------------------------------------------------------------------------------------
  ; Patterns για JSON parsing (Edge profiles)
  ; --------------------------------------------------------------------------------------
  static Pat_JsonObjectMinimal()
  {
    c := RegexLib.Chars
    ; \{ [\s\S]*? \}
    return c.LBRACE
      . c.LBRKT . c.WS . c.BIGS . c.RBRKT
      . c.STAR . c.QMARK
      . c.RBRACE
  }

  static Pat_JsonKeyQuotedString(key)
  {
    c := RegexLib.Chars
    ; \"key\"\s*:\s*\"([^\"]*)\"
    return c.BS . c.DQ . key . c.BS . c.DQ
      . c.WS . c.STAR . c.COLON . c.WS . c.STAR
      . c.BS . c.DQ
      . c.LPAREN . c.LBRKT . c.CARET . c.BS . c.DQ . c.RBRKT . c.STAR . c.RPAREN
      . c.BS . c.DQ
  }

  static Pat_JsonKeyNumber(key)
  {
    c := RegexLib.Chars
    ; \"key\"\s*:\s*(\-?\d+(?:\.\d+)?)
    return c.BS . c.DQ . key . c.BS . c.DQ
      . c.WS . c.STAR . c.COLON . c.WS . c.STAR
      . c.LPAREN
      . c.DASH . c.QMARK       ; optional '\-'
      . c.DIGIT . c.PLUS       ; \d+
      . c.LPAREN . c.QMARK . c.COLON ; (?: ... )
      . c.BS . c.DOT           ; \.
      . c.DIGIT . c.PLUS       ; \d+
      . c.RPAREN
      . c.RPAREN
  }

  ; --------------------------------------------------------------------------------------
  ; Edge profile parsing
  ; --------------------------------------------------------------------------------------
  static FindProfileDirInLocalState(localStateText, displayName)
  {
    if (localStateText = "")
      return ""

    c := RegexLib.Chars
    ; "profile": { "info_cache": { ... } }
    pat :=
      c.BS . c.DQ . "profile" . c.BS . c.DQ
      . c.WS . c.STAR . c.COLON . c.WS . c.STAR
      . c.LBRACE . c.WS . c.STAR
      . c.BS . c.DQ . "info_cache" . c.BS . c.DQ
      . c.WS . c.STAR . c.COLON . c.WS . c.STAR
      . c.LBRACE
      . c.LBRKT . c.WS . c.BIGS . c.RBRKT . c.STAR . c.QMARK
      . c.RBRACE . c.WS . c.STAR
      . c.RBRACE

    try {
      if !RegExMatch(localStateText, pat, &m) {
        return ""
      }
    } catch Error as e {
      return ""
    }

    cache := m[0]
    pos := 1

    ; "Profile X": {"name": "DisplayName", ...}
    p2 :=
      c.BS . c.DQ
      . c.LPAREN . c.LBRKT . c.CARET . c.BS . c.DQ . c.RBRKT . c.PLUS . c.RPAREN
      . c.BS . c.DQ
      . c.WS . c.STAR . c.COLON . c.WS . c.STAR
      . c.LBRACE
      . c.LBRKT . c.WS . c.BIGS . c.RBRKT . c.STAR
      . c.BS . c.DQ . "name" . c.BS . c.DQ
      . c.WS . c.STAR . c.COLON . c.WS . c.STAR
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

  ; --------------------------------------------------------------------------------------
  ; "name": "DisplayName" στον Preferences JSON
  ; --------------------------------------------------------------------------------------
  static PreferencesContainsProfileName(prefsText, displayName)
  {
    if (prefsText = "")
      return false

    c := RegexLib.Chars
    escName := RegexLib.Escape(displayName)

    ; "profile": {... "name": "DisplayName" ...}
    p1 :=
      c.BS . c.DQ . "profile" . c.BS . c.DQ
      . c.WS . c.STAR . c.COLON . c.WS . c.STAR
      . c.LBRACE
      . c.LBRKT . c.WS . c.BIGS . c.RBRKT . c.STAR
      . c.BS . c.DQ . "name" . c.BS . c.DQ
      . c.WS . c.STAR . c.COLON . c.WS . c.STAR
      . c.BS . c.DQ . escName . c.BS . c.DQ

    if RegExMatch(prefsText, p1) {
      return true
    }

    ; Fallback: οποιοδήποτε "name": "DisplayName"
    p2 :=
      c.BS . c.DQ . "name" . c.BS . c.DQ
      . c.WS . c.STAR . c.COLON . c.WS . c.STAR
      . c.BS . c.DQ . escName . c.BS . c.DQ

    if RegExMatch(prefsText, p2) {
      return true
    }
    return false
  }
}
; ==================== End Of File ====================
