; ==================== lib/video.ahk ====================
#Requires AutoHotkey v2.0
#Include "moves.ahk"
#Include "settings.ahk"

class VideoService
{
  ; -----------------------------------------------------
  ; Βοηθητικά
  ; -----------------------------------------------------
  StepDelay(ms) {
    local d := 0
    try {
      d := ms + 0
    } catch Error as e {
      d := 120
    }
    if (d <= 0) {
      d := 120
    }
    Sleep(d)
  }

  _DebugLog(logger, msg) {
    local dbg := false
    try {
      dbg := Settings.VIDEO_DEBUG
    } catch Error as e {
      dbg := false
    }
    if (dbg) {
      if (logger) {
        try {
          logger.Write("🐞 " msg)
        } catch Error as e {
        }
      }
    }
  }

  _ClampInt(v, minV, maxV) {
    local x := 0
    try {
      x := v + 0
    } catch Error as e {
      x := v
    }
    if (x < minV) {
      x := minV
    }
    if (x > maxV) {
      x := maxV
    }
    return x
  }

  _GetClientMetrics(hWnd, &cX, &cY, &cW, &cH) {
    cX := 0
    cY := 0
    cW := 0
    cH := 0
    try {
      WinGetClientPos(&cX, &cY, &cW, &cH, "ahk_id " hWnd)
    } catch Error as e {
      cX := 0
      cY := 0
      cW := 0
      cH := 0
    }
  }

  _PointInGui(sx, sy, gx, gy, gw, gh) {
    if (gw > 0) {
      if (gh > 0) {
        if (sx >= gx) {
          if (sx < (gx + gw)) {
            if (sy >= gy) {
              if (sy < (gy + gh)) {
                return true
              }
            }
          }
        }
      }
    }
    return false
  }

  ; -----------------------------------------------------
  ; ΝΕΟ IsPlaying(): 300 δείγματα, ασφαλής περιοχή,
  ; αποκλεισμός GUI, early-exit 5 γύρων
  ; -----------------------------------------------------
  IsPlaying(hWnd, logger := 0, guiX := 0, guiY := 0, guiW := 0, guiH := 0) {

    ; Client metrics
    local cX := 0
    local cY := 0
    local cW := 0
    local cH := 0
    try {
      this._GetClientMetrics(hWnd, &cX, &cY, &cW, &cH)
    } catch Error as e {
      if (logger) {
        try logger.Write("⚠️ GetClientMetrics: " e.Message)
      }
      return false
    }
    if (cW <= 0) {
      return false
    }

    ; Περιθώρια ποσοστού (ασφαλή + YouTube δεξιά)
    local marginTop := 0.14
    local marginBottom := 0.14
    local marginLeft := 0.08
    local marginRight := 0.34

    if (marginTop < 0.00) {
      marginTop := 0.00
    }
    if (marginBottom < 0.00) {
      marginBottom := 0.00
    }
    if (marginLeft < 0.00) {
      marginLeft := 0.00
    }
    if (marginRight < 0.00) {
      marginRight := 0.00
    }
    if ((marginTop + marginBottom) >= 0.90) {
      marginTop := 0.05
      marginBottom := 0.05
    }
    if ((marginLeft + marginRight) >= 0.90) {
      marginLeft := 0.05
      marginRight := 0.05
    }

    ; Περιοχή sampling (σε client pixels)
    local safeX1 := Floor(cW * marginLeft)
    local safeX2 := Floor(cW * (1 - marginRight))
    local safeY1 := Floor(cH * marginTop)
    local safeY2 := Floor(cH * (1 - marginBottom))

    if (safeX2 <= safeX1) {
      safeX1 := 0
      safeX2 := cW - 1
    }
    if (safeY2 <= safeY1) {
      safeY1 := 0
      safeY2 := cH - 1
    }

    ; 300 ασφαλή σημεία (με αποκλεισμό GUI)
    local pts := []
    local targetCount := 300
    local maxTotalTries := targetCount * 6
    local tries := 0

    while (pts.Length < targetCount) {
      if (tries >= maxTotalTries) {
        break
      }
      tries := tries + 1

      local px := 0
      local py := 0
      try {
        px := Random(safeX1, safeX2)
      } catch Error {
        px := safeX1
      }
      try {
        py := Random(safeY1, safeY2)
      } catch Error {
        py := safeY1
      }

      local sx := cX + px
      local sy := cY + py

      local inGui := false
      try {
        inGui := this._PointInGui(sx, sy, guiX, guiY, guiW, guiH)
      } catch Error {
        inGui := false
      }

      if (inGui) {
        continue
      }

      pts.Push([px, py])
    }

    ; Συμπλήρωση σε ακραία περίπτωση
    while (pts.Length < targetCount) {
      local px2 := 0
      local py2 := 0
      try px2 := Random(0, cW - 1)
      try py2 := Random(0, cH - 1)
      pts.Push([px2, py2])
    }

    ; Πίνακες 5 γύρων
    local A := []
    local t := 1
    while (t <= 5) {
      local arr := []
      A.Push(arr)
      t := t + 1
    }


    ; 🔸 ΝΕΟ: ΠΡΙΝ από το πρώτο sampling (round=1)
    ; Κάνε MoveMouseRandom4 στο κέντρο του client και μετά περίμενε MID_DELAY_MS.
    try {
      local midCX := 0, midCY := 0
      midCX := cX + Floor(cW * 0.50)
      midCY := cY + Floor(cH * 0.50)
      MoveMouseRandom4(midCX, midCY)
    } catch Error as _eMM {
      ; no-op
    }
    try {
      local mid := 0
      mid := Settings.MID_DELAY_MS + 0
      Sleep(mid)
    } catch Error as _eMid {
      ; no-op
    }


    ; Sampling 5 γύρων με early exit
    t := 1
    while (t <= 5) {

      ; SAMPLE PHASE
      local idx := 1
      while (idx <= pts.Length) {

        local pxs := 0
        local pys := 0
        try pxs := pts[idx][1]
        try pys := pts[idx][2]

        local col := ""
        try {
          col := PixelGetColor(pxs, pys, "Window")
        } catch Error {
          col := ""
        }

        A[t].Push(col)
        idx := idx + 1
      }

      this._DebugLog(logger, "MotionSample round=" t)

      ; ANALYSIS PHASE
      if (t >= 2) {
        local changedCount := 0
        idx := 1

        while (idx <= pts.Length) {
          local v1 := ""
          local v2 := ""

          try v1 := A[t - 1][idx]
          try v2 := A[t][idx]

          if (v1 != "") {
            if (v2 != "") {
              local diff := 0
              try diff := Abs(v1 - v2)

              if (diff > 0x030303) {
                changedCount := changedCount + 1
              }
            }
          }
          idx := idx + 1
        }

        this._DebugLog(logger, "MotionDelta t=" t " changed=" changedCount)

        if (changedCount >= 8) {
          return true
        }
      }

      if (t < 5) {
        Sleep(1000)
      }

      t := t + 1
    }

    return false
  }

  ; -----------------------------------------------------
  ; EnsurePlaying με GUI-aware IsPlaying
  ; -----------------------------------------------------
  EnsurePlaying(hWnd, logger := 0, guiX := 0, guiY := 0, guiW := 0, guiH := 0) {

    local plays := false
    try {
      plays := this.IsPlaying(hWnd, logger, guiX, guiY, guiW, guiH)
    } catch Error as e {
      plays := false
      if (logger) {
        try logger.Write("⚠️ IsPlaying error: " e.Message)
      }
    }

    if (plays) {
      return true
    }

    ; fallback click center
    local cX, cY, cW, cH
    try {
      this._GetClientMetrics(hWnd, &cX, &cY, &cW, &cH)
    } catch Error as e2 {
      if (logger) {
        try logger.Write("⚠️ GetClientMetrics error: " e2.Message)
      }
      return false
    }

    if (cW <= 0) {
      return false
    }

    local cx := 0
    local cy := 0
    try {
      cx := cX + Floor(cW * 0.50)
      cy := cY + Floor(cH * 0.50)
    } catch Error {
      cx := cX
      cy := cY
    }

    try MoveMouseRandom4(cx, cy)
    this.StepDelay(80)

    try Click(cx, cy)

    local mid := 0
    try mid := Settings.MID_DELAY_MS + 0
    this.StepDelay(mid)

    try {
      plays := this.IsPlaying(hWnd, logger, guiX, guiY, guiW, guiH)
    } catch Error {
      plays := false
    }

    if (plays) {
      if (logger) {
        try logger.Write("▶️ Έναρξη αναπαραγωγής με click στο κέντρο.")
      }
      return true
    }

    if (logger) {
      try logger.Write("⛔ Αποτυχία εκκίνησης με click στο κέντρο.")
    }
    return false
  }
}
; ==================== End Of File ====================
