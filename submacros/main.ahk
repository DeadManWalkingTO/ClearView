; ==================== main.ahk (AHK v2) ====================
#Requires AutoHotkey v2.0
#SingleInstance Force

SetTitleMatchMode(2)
SetWorkingDir(A_ScriptDir)

; --- Includes (lib) ---
#Include ..\lib\settings.ahk
#Include ..\lib\regex.ahk
#Include ..\lib\edge.ahk
#Include ..\lib\flow.ahk
#Include ..\lib\log.ahk

; --- GUI ---
AppTitle := Settings.APP_TITLE " — " Settings.APP_VERSION
try {
  App := Gui("+AlwaysOnTop +Resize", AppTitle)
  App.SetFont("s10", "Segoe UI")
} catch Error as _eGui {
  MsgBox("Αποτυχία δημιουργίας GUI.", "Σφάλμα", "Iconx")
  ExitApp
}

try {
  btnStart := App.Add("Button", "xm ym w90 h28", "Έναρξη")
  btnPause := App.Add("Button", "x+8 yp w110 h28", "Παύση")
  btnStop := App.Add("Button", "x+8 yp w90 h28", "Τερματισμός")
  btnCopy := App.Add("Button", "x+24 yp w110 h28", "Αντιγραφή Log")
  btnClear := App.Add("Button", "x+8 yp w110 h28", "Καθαρισμός Log")
  btnExit := App.Add("Button", "x+8 yp w90 h28", "Έξοδος")

  txtHead := App.Add("Text", "xm y+10 w760 h24 cBlue", "Έτοιμο. " Settings.APP_VERSION)
  txtLog := App.Add("Edit", "xm y+6 w860 h360 ReadOnly Multi -Wrap +VScroll", "")
  App.Add("Text", "xm y+6", "Πιθανότητα επιλογής list1 (%):")
  sldProb := App.Add("Slider", "xm y+2 w300 Range0-100 TickInterval10", Settings.LIST1_PROB_PCT)
  lblProb := App.Add("Text", "x+8 yp", "list1: " Settings.LIST1_PROB_PCT "%")
  helpLine := App.Add("Text", "xm y+6 cGray", "Η εύρεση διάρκειας έχει αφαιρεθεί πλήρως.")

  ; Εμφάνιση με συγκεκριμένο μέγεθος (χωρίς Center — θα τοποθετηθεί κάτω-δεξιά αυτόματα)
  App.Show("w670 h400")
} catch Error as _eGui2 {
  MsgBox("Αποτυχία σύνθεσης στοιχείων GUI.", "Σφάλμα", "Iconx")
  ExitApp
}

; --- Services ---
try {
  logInst := Logger(txtLog, txtHead)
  edgeSvc := EdgeService(Settings.EDGE_EXE, Settings.EDGE_WIN_SEL)
  flowCtl := FlowController(logInst, edgeSvc, Settings)
} catch Error as _eSvc {
  MsgBox("Αποτυχία δημιουργίας services.", "Σφάλμα", "Iconx")
  ExitApp
}

; --- Bottom-Right Auto Positioning ---
global _br_margin := 10
global _movingProgrammatically := false
global _currentMonitorIdx := 0

GetMonitorIndexForWindow() {
  global App
  ; Εντοπισμός monitor με βάση το κέντρο του παραθύρου
  try {
    App.GetPos(&winX, &winY, &W, &H)
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
  global App, _currentMonitorIdx, _movingProgrammatically
  try {
    ; Επιλογή τρέχοντος monitor (ή primary)
    monIdx := GetMonitorIndexForWindow()
    _currentMonitorIdx := monIdx

    ; Work area του monitor (λαμβάνει υπόψη taskbar)
    MonitorGetWorkArea(monIdx, &waL, &waT, &waR, &waB)

    ; Τρέχον μέγεθος GUI
    App.GetPos(, , &W, &H)

    ; Υπολογισμός συντεταγμένων
    x := waR - W - margin
    y := waB - H - margin

    ; Μετακίνηση (με καταστολή WM_MOVE recursion)
    _movingProgrammatically := true
    App.Move(x, y)
    Sleep(25)
    _movingProgrammatically := false
  } catch Error as _eBR {
    ; no-op
  }
}

OnAppSize(*) {
  global _br_margin, _movingProgrammatically
  try {
    ; κάτω-δεξιά μετά από resize
    PositionBottomRight(_br_margin)
  } catch Error as _eSize {
    ; no-op
  }
}

WM_DISPLAYCHANGE_Handler(wParam, lParam, msg, hwnd) {
  global _br_margin
  try {
    ; Κάθε αλλαγή διάταξης/ανάλυσης → επανατοποθέτηση
    PositionBottomRight(_br_margin)
  } catch Error as _eDisp {
    ; no-op
  }
}

WM_MOVE_Handler(wParam, lParam, msg, hwnd) {
  ; Αναλύει monitor-index αλλαγές κατά τη μετακίνηση και επανατοποθετεί κάτω-δεξιά
  global _br_margin, _currentMonitorIdx, _movingProgrammatically

  ; Αν το κινούμε εμείς, αγνόησε (αποφυγή recursion)
  if (_movingProgrammatically) {
    return
  }

  try {
    newIdx := GetMonitorIndexForWindow()
  } catch Error as _eMon {
    newIdx := _currentMonitorIdx
  }

  ; Μόνο αν άλλαξε monitor-index, επανατοποθέτησε
  if (newIdx != _currentMonitorIdx) {
    _currentMonitorIdx := newIdx
    PositionBottomRight(_br_margin)
  }
}

; Wire: Size + DisplayChange + Move
try {
  App.OnEvent("Size", OnAppSize)
} catch Error as _eSizeWire {
  ; no-op
}
OnMessage(0x007E, WM_DISPLAYCHANGE_Handler) ; WM_DISPLAYCHANGE
OnMessage(0x0003, WM_MOVE_Handler)          ; WM_MOVE

; Αρχική κάτω-δεξιά τοποθέτηση μετά το Show
PositionBottomRight(_br_margin)

; --- Boot logs ---
try {
  logInst.Write("ℹ️ Έναρξη Εφαρμογής.")
  logInst.Write(Format("ℹ️ Έκδοση: {}", Settings.APP_VERSION))
  logInst.Write(Format("ℹ️ Εκτελέσιμο Edge: {}", Settings.EDGE_EXE))
  logInst.Write(Format("ℹ️ Προφίλ: {}", Settings.EDGE_PROFILE_NAME))
  logInst.Write(Format("ℹ️ Διατήρηση Παραθύρου: {}", (Settings.KEEP_EDGE_OPEN ? "Ναι" : "Όχι")))
  logInst.Write(Format("ℹ️ Paths: list={} - random={}", Settings.DATA_LIST_TXT, Settings.DATA_RANDOM_TXT))
  logInst.Write(Format("ℹ️ Πιθανότητα list1: {}%", Settings.LIST1_PROB_PCT))
  logInst.Write(Format("ℹ️ Close Other Windows: {}", (Settings.CLOSE_ALL_OTHER_WINDOWS ? "True" : "False")))
  flowCtl.LoadIdLists()
} catch Error as _eBoot {
  ; no-op
}

; --- Wire Events ---
try {
  btnStart.OnEvent("Click", (*) => OnStart())
  btnPause.OnEvent("Click", (*) => OnPauseResume())
  btnStop.OnEvent("Click", (*) => OnStop())
  btnCopy.OnEvent("Click", (*) => OnCopyLogs())
  btnClear.OnEvent("Click", (*) => OnClearLogs())
  btnExit.OnEvent("Click", (*) => OnExitApp())
  sldProb.OnEvent("Change", SliderProb_Changed)
} catch Error as _eWire {
  ; no-op
}

; --- Handlers ---
OnStart() {
  global flowCtl, logInst
  try {
    if flowCtl.IsRunning() {
      logInst.SetHeadline("ℹ️ Ήδη Εκτελείται.")
      logInst.Write("ℹ️ Αγνοήθηκε")
      return
    }
    flowCtl.StartRun()
  } catch Error as _eStart {
    ; no-op
  }
}

OnPauseResume() {
  global flowCtl, logInst, btnPause
  try {
    if !flowCtl.IsRunning() {
      logInst.SetHeadline("ℹ️ Δεν Εκτελείται Ροή.")
      logInst.Write("ℹ️ Αγνοήθηκε")
      return
    }
    if flowCtl.TogglePause() {
      btnPause.Text := "Συνέχεια"
      logInst.SetHeadline("⏸️ Παύση")
      logInst.Write("⏸️ Παύση")
    } else {
      btnPause.Text := "Παύση"
      logInst.SetHeadline("▶️ Συνέχεια")
      logInst.Write("▶️ Συνέχεια")
    }
  } catch Error as _ePause {
    ; no-op
  }
}

OnStop() {
  global flowCtl, logInst
  try {
    if !flowCtl.IsRunning() {
      logInst.SetHeadline("ℹ️ Δεν Εκτελείται Ροή.")
      logInst.Write("ℹ️ Αγνοήθηκε")
      return
    }
    flowCtl.RequestStop()
    logInst.SetHeadline("🛑 Τερματισμός…")
    logInst.Write("🛑 Αίτημα Τερματισμού")
  } catch Error as _eStop {
    ; no-op
  }
}

OnCopyLogs() {
  global txtLog, logInst
  try {
    A_Clipboard := txtLog.Value
    logInst.Write("📋 Αντιγραφή Log Στο Πρόχειρο")
    logInst.SetHeadline("📋 Αντιγράφηκε")
  } catch Error as _eCopy {
    ; no-op
  }
}

OnClearLogs() {
  global logInst
  try {
    logInst.Clear()
    logInst.SetHeadline("🧼 Καθαρίστηκε")
    logInst.Write("🧼 Καθαρισμός Log")
  } catch Error as _eClear {
    ; no-op
  }
}

OnExitApp() {
  global logInst
  try {
    logInst.SetHeadline("🚪 Έξοδος")
    logInst.Write("🚪 Τερματισμός")
  } catch Error as _eExit {
    ; no-op
  }
  ExitApp
}

SliderProb_Changed(ctrl, info) {
  global lblProb, logInst
  try {
    Settings.LIST1_PROB_PCT := ctrl.Value
    lblProb.Text := "list1: " Settings.LIST1_PROB_PCT "%"
    logInst.Write("🎛️ Πιθανότητα list1 ενημερώθηκε σε " Settings.LIST1_PROB_PCT "%")
  } catch Error as _eSld {
    ; no-op
  }
}

GuiReflow() {
  global App, btnStart, btnPause, btnStop, btnCopy, btnClear, btnExit, txtHead, txtLog, helpLine, sldProb, lblProb
  try {
    App.GetPos(, , &W, &H)
    lMargin := 12, rMargin := 12, topMargin := 12, gap := 8
    x := lMargin, y := topMargin

    btnStart.Move(x, y, 90, 28), x += 90 + gap
    btnPause.Move(x, y, 110, 28), x += 110 + gap
    btnStop.Move(x, y, 90, 28), x += 90 + gap
    btnCopy.Move(x, y, 110, 28), x += 110 + gap
    btnClear.Move(x, y, 110, 28), x += 110 + gap
    btnExit.Move(x, y, 90, 28)

    txtHead.Move(lMargin, y + 28 + 10, W - lMargin - rMargin, 24)
    topLog := y + 28 + 10 + 24 + 6

    sldY := topLog
    sldProb.Move(lMargin, sldY, 300, 24)
    lblProb.Move(lMargin + 300 + 8, sldY, 140, 24)

    helpLine.Move(lMargin, H - topMargin - 20, W - lMargin - rMargin, 20)
    txtLog.Move(lMargin, sldY + 30, W - lMargin - rMargin, (H - (sldY + 30) - topMargin - 24) - 24)
  } catch Error as _eReflow {
    ; no-op
  }
}
; ==================== End Of File ====================
