#Requires AutoHotkey v2.0
; ==================== lib/moves.ahk ====================

; =========================
; Παραμετροποίηση
; =========================
; Διαστάσεις τετραγώνου (20x20 default)
SQUARE_WIDTH := 20
SQUARE_HEIGHT := 20

; Καθυστέρηση ανά κίνηση (50–150 ms default)
DELAY_MIN_MS := 50
DELAY_MAX_MS := 150

; =========================
; Συναρτήσεις
; =========================

; MoveMouseRandom4(pointX, pointY)
; Δέχεται ένα σημείο (pointX, pointY) στην οθόνη και κινεί το ποντίκι 4 φορές
; σε τυχαίες θέσεις μέσα σε τετράγωνο SQUARE_WIDTH x SQUARE_HEIGHT, με τυχαία
; καθυστέρηση DELAY_MIN_MS..DELAY_MAX_MS ms ανάμεσα.
;
; Σημείωση: Το τετράγωνο θεωρείται κεντραρισμένο στο (pointX, pointY).
;
MoveMouseRandom4(pointX, pointY) {
  try {
    halfW := Floor(SQUARE_WIDTH / 2)
  } catch {
    halfW := 10
  }
  try {
    halfH := Floor(SQUARE_HEIGHT / 2)
  } catch {
    halfH := 10
  }

  Loop 4 {
    dx := 0
    dy := 0
    try {
      dx := Random(-halfW, halfW)
    } catch {
      dx := 0
    }
    try {
      dy := Random(-halfH, halfH)
    } catch {
      dy := 0
    }

    targetX := pointX + dx
    targetY := pointY + dy

    try {
      MouseMove(targetX, targetY, 0) ; speed 0 = instant
    } catch {
    }

    delayMs := 0
    try {
      delayMs := Random(DELAY_MIN_MS, DELAY_MAX_MS)
    } catch {
      delayMs := 80
    }
    Sleep(delayMs)
  }
}

; ClickCenter(hWnd, logger := 0, preMoveSleepMs := 0, preClickSleepMs := 80)
; Κάνει κλικ στο ΚΕΝΤΡΟ του client area του παραθύρου hWnd.
; - Υπολογίζει client rect με WinGetClientPos,
; - κεντράρει (cx, cy),
; - κάνει μία μικρή «ανθρώπινη» κίνηση (MoveMouseRandom4) και Click,
; - προαιρετικό logging (αν περαστεί logger).
; Επιστρέφει true σε επιτυχία (έγκυρο client πλάτος), αλλιώς false.
ClickCenter(hWnd, logger := 0, preMoveSleepMs := 0, preClickSleepMs := 80) {
  cX := 0
  cY := 0
  cW := 0
  cH := 0

  ; Ανάγνωση client περιοχής
  try {
    WinGetClientPos(&cX, &cY, &cW, &cH, "ahk_id " hWnd)
  } catch {
    cW := 0
    cH := 0
  }

  if (cW > 0) {
    cx := 0
    cy := 0
    try {
      cx := cX + Floor(cW * 0.50)
    } catch {
      cx := cX
    }
    try {
      cy := cY + Floor(cH * 0.50)
    } catch {
      cy := cY
    }

    ; Προαιρετική μικρή αναμονή πριν την κίνηση
    if (preMoveSleepMs > 0) {
      Sleep(preMoveSleepMs)
    }

    ; Ελαφρά «ανθρώπινη» κίνηση & Click
    try {
      MoveMouseRandom4(cx, cy)
    } catch {
    }

    if (preClickSleepMs > 0) {
      Sleep(preClickSleepMs)
    }

    try {
      Click(cx, cy)
    } catch {
    }

    ; Logging επιτυχίας (προαιρετικό)
    try {
      if (logger) {
        logger.Write("🖱️ ClickCenter: MoveMouseRandom4 + Click στο κέντρο του client.")
      }
    } catch {
    }
    return true
  }

  ; Αποτυχία: άγνωστο client μέγεθος
  try {
    if (logger) {
      logger.Write("⚠️ ClickCenter: άγνωστο client μέγεθος (WinGetClientPos δεν έδωσε w>0).")
    }
  } catch {
  }
  return false
}

; ==================== End Of File ====================
