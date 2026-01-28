; ==================== lib/cdp_http.ahk ====================
#Requires AutoHotkey v2.0
#Include "regex.ahk"

; -----------------------------------------------------------------------------
; DevTools HTTP helpers (polling /json & parsing targets)
; -----------------------------------------------------------------------------
; Στόχος: Απομονωμένη και «ελαφριά» υλοποίηση για τον HTTP έλεγχο διαθεσιμότητας
; του DevTools endpoint (http://127.0.0.1:PORT/json) και το parsing των targets.
; Χρησιμοποιεί RegexLib για ασφαλή σύνθεση patterns/strings.
;
; Κανόνες που τηρούνται:
; - AHK v2: Πλήρη try/catch blocks, χωρίς μονογραμμικά.
; - Χωρίς τελεστές && / || (διαδοχικά if).
; - Χωρίς ωμούς ειδικούς χαρακτήρες όπου γίνεται: αξιοποίηση RegexLib.Chars/Str.
; -----------------------------------------------------------------------------

/**
 * DevTools_GetTargets
 * Κάνει polling στο http://127.0.0.1:PORT/json έως maxWaitMs (βήμα stepMs) και
 * επιστρέφει πίνακα με τα targets (κάθε target = Map με keys: id, title, url, type, webSocketDebuggerUrl).
 * 
 * @param {Integer} port       π.χ. 9222
 * @param {Integer} maxWaitMs  συνολικό timeout σε ms (default: 6000)
 * @param {Integer} stepMs     διάστημα μεταξύ προσπαθειών (default: 250)
 * @return {Array} targets     [] αν timeout/αποτυχία
 */
DevTools_GetTargets(port, maxWaitMs := 6000, stepMs := 250) {
  local tStart, elapsed, url, http, txt, targets, c
  c := RegexLib.Chars
  ; Σύνθεση URL χωρίς ωμά escaping
  url := "http://127.0.0.1:" port c.SLASH "json"

  tStart := A_TickCount
  elapsed := 0
  targets := []

  while (elapsed < maxWaitMs) {
    try {
      http := ComObject("WinHttp.WinHttpRequest.5.1")
      http.Open("GET", url, false)
      http.Send()
      if (http.Status = 200) {
        txt := http.ResponseText
        targets := DevTools_ParseTargets(txt)
        if (targets.Length > 0) {
          return targets
        }
      }
    } catch Error as e {
      ; WinHttp μπορεί να ρίξει 0x80072EFD ή άλλα σφάλματα μέχρι να «ζωντανέψει» το endpoint
      ; Συνεχίζουμε τα retries σιωπηρά.
    }
    Sleep(stepMs)
    elapsed := A_TickCount - tStart
  }
  return targets
}

/**
 * DevTools_ParseTargets
 * Best-effort parser: εντοπίζει ελάχιστα JSON αντικείμενα με RegexLib.Pat_JsonObjectMinimal()
 * και εξάγει βασικά πεδία μέσω RegexLib.Pat_JsonKeyQuotedString(key).
 * 
 * @param {String} txt   το κείμενο της απόκρισης /json
 * @return {Array}       targets (κάθε στοιχείο Map)
 */
DevTools_ParseTargets(txt) {
  local out, pos, m, objTxt, o, key, v, patObj
  out := []
  if (txt = "") {
    return out
  }

  pos := 1
  patObj := RegexLib.Pat_JsonObjectMinimal()

  try {
    while RegExMatch(txt, patObj, &m, pos) {
      objTxt := m[0]
      pos := m.Pos(0) + m.Len(0)

      o := Map()
      ; Τα κλασικά πεδία του DevTools: "id", "title", "url", "type", "webSocketDebuggerUrl"
      for key in ["id", "title", "url", "type", "webSocketDebuggerUrl"] {
        v := DevTools_JsonExtractString(objTxt, key)
        if (v != "") {
          o[key] := v
        }
      }
      if (o.Count) {
        out.Push(o)
      }
    }
  } catch Error as e {
    ; Σε αποτυχία regex parsing επιστρέφουμε ό,τι έχουμε (πιθανόν κενό).
  }
  return out
}

/**
 * DevTools_JsonExtractString
 * Επιστρέφει την τιμή string ενός συγκεκριμένου key από JSON-σαν κείμενο (best-effort).
 * Χρησιμοποιεί RegexLib.Pat_JsonKeyQuotedString(key) με captured group το value.
 * 
 * @param {String} src   JSON-σαν τμήμα κειμένου
 * @param {String} key   κλειδί π.χ. "id", "webSocketDebuggerUrl"
 * @return {String}      τιμή ή "" αν δεν βρεθεί
 */
DevTools_JsonExtractString(src, key) {
  local pat, mm
  if (src = "") {
    return ""
  }
  try {
    pat := RegexLib.Pat_JsonKeyQuotedString(key)
    if RegExMatch(src, pat, &mm) {
      return mm[1]
    }
  } catch Error as e {
    ; σιωπηρά
  }
  return ""
}
; ==================== End Of File ====================
