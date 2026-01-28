; ==================== lib/json.ahk ====================
#Requires AutoHotkey v2.0
#Include "regex.ahk"

; -----------------------------------------------------------------------------
; JSON helpers (stringify & escape) με χρήση RegexLib.Str/Chars
; -----------------------------------------------------------------------------
; Κανόνες:
; - AHK v2: χωρίς && / ||, πλήρη try/catch όπου χρειάζεται.
; - Ασφαλής χειρισμός των ειδικών χαρακτήρων με RegexLib.Str.JsonEscape().
; - Υποστηρίζονται: Map, Array, Integer, Float, String, Object/ComObject, true/false, "".
; -----------------------------------------------------------------------------

/**
 * JsonStringify(v)
 * Μετατρέπει μια AHK τιμή σε JSON string (best-effort).
 * - Map      -> {"key":value,...}
 * - Array    -> [value,...]
 * - Number   -> 123 / 1.23
 * - String   -> "escaped"
 * - Object   -> "object to string" (ως quoted string)
 * - true/false -> true/false
 * - ""       -> ""
 */
JsonStringify(v) {
  local t, s, first, k, val, dq, bs
  dq := RegexLib.Str.DQ()
  bs := RegexLib.Str.BS()

  t := Type(v)

  if (t = "Map") {
    s := "{"
    first := true
    for k, val in v {
      if (!first) {
        s .= ","
      }
      first := false
      ; "key": JsonStringify(val)
      s .= bs . dq . JsonEscape(String(k)) . bs . dq
      s .= ":" . JsonStringify(val)
    }
    s .= "}"
    return s

  } else if (t = "Array") {
    s := "["
    first := true
    for _, val in v {
      if (!first) {
        s .= ","
      }
      first := false
      s .= JsonStringify(val)
    }
    s .= "]"
    return s

  } else if (t = "Integer") {
    return String(v)

  } else if (t = "Float") {
    return String(v)

  } else if (t = "String") {
    ; "escaped string"
    return bs . dq . JsonEscape(v) . bs . dq

  } else if (t = "Object") {
    ; Best-effort: μετατρέπουμε σε string και το κάνουμε quoted
    return bs . dq . JsonEscape(String(v)) . bs . dq

  } else if (t = "ComObject") {
    return bs . dq . JsonEscape(String(v)) . bs . dq

  } else if (v = true) {
    return "true"

  } else if (v = false) {
    return "false"

  } else if (v = "") {
    return bs . dq . bs . dq

  } else {
    ; Fallback: quoted string από String(v)
    return bs . dq . JsonEscape(String(v)) . bs . dq
  }
}

/**
 * JsonEscape(s)
 * JSON-escape για απλό string:
 * \ -> \\ · `n -> \n · `r -> \r · " -> \"
 * Χρησιμοποιεί RegexLib.Str για συνεπή συμπεριφορά.
 */
JsonEscape(s) {
  try {
    return RegexLib.Str.JsonEscape(s)
  } catch Error as _e {
    ; Σε σπάνια αποτυχία, επιστρέφουμε ασφαλές κενό string.
    return ""
  }
}
; ==================== End Of File ====================
