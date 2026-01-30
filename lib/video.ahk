; ==================== lib/video.ahk ====================
#Requires AutoHotkey v2.0
#Include "moves.ahk"
#Include "settings.ahk"

class VideoService {

  ; ----------------------------------------------------
  ; Βοηθητικά
  ; ----------------------------------------------------
  StepDelay(ms) {
    try {
      d := ms + 0
    } catch {
      d := 120
    }
    if (d <= 0) {
      d := 120
    }
    Sleep(d)
  }

  _IsWhite(col) {
    ; Κατώφλι "λευκού" για τις κάθετες μπάρες Pause.
    thr := 0xE8E8E8
    try {
      thr := Settings.VIDEO_WHITE_THRESHOLD + 0
    } catch {
      thr := 0xE8E8E8
    }

    if (col >= thr) {
      return true
    }

    return false
  }

  _SamplePixel(hWnd, xf, yf) {
    try {
      WinGetPos(, , &W, &H, "ahk_id " hWnd)
    } catch {
      return ""
    }

    x := 0
    y := 0
    try {
      x := Floor(W * xf)
    } catch {
      x := 0
    }
    try {
      y := Floor(H * yf)
    } catch {
      y := 0
    }

    col := ""
    try {
      ; "Window" mode (BGR). Το 0xFFFFFF παραμένει λευκό.
      col := PixelGetColor(x, y, "Window")
    } catch {
      col := ""
    }

    return col
  }

  ; ----------------------------------------------------
  ; Εμφάνιση control bar με ανθρώπινες κινήσεις
  ; ----------------------------------------------------
  ShowControls(hWnd) {
    try {
      WinActivate("ahk_id " hWnd)
      WinWaitActive("ahk_id " hWnd, , 2)
    } catch {
    }

    try {
      WinGetPos(, , &W, &H, "ahk_id " hWnd)
    } catch {
      return
    }

    ; 1) Κέντρο
    cx := Floor(W * 0.50)
    cy := Floor(H * 0.50)
    try {
      MoveMouseRandom4(cx, cy)
    } catch {
    }
    this.StepDelay(120)

    ; 2) Κάτω ζώνη του player (για να εμφανιστεί η μπάρα)
    try {
      MoveMouseRandom4(cx, Floor(H * 0.90))
    } catch {
    }
    this.StepDelay(120)
  }

  ; ----------------------------------------------------
  ; Έλεγχος: Παίζει;
  ; ----------------------------------------------------
  IsPlaying(hWnd) {
    ; Εξαναγκάζουμε εμφάνιση controls για σταθερό sampling.
    this.ShowControls(hWnd)

    ; Δείγμα στο σημείο της αριστερής μπάρας του Pause (αν παίζει).
    ; Σταθερά, κάτω-αριστερά της control bar.
    col := this._SamplePixel(hWnd, 0.090, 0.885)
    if (col = "") {
      return false
    }

    if (this._IsWhite(col)) {
      return true
    }

    return false
  }

  ; ----------------------------------------------------
  ; Αν δεν παίζει → click στο κέντρο, log για επιτυχία/αποτυχία, ξανά έλεγχος.
  ; ----------------------------------------------------
  EnsurePlaying(hWnd, logger := 0) {
    ; 1) Αν ήδη παίζει, τέλος.
    if (this.IsPlaying(hWnd)) {
      return true
    }

    ; 2) Click στο κέντρο.
    try {
      WinGetPos(, , &W, &H, "ahk_id " hWnd)
    } catch {
      return false
    }

    cx := Floor(W * 0.50)
    cy := Floor(H * 0.50)

    ; Ανθρώπινο jitter πριν το click
    try {
      MoveMouseRandom4(cx, cy)
    } catch {
    }
    this.StepDelay(80)

    ; Click στο κέντρο
    try {
      Click(cx, cy)
    } catch {
    }

    ; 3) Μικρή αναμονή και ξανά έλεγχος
    this.StepDelay(350)

    nowPlays := this.IsPlaying(hWnd)

    ; 4) Μήνυμα για τη στιγμή που γίνεται play μέσα από αυτό το branch
    if (nowPlays) {
      if (logger) {
        try {
          logger.Write("▶️ Έναρξη αναπαραγωγής με click στο κέντρο.")
        } catch {
        }
      }
      return true
    }

    ; 5) Μήνυμα αποτυχίας εκκίνησης από το click στο κέντρο
    if (logger) {
      try {
        logger.Write("⛔ Αποτυχία εκκίνησης με click στο κέντρο.")
      } catch {
      }
    }

    return false
  }
}
; ==================== End Of File ====================
