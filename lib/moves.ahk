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
; Συνάρτηση
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
    halfH := Floor(SQUARE_HEIGHT / 2)

    Loop 4 {
      dx := Random(-halfW, halfW)
      dy := Random(-halfH, halfH)

      targetX := pointX + dx
      targetY := pointY + dy

      MouseMove(targetX, targetY, 0)  ; speed 0 = instant

      delayMs := Random(DELAY_MIN_MS, DELAY_MAX_MS)
      Sleep(delayMs)
    }
  } catch as err {
    ; Απλή αναφορά σφάλματος (μπορείς να το προσαρμόσεις)
    MsgBox("Σφάλμα στη MoveMouseRandom4(): " err.Message)
  }
}

; ==================== End Of File ====================
