; ==================== lib/ui_window.ahk ====================
#Requires AutoHotkey v2.0
#Include "settings.ahk"
class UiWindow {
  __New() {
    this._app := 0
    this._controls := Map()
    this._br_margin := 10
    this._movingProgrammatically := false
    this._currentMonitorIdx := 0
  }
  CreateWindow() {
    AppTitle := Settings.APP_TITLE " — " Settings.APP_VERSION
    try {
      this._app := Gui("+AlwaysOnTop -Resize -MaximizeBox", AppTitle)
      this._app.SetFont("s10", "Segoe UI")
      guiW := Settings.GUI_MIN_W + 0
      guiH := Settings.GUI_MIN_H + 0
      if (guiW < 200) {
        guiW := 200
      }
      if (guiH < 200) {
        guiH := 200
      }
      this._app.Opt("+MinSize" guiW "x" guiH)
      this._app.Opt("+MaxSize" guiW "x" guiH)
    } catch Error as _eGui {
      MsgBox("Αποτυχία δημιουργίας GUI.", "Σφάλμα", "Iconx")
      ExitApp
    }
  }
  AddControls() {
    try {
      c := this._controls
      c["btnStart"] := this._app.Add("Button", "xm ym w90  h28", "Έναρξη")
      c["btnPause"] := this._app.Add("Button", "x+8 yp w110 h28", "Παύση")
      c["btnStop"] := this._app.Add("Button", "x+8 yp w90  h28", "Τερματισμός")
      c["btnCopy"] := this._app.Add("Button", "x+24 yp w110 h28", "Αντιγραφή Log")
      c["btnClear"] := this._app.Add("Button", "x+8 yp w110 h28", "Καθαρισμός Log")
      c["btnExit"] := this._app.Add("Button", "x+8 yp w90  h28", "Έξοδος")

      c["txtProbTitle"] := this._app.Add("Text", "xm y+10", "Πιθανότητα επιλογής list1 (%):")
      c["sldProb"] := this._app.Add("Slider", "xm y+2 w150 Range0-100 TickInterval10", Settings.LIST1_PROB_PCT)
      c["lblProb"] := this._app.Add("Text", "x+8 yp", "list1: " Settings.LIST1_PROB_PCT "%")

      ; (ΑΦΑΙΡΕΘΗΚΕ: chkClickToPlay)

      ; Defaults λεπτών από *_MS ή fallback σε *_MINUTES
      defMinMin := 0
      defMaxMin := 0
      try {
        defMinMin := Floor((Settings.LOOP_MIN_MS + 0) / 60000)
      } catch Error as _eL1 {
        defMinMin := 0
      }
      try {
        defMaxMin := Floor((Settings.LOOP_MAX_MS + 0) / 60000)
      } catch Error as _eL2 {
        defMaxMin := 0
      }
      if (defMinMin <= 0) {
        try {
          defMinMin := Settings.LOOP_MIN_MINUTES + 0
        } catch Error as _eL3 {
          defMinMin := 5
        }
      }
      if (defMaxMin <= 0) {
        try {
          defMaxMin := Settings.LOOP_MAX_MINUTES + 0
        } catch Error as _eL4 {
          defMaxMin := 10
        }
      }
      if (defMaxMin < defMinMin) {
        t := defMinMin
        defMinMin := defMaxMin
        defMaxMin := t
      }

      c["txtLoopTitle"] := this._app.Add("Text", "x+14 yp", "Διάστημα (λεπτά):")
      c["edtLoopMin"] := this._app.Add("Edit", "x+6 yp w40 Limit2")
      c["udLoopMin"] := this._app.Add("UpDown", "Range1-25 0x80", defMinMin) ; buddy left
      c["txtLoopTo"] := this._app.Add("Text", "x+6 yp", "έως")
      c["edtLoopMax"] := this._app.Add("Edit", "x+6 yp w40 Limit2")
      c["udLoopMax"] := this._app.Add("UpDown", "Range1-25 0x80", defMaxMin) ; buddy left

      c["txtHead"] := this._app.Add("Text", "xm y+10 w760 h24 cBlue", "Έτοιμο. " Settings.APP_VERSION)
      c["txtLog"] := this._app.Add("Edit", "xm y+6 w10 h10 ReadOnly Multi -Wrap +VScroll", "")
      c["helpLine"] := this._app.Add("Text", "xm y+6 cGray", "Η εύρεση διάρκειας έχει αφαιρεθεί πλήρως.")
    } catch Error as _eControls {
      MsgBox("Αποτυχία σύνθεσης στοιχείων GUI.", "Σφάλμα", "Iconx")
      ExitApp
    }
  }
  ShowWindow() {
    try {
      this._app.Show("w" Settings.GUI_MIN_W " h" Settings.GUI_MIN_H)
    } catch Error as _eShow {
      ; no-op
    }
  }
  GuiReflow() {
    try {
      this._app.GetPos(, , &W, &H)
      lMargin := 12
      rMargin := 12
      topMargin := 12
      gap := 8
      x := lMargin
      y := topMargin
      c := this._controls

      ; --- Πάνω σειρά κουμπιών ---
      c["btnStart"].Move(x, y, 90, 28)
      x += 90 + gap
      c["btnPause"].Move(x, y, 110, 28)
      x += 110 + gap
      c["btnStop"].Move(x, y, 90, 28)
      x += 90 + gap
      c["btnCopy"].Move(x, y, 110, 28)
      x += 110 + gap
      c["btnClear"].Move(x, y, 110, 28)
      x += 110 + gap
      c["btnExit"].Move(x, y, 90, 28)

      ; --- Slider/label ---
      probY := y + 28 + 10
      c["txtProbTitle"].Move(lMargin, probY, W - lMargin - rMargin, 20)
      sldY := probY + 20 + 4
      c["sldProb"].Move(lMargin, sldY, 150, 24)

      lblX := lMargin + 150 + 8
      c["lblProb"].Move(lblX, sldY)

      ; Πραγματικό πλάτος label
      lbx := lblX, lby := sldY, lbw := 0, lbh := 0
      try {
        c["lblProb"].GetPos(&lbx, &lby, &lbw, &lbh)
      } catch Error as _eGetLbl {
        lbw := 60
        lbh := 24
      }

      ; --- Διάστημα (λεπτά) — REFLOW χωρίς checkbox ---
      loopX := lbx + lbw + 12
      loopY := sldY

      ; Μετρήσεις ύψους controls
      lth0 := 24, emh0 := 24, umh0 := 24, tth0 := 24, eah0 := 24, uah0 := 24
      try c["txtLoopTitle"].GetPos(, , , &lth0)

      try c["edtLoopMin"].GetPos(, , , &emh0)

      try c["udLoopMin"].GetPos(, , , &umh0)

      try c["txtLoopTo"].GetPos(, , , &tth0)

      try c["edtLoopMax"].GetPos(, , , &eah0)

      try c["udLoopMax"].GetPos(, , , &uah0)


      commonH := lth0
      if (emh0 > commonH) {
        commonH := emh0
      }
      if (umh0 > commonH) {
        commonH := umh0
      }
      if (tth0 > commonH) {
        commonH := tth0
      }
      if (eah0 > commonH) {
        commonH := eah0
      }
      if (uah0 > commonH) {
        commonH := uah0
      }
      if (commonH < 20) {
        commonH := 24
      }

      c["txtLoopTitle"].Move(loopX, loopY) ; autosize
      ltx := loopX, lty := loopY, ltw := 130, lth := commonH
      try c["txtLoopTitle"].GetPos(&ltx, &lty, &ltw, &lth)


      c["txtLoopTitle"].Move(loopX, loopY, , commonH)
      loopX := loopX + ltw + 6

      c["edtLoopMin"].Move(loopX, loopY, 40, commonH)
      edMinX := loopX, edMinW := 40
      udMinW := 16, udMinH := commonH
      udMinX := edMinX + edMinW
      c["udLoopMin"].Move(udMinX, loopY, udMinW, udMinH)

      loopX := loopX + 40 + udMinW + 6
      c["txtLoopTo"].Move(loopX, loopY, , commonH)
      loopX := loopX + 26 + 6

      c["edtLoopMax"].Move(loopX, loopY, 40, commonH)
      edMaxX := loopX, edMaxW := 40
      udMaxW := 16, udMaxH := commonH
      udMaxX := edMaxX + edMaxW
      c["udLoopMax"].Move(udMaxX, loopY, udMaxW, udMaxH)

      ; --- Επικεφαλίδα & βοηθητική ---
      headY := loopY + commonH + 10
      c["txtHead"].Move(lMargin, headY, W - lMargin - rMargin, 24)

      ; --- Log περιοχή ---
      topLog := headY + 24 + 6
      bottomGap := 6
      helpH := 20
      helpY := H - topMargin - helpH
      logH := (helpY - bottomGap) - topLog
      if (logH < 0) {
        logH := 0
      }

      wLog := W - lMargin - rMargin
      if (wLog < 200) {
        wLog := 200
      }

      c["txtLog"].Move(lMargin, topLog, wLog, logH)
      c["helpLine"].Move(lMargin, helpY, W - lMargin - rMargin, helpH)
    } catch Error as _eReflow {
      ; no-op
    }
  }
  WirePositioning() {
    try {
      OnMessage(0x007E, (wParam, lParam, msg, hwnd) => this.WM_DISPLAYCHANGE_Handler(wParam, lParam, msg, hwnd)) ; WM_DISPLAYCHANGE
      OnMessage(0x0003, (wParam, lParam, msg, hwnd) => this.WM_MOVE_Handler(wParam, lParam, msg, hwnd))         ; WM_MOVE
      this.PositionBottomRight(this._br_margin)
    } catch Error as _eWire {
      ; no-op
    }
  }
  GetMonitorIndexForWindow() {
    try {
      this._app.GetPos(&winX, &winY, &W, &H)
    } catch Error as _ePos {
      return MonitorGetPrimary()
    }
    winCenterX := winX + Floor(W / 2)
    winCenterY := winY + Floor(H / 2)
    monCount := 1
    try {
      monCount := MonitorGetCount()
    } catch Error as _eCnt {
      monCount := 1
    }
    idx := MonitorGetPrimary()
    i := 1
    try {
      loop monCount {
        MonitorGet(i, &mL, &mT, &mR, &mB)
        if (winCenterX >= mL) {
          if (winCenterX <= mR) {
            if (winCenterY >= mT) {
              if (winCenterY <= mB) {
                idx := i
                break
              }
            }
          }
        }
        i += 1
      }
    } catch Error as _eScan {
      ; no-op
    }
    return idx
  }
  PositionBottomRight(margin := 10) {
    try {
      monIdx := this.GetMonitorIndexForWindow()
      this._currentMonitorIdx := monIdx
      MonitorGetWorkArea(monIdx, &waL, &waT, &waR, &waB)
      this._app.GetPos(, , &W, &H)
      x := waR - W - margin
      y := waB - H - margin
      this._movingProgrammatically := true
      this._app.Move(x, y)
      Sleep(25)
      this._movingProgrammatically := false
    } catch Error as _eBR {
      ; no-op
    }
  }
  WM_DISPLAYCHANGE_Handler(wParam, lParam, msg, hwnd) {
    try {
      this.PositionBottomRight(this._br_margin)
    } catch Error as _eDisp {
      ; no-op
    }
  }
  WM_MOVE_Handler(wParam, lParam, msg, hwnd) {
    if (this._movingProgrammatically) {
      return
    }
    try {
      newIdx := this.GetMonitorIndexForWindow()
    } catch Error as _eMon {
      newIdx := this._currentMonitorIdx
    }
    if (newIdx != this._currentMonitorIdx) {
      this._currentMonitorIdx := newIdx
      this.PositionBottomRight(this._br_margin)
    }
  }

  ; --- Getters ---
  GetApp() {
    return this._app
  }
  GetControls() {
    return this._controls
  }
  GetControl(name) {
    try {
      if (this._controls.Has(name)) {
        return this._controls[name]
      } else {
        return 0
      }
    } catch Error as _e {
      return 0
    }
  }
}
; ==================== End Of File ====================
