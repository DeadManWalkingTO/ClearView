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
    ; Χρησιμοποιούμε κατώφλι λευκού από Settings (default ~0xE8E8E8).
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

  _SamplePixel(hWnd, xf, yf, logger := 0) {
    try {
      WinGetPos(, , &W, &H, "ahk_id " hWnd)
    } catch {
      if (logger) {
        try {
          logger.Write("⚠️ SamplePixel: WinGetPos απέτυχε.")
        } catch {
        }
      }
      return ""
    }

    x := 0
    y := 0
    try {
      x := Floor(W * xf)
      y := Floor(H * yf)
    } catch {
      x := 0
      y := 0
    }

    col := ""
    try {
      ; Προεπιλογή: "Window" (BGR). Το λευκό είναι 0xFFFFFF ανεξαρτήτως RGB/BGR.
      col := PixelGetColor(x, y, "Window")
    } catch {
      col := ""
    }

    if (col = "") {
      if (logger) {
        try {
          logger.Write("⚠️ SamplePixel: άγνωστο χρώμα.")
        } catch {
        }
      }
    }

    return col
  }

  ; ----------------------------------------------------
  ; Εμφάνιση control bar (χωρίς click)
  ; ----------------------------------------------------
  EnsurePlayerBarVisible(hWnd, logger := 0) {
    try {
      WinActivate("ahk_id " hWnd)
      WinWaitActive("ahk_id " hWnd, , 2)
    } catch {
    }

    try {
      WinGetPos(, , &W, &H, "ahk_id " hWnd)
    } catch {
      if (logger) {
        try {
          logger.Write("⚠️ EnsurePlayerBarVisible: WinGetPos απέτυχε.")
        } catch {
        }
      }
      return
    }

    ; Κινήσεις ποντικιού στο κέντρο και ελαφρά προς τα κάτω
    cx := Floor(W * 0.50)
    cy := Floor(H * 0.50)

    try {
      MoveMouseRandom4(cx, cy)
    } catch {
    }
    this.StepDelay(120)

    ; Μικρή κίνηση προς το κάτω μέρος του player για να αποκαλυφθεί η μπάρα
    try {
      MoveMouseRandom4(cx, Floor(H * 0.90))
    } catch {
    }
    this.StepDelay(120)
  }

  ; ----------------------------------------------------
  ; Ανίχνευση κατάστασης αναπαραγωγής μέσω pixels (αδιάβλητο v2)
  ; ----------------------------------------------------
  IsPlaying_ByPixel(hWnd, logger := 0) {
    ; Προαιρετικά βεβαιωνόμαστε ότι φαίνεται η μπάρα
    needBar := true
    try {
      needBar := Settings.VIDEO_ENSURE_BAR
    } catch {
      needBar := true
    }
    if (needBar) {
      this.EnsurePlayerBarVisible(hWnd, logger)
    }

    ; Δειγματοληψία σε τρία σημεία όπου αναμένεται να "πέφτει" η μπάρα του Pause (λευκό)
    ; A, B, C: κάτω-αριστερά μέρος control bar (Play/Pause region)
    colA := this._SamplePixel(hWnd, 0.082, 0.885, logger)
    colB := this._SamplePixel(hWnd, 0.097, 0.885, logger)
    colC := this._SamplePixel(hWnd, 0.112, 0.885, logger)

    if (colA != "") {
      if (this._IsWhite(colA)) {
        return true
      }
    }

    if (colB != "") {
      if (this._IsWhite(colB)) {
        return true
      }
    }

    if (colC != "") {
      if (this._IsWhite(colC)) {
        return true
      }
    }

    return false
  }

  ; ----------------------------------------------------
  ; Προσπάθεια εκκίνησης (click/k) + μικρά jitter
  ; ----------------------------------------------------
  ForcePlay(hWnd, logger := 0) {
    this.EnsurePlayerBarVisible(hWnd, logger)
    this.StepDelay(80)

    try {
      WinGetPos(, , &W, &H, "ahk_id " hWnd)
    } catch {
      if (logger) {
        try {
          logger.Write("⚠️ ForcePlay: WinGetPos απέτυχε.")
        } catch {
        }
      }
      return
    }

    ; Περιοχή Play/Pause (κάτω αριστερά)
    px := Floor(W * 0.09)
    py := Floor(H * 0.885)

    ; Μικρό ανθρώπινο jitter
    try {
      MoveMouseRandom4(px, py)
    } catch {
    }
    this.StepDelay(60)

    ; Σεβασμός ρύθμισης CLICK_TO_PLAY
    doClick := true
    try {
      doClick := Settings.CLICK_TO_PLAY
    } catch {
      doClick := true
    }
    if (doClick) {
      try {
        Click(px, py)
      } catch {
      }
      this.StepDelay(200)
      if (logger) {
        try {
          logger.Write("🖱️ ForcePlay: click στο Play/Pause.")
        } catch {
        }
      }
    }

    ; Προαιρετικά 'k' (play/pause)
    doSendK := false
    try {
      doSendK := Settings.SEND_K_KEY
    } catch {
      doSendK := false
    }
    if (doSendK) {
      try {
        Send("k")
      } catch {
      }
      this.StepDelay(180)
      if (logger) {
        try {
          logger.Write("⌨️ ForcePlay: αποστολή πλήκτρου 'k'.")
        } catch {
        }
      }
    }

    ; Αν ζητηθεί, δοκιμή και με click στο κέντρο
    tryCenter := true
    try {
      tryCenter := Settings.VIDEO_CLICK_CENTER_IF_NEEDED
    } catch {
      tryCenter := true
    }
    if (tryCenter) {
      ; Μόνο αν ακόμη δεν παίζει
      if (this.IsPlaying_ByPixel(hWnd, logger)) {
        ; ήδη παίζει
      } else {
        cx := Floor(W * 0.50)
        cy := Floor(H * 0.50)
        try {
          MoveMouseRandom4(cx, cy)
        } catch {
        }
        this.StepDelay(60)
        try {
          Click(cx, cy)
        } catch {
        }
        this.StepDelay(220)
        if (logger) {
          try {
            logger.Write("🖱️ ForcePlay: fallback click στο κέντρο.")
          } catch {
          }
        }
      }
    }
  }

  ; ----------------------------------------------------
  ; Αναμονή μέχρι να παίζει (με ενδιάμεσο retry)
  ; ----------------------------------------------------
  WaitUntilPlaying(hWnd, timeoutMs := 3000, logger := 0) {
    total := 0
    step := 150
    halfRetryDone := false

    try {
      d := Settings.VIDEO_WAIT_TIMEOUT_MS + 0
    } catch {
      d := timeoutMs
    }
    if (d <= 0) {
      d := timeoutMs
    }
    timeout := d

    loop {
      if (total >= timeout) {
        break
      }

      if (this.IsPlaying_ByPixel(hWnd, logger)) {
        if (logger) {
          try {
            logger.Write("🎵 Playback detected (pixel v2).")
          } catch {
          }
        }
        return true
      }

      ; Στο μέσο του timeout, κάνε ένα δυνατό retry
      if (total >= Floor(timeout / 2)) {
        if (halfRetryDone) {
          ; ήδη έγινε μία φορά
        } else {
          if (logger) {
            try {
              logger.Write("↻ Retry: ForcePlay στη μέση του timeout.")
            } catch {
            }
          }
          this.ForcePlay(hWnd, logger)
          halfRetryDone := true
        }
      }

      Sleep(step)
      total := total + step
    }

    if (logger) {
      try {
        logger.Write("⛔ Playback NOT detected (timeout).")
      } catch {
      }
    }
    return false
  }

  ; ----------------------------------------------------
  ; Προαιρετικό: Αναμονή για τίτλο YouTube (μεταφορά από edge.ahk)
  ; ----------------------------------------------------
  WaitForYouTubeTitle(hWnd, timeoutMs := 8000) {
    tries := Ceil(timeoutMs / 250.0)
    i := 0
    loop tries {
      i := i + 1
      t := ""
      try {
        t := WinGetTitle("ahk_id " hWnd)
      } catch {
        t := ""
      }
      if (InStr(t, "YouTube")) {
        return true
      }
      Sleep(250)
    }
    return false
  }
}
; ==================== End Of File ====================
