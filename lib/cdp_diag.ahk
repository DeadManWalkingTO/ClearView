; ==================== lib/cdp_diag.ahk ====================
#Requires AutoHotkey v2.0
#Include "settings.ahk"
#Include "regex.ahk"

; Διαγνωστικό probe για την προσβασιμότητα του DevTools endpoint (/json).
; Χρήση:
;   CDP_DiagProbe(Settings.CDP_PORT, logger)
; όπου logger είναι instance με μεθόδους Write(text) και SafeErrorLog(prefix, e).
CDP_DiagProbe(port, logger, maxWaitMs := 8000, stepMs := 300) {
  local tStart, elapsed, ok, targetsCount, url, msg, txt

  ; Σύνθεση URL με helpers (αποφεύγουμε ωμά quotes/escapes)
  url := "http://127.0.0.1:" port "/json"

  ; Εκκίνηση probe
  try {
    msg := "🔍 Probe: Έλεγχος διαθεσιμότητας /json στο port " port
    logger.Write(msg)
  } catch Error as e {
    ; αν δεν υπάρχει logger ή έσκασε, συνεχίζουμε σιωπηλά
  }

  tStart := A_TickCount
  elapsed := 0
  ok := false
  targetsCount := 0

  ; Επανάληψη μέχρι να γίνει reachable ή να παρέλθει το timeout
  while (elapsed < maxWaitMs) {
    try {
      http := ComObject("WinHttp.WinHttpRequest.5.1")
      http.Open("GET", url, false)
      http.Send()
      if (http.Status = 200) {
        txt := http.ResponseText
        targetsCount := CDP_Diag_ParseTargetsCount(txt)
        if (targetsCount > 0) {
          ok := true
          break
        }
      }
    } catch Error as e {
      ; WinHttp μπορεί να ρίξει 0x80072EFD όταν το endpoint δεν έχει σηκωθεί ακόμη
      ; Δεν κάνουμε log σε κάθε βήμα για να μην «πνίξουμε» το log.
    }
    Sleep(stepMs)
    elapsed := A_TickCount - tStart
  }

  ; Αποτέλεσμα
  try {
    if (ok) {
      logger.Write("✅ Probe: /json διαθέσιμο — targets=" targetsCount)
    } else {
      logger.Write("❌ Probe: /json δεν απάντησε (timeout)")
    }
  } catch Error as e {
    ; σιωπηλή αστοχία logging
  }
}

; ---------------- Internal helpers ----------------

; Γρήγορο parser που απλώς μετρά πόσα ελάχιστα JSON αντικείμενα (\{[\s\S]*?\}) υπάρχουν.
; Δεν κάνει πλήρες JSON parse — είναι best-effort για διαγνωστικούς σκοπούς.
CDP_Diag_ParseTargetsCount(txt) {
  local c, pos, m, count
  c := RegexLib.Chars
  pos := 1
  count := 0
  try {
    ; Pattern από RegexLib: \{[\s\S]*?\}
    pat := RegexLib.Pat_JsonObjectMinimal()
    while RegExMatch(txt, pat, &m, pos) {
      count += 1
      pos := m.Pos(0) + m.Len(0)
    }
  } catch Error as e {
    ; αν σκάσει το regex, επιστρέφουμε 0
    count := 0
  }
  return count
}
; ==================== End Of File ====================
