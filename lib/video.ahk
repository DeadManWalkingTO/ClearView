; ==================== lib/video.ahk ====================
#Requires AutoHotkey v2.0
#Include "moves.ahk"
#Include "settings.ahk"

class VideoService
{
  ; ----------------------------------------------------
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

  ; ----------------------------------------------------
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

  ; ----------------------------------------------------
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

  ; ----------------------------------------------------
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

  ; ----------------------------------------------------
  _SampleClientPixel(hWnd, xf, yf, &colBgr) {
    colBgr := ""

    local cX, cY, cW, cH
    this._GetClientMetrics(hWnd, &cX, &cY, &cW, &cH)

    if (cW <= 0) {
      return false
    }

    local px := 0
    local py := 0

    try {
      px := Floor(cW * xf)
    } catch Error as e {
      px := 0
    }

    try {
      py := Floor(cH * yf)
    } catch Error as e {
      py := 0
    }

    try {
      px := this._ClampInt(px, 0, cW - 1)
    } catch Error as e {
      px := 0
    }

    try {
      py := this._ClampInt(py, 0, cH - 1)
    } catch Error as e {
      py := 0
    }

    try {
      colBgr := PixelGetColor(px, py, "Window")
    } catch Error as e {
      colBgr := ""
    }

    if (colBgr = "") {
      return false
    }

    return true
  }

  ; ----------------------------------------------------
  ; NEW IsPlaying() — SAFE Motion‑50 + EARLY EXIT + Full Logging
  ; ----------------------------------------------------
  IsPlaying(hWnd, logger := 0) {

    ; -------- Client metrics --------
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

    ; -------- Build 50 safe random sample points --------
    local pts := []
    local i := 1

    while (i <= 50) {
      local p := []
      try {
        local xf := Random(0.12, 0.88)
        local yf := Random(0.12, 0.88)
        p.Push(xf)
        p.Push(yf)
      } catch Error as e {
        p.Push(0.50)
        p.Push(0.50)
        if (logger) {
          try logger.Write("⚠️ Random point error: " e.Message)
        }
      }
      pts.Push(p)
      i := i + 1
    }

    ; -------- Prepare A[t] --------
    local A := []
    local t := 1
    while (t <= 5) {
      local arr := []
      A.Push(arr)
      t := t + 1
    }

    ; -------- 5 rounds with EARLY EXIT --------
    t := 1
    while (t <= 5) {

      ; === SAMPLE PHASE ===
      local idx := 1
      while (idx <= pts.Length) {

        local xf := 0.50
        local yf := 0.50

        try {
          xf := pts[idx][1]
          yf := pts[idx][2]
        } catch Error as e {
          xf := 0.50
          yf := 0.50
          if (logger) {
            try logger.Write("⚠️ pts index error: " e.Message)

          }
        }

        local col := ""
        try {
          if (this._SampleClientPixel(hWnd, xf, yf, &col)) {
            A[t].Push(col)
          } else {
            A[t].Push("")
          }
        } catch Error as e {
          A[t].Push("")
          if (logger) {
            try logger.Write("⚠️ SamplePixel error: " e.Message)

          }
        }

        idx := idx + 1
      }

      if (logger) {
        try logger.Write("🐞 MotionSample round=" t)

      }

      ; === ANALYSIS PHASE (EARLY EXIT) ===
      if (t >= 2) {

        local changedCount := 0
        idx := 1

        while (idx <= 50) {

          local v1 := ""
          local v2 := ""

          try v1 := A[t - 1][idx]
          catch Error as e {
            v1 := ""
          }

          try v2 := A[t][idx]
          catch Error as e {
            v2 := ""
          }

          if (v1 != "") {
            if (v2 != "") {
              local diff := 0
              try diff := Abs(v1 - v2)
              catch Error as e {
                diff := 0
              }

              if (diff > 0x030303) {
                changedCount := changedCount + 1
              }
            }
          }

          idx := idx + 1
        }

        if (logger) {
          try logger.Write("🐞 MotionDelta t=" t " changed=" changedCount)

        }

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

  ; ----------------------------------------------------
  EnsurePlaying(hWnd, logger := 0) {

    local plays := false

    try {
      plays := this.IsPlaying(hWnd, logger)
    } catch Error as e {
      plays := false
      if (logger) {
        try logger.Write("⚠️ IsPlaying error: " e.Message)

      }
    }

    if (plays) {
      return true
    }

    ; -------- fallback click center --------
    local cX, cY, cW, cH

    try {
      this._GetClientMetrics(hWnd, &cX, &cY, &cW, &cH)
    } catch Error as e {
      if (logger) {
        try logger.Write("⚠️ GetClientMetrics error: " e.Message)

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
    } catch Error as e {
      cx := cX
      cy := cY
    }

    try {
      MoveMouseRandom4(cx, cy)
    } catch Error as e {
      if (logger) {
        try logger.Write("⚠️ MoveMouseRandom4 error: " e.Message)

      }
    }

    this.StepDelay(80)

    try {
      Click(cx, cy)
    } catch Error as e {
      if (logger) {
        try logger.Write("⚠️ Click error: " e.Message)

      }
    }

    local mid := 3000
    try {
      mid := Settings.MID_DELAY_MS + 0
    } catch Error as e {
      mid := 3000
      if (logger) {
        try logger.Write("⚠️ MID_DELAY_MS error: " e.Message)

      }
    }

    this.StepDelay(mid)

    try {
      plays := this.IsPlaying(hWnd, logger)
    } catch Error as e {
      plays := false
      if (logger) {
        try logger.Write("⚠️ IsPlaying retry error: " e.Message)

      }
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
