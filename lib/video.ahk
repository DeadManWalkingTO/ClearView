; ==================== lib/video.ahk ====================
#Requires AutoHotkey v2.0
#Include "..\core\system\utils.ahk"
#Include "..\core\automation\mouse.ahk"
#Include "..\lib\settings.ahk"


class VideoService {
  ; -------------------- Βοηθητικά --------------------
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
          ; Write → Both → ενημέρωση και head με το ίδιο κείμενο
          logger.Write("🐞 " msg)
        } catch Error as e2 {
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

  ; -------------------- IsPlaying --------------------
  ; ΝΕΟ IsPlaying(): 300 δείγματα, ασφαλής περιοχή, αποκλεισμός GUI, early-exit 5 γύρων
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
        try {
          logger.Write("⚠️ GetClientMetrics: " e.Message)
        } catch {
        }
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
      } catch {
        px := safeX1
      }
      try {
        py := Random(safeY1, safeY2)
      } catch {
        py := safeY1
      }

      local sx := cX + px
      local sy := cY + py

      local inGui := false
      try {
        inGui := Utils.IsPointInRect(sx, sy, guiX, guiY, guiW, guiH)
      } catch {
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
      try {
        px2 := Random(0, cW - 1)
      } catch {
        px2 := 0
      }
      try {
        py2 := Random(0, cH - 1)
      } catch {
        py2 := 0
      }
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

    ; 🔶 ΠΡΙΝ από το πρώτο sampling (round=1): κίνηση ποντικιού στο κέντρο και αναμονή MID_DELAY_MS
    try {
      local midCX := 0, midCY := 0
      midCX := cX + Floor(cW * 0.50)
      midCY := cY + Floor(cH * 0.50)
      MoveMouseRandom4(midCX, midCY)
    } catch {
    }
    try {
      local mid := 0
      mid := Settings.MID_DELAY_MS + 0
      Sleep(mid)
    } catch {
    }

    ; Sampling 5 γύρων με early exit
    t := 1
    while (t <= 5) {
      ; SAMPLE PHASE
      local idx := 1
      while (idx <= pts.Length) {
        local pxs := 0
        local pys := 0
        try {
          pxs := pts[idx][1]
        } catch {
          pxs := 0
        }
        try {
          pys := pts[idx][2]
        } catch {
          pys := 0
        }
        local col := ""
        try {
          col := PixelGetColor(pxs, pys, "Window")
        } catch {
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
          try {
            v1 := A[t - 1][idx]
          } catch {
            v1 := ""
          }
          try {
            v2 := A[t][idx]
          } catch {
            v2 := ""
          }
          if (v1 != "") {
            if (v2 != "") {
              local diff := 0
              try {
                diff := Abs(v1 - v2)
              } catch {
                diff := 0
              }
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

  ; -------------------- EnsurePlaying --------------------
  ; GUI-aware IsPlaying + fallback click στο κέντρο με ClickCenter()
  EnsurePlaying(hWnd, logger := 0, guiX := 0, guiY := 0, guiW := 0, guiH := 0) {
    local plays := false
    try {
      plays := this.IsPlaying(hWnd, logger, guiX, guiY, guiW, guiH)
    } catch Error as e {
      plays := false
      if (logger) {
        try {
          logger.Write("⚠️ IsPlaying error: " e.Message)
        } catch {
        }
      }
    }
    if (plays) {
      ; ΜΟΝΟ αν ΔΕΝ έχει προηγηθεί click στο τρέχον βίντεο,
      ; θεωρούμε ότι πρόκειται για autoplay -> PRE_CLICK_ENABLED := false
      try {
        if (!Settings.CLICK_OCCURRED_THIS_VIDEO) {
          Settings.PRE_CLICK_ENABLED := false
        }
      } catch {
      }
      if (logger) {
        try {
          logger.Write("🎵 Παίζει ήδη (χωρίς επιπλέον ενέργεια).")
        } catch {
        }
      }
      return true
    }

    ; Fallback click (μόνο όταν επιτρέπεται)
    local clicked := false
    try {
      clicked := ClickCenter(hWnd, logger, 0, 80)
      ; ΝΕΟ: δηλώνουμε ότι έγινε click στο τρέχον βίντεο
      try {
        if (clicked) {
          Settings.CLICK_OCCURRED_THIS_VIDEO := true
        }
      } catch {
      }
    } catch {
      clicked := false
    }

    ; Μικρή αναμονή (MID_DELAY_MS) πριν το recheck
    local mid := 0
    try {
      mid := Settings.MID_DELAY_MS + 0
    } catch {
      mid := 3000
    }
    this.StepDelay(mid)

    try {
      plays := this.IsPlaying(hWnd, logger, guiX, guiY, guiW, guiH)
    } catch {
      plays := false
    }

    if (plays) {
      ; Αν χρειάστηκε click για να ξεκινήσει, στο επόμενο βίντεο ΘΕΛΟΥΜΕ προ-κλικ.
      ; Αν ξεκίνησε χωρίς click σε αυτό το branch (σπάνιο), κρατάμε conservative στάση: αφήνουμε την τιμή ως έχει.
      try {
        if (clicked) {
          Settings.PRE_CLICK_ENABLED := true
        }
      } catch {
      }

      if (logger) {
        try {
          if (clicked) {
            logger.Write("▶️ Έναρξη αναπαραγωγής με click στο κέντρο.")
          } else {
            logger.Write("▶️ Έναρξη αναπαραγωγής (χωρίς click).")
          }
        } catch {
        }
      }
      return true
    }

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
