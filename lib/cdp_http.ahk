; ==================== lib/cdp_http.ahk ====================
#Requires AutoHotkey v2.0
#Include "regex.ahk"

; -----------------------------------------------------------------------------
; DevTools HTTP helpers (polling /json & parsing targets)
; -----------------------------------------------------------------------------
; Βελτιώσεις:
; - Progressive backoff στα retries (250 → 400 → 600 → 800 ms …).
; - Fallback client: αν αποτύχει WinHttpRequest, δοκιμάζουμε MSXML2.XMLHTTP.
; -----------------------------------------------------------------------------

/**
 * DevTools_GetTargets
 * Κάνει polling στο http://127.0.0.1:PORT/json έως maxWaitMs και επιστρέφει targets.
 *
 * @param {Integer} port       π.χ. 9222
 * @param {Integer} maxWaitMs  συνολικό timeout σε ms (default: 12000 για σταθερότητα)
 * @param {Integer} stepMs     αρχικό διάστημα μεταξύ προσπαθειών (default: 250)
 * @return {Array} targets     [] αν timeout/αποτυχία
 */
DevTools_GetTargets(port, maxWaitMs := 12000, stepMs := 250) {
  local tStart, elapsed, url, txt, targets, c
  c := RegexLib.Chars
  url := "http://127.0.0.1:" port c.SLASH "json"

  tStart := A_TickCount
  elapsed := 0
  targets := []
  curStep := stepMs

  while (elapsed < maxWaitMs) {
    ; 1) Προσπάθεια με WinHttpRequest
    txt := DevTools_TryGetJson_WinHttp(url)
    if (txt != "") {
      targets := DevTools_ParseTargets(txt)
      if (targets.Length > 0) {
        return targets
      }
    }

    ; 2) Fallback με MSXML2.XMLHTTP (μερικά AV/Policies μπλοκάρουν WinHTTP)
    txt := DevTools_TryGetJson_MSXML(url)
    if (txt != "") {
      targets := DevTools_ParseTargets(txt)
      if (targets.Length > 0) {
        return targets
      }
    }

    ; Backoff: αυξάνουμε σταδιακά το διάστημα αναμονής
    Sleep(curStep)
    if (curStep < 800) {
      curStep := curStep + 150   ; 250→400→550→700→850 (κόφτης παρακάτω)
    }
    if (curStep > 850) {
      curStep := 850
    }
    elapsed := A_TickCount - tStart
  }
  return targets
}

DevTools_TryGetJson_WinHttp(url) {
  local txt
  txt := ""
  try {
    http := ComObject("WinHttp.WinHttpRequest.5.1")
    http.Open("GET", url, false)
    http.Send()
    if (http.Status = 200) {
      txt := http.ResponseText
    }
  } catch Error as _eWinHttp {
    ; σιωπηλά
  }
  return txt
}

DevTools_TryGetJson_MSXML(url) {
  local txt
  txt := ""
  try {
    xhr := ComObject("MSXML2.XMLHTTP")
    xhr.open("GET", url, false)
    xhr.send()
    ; Σημείωση: Σε μερικές εκδόσεις, το readyState=4 + status=200
    if (xhr.status = 200) {
      txt := xhr.responseText
    }
  } catch Error as _eXhr {
    ; σιωπηλά
  }
  return txt
}

/**
 * DevTools_ParseTargets
 * Best-effort parser: εντοπίζει ελάχιστα JSON αντικείμενα και εξάγει βασικά πεδία.
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
  } catch Error as _eParse {
    ; σιωπηλά
  }
  return out
}

/**
 * DevTools_JsonExtractString
 * Επιστρέφει την τιμή string ενός συγκεκριμένου key (best-effort).
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
  } catch Error as _eKey {
    ; σιωπηλά
  }
  return ""
}
; ==================== End Of File ====================