; ==================== main.ahk (AHK v2) ====================
#Requires AutoHotkey v2.0
#SingleInstance Force

SetTitleMatchMode(2)
SetWorkingDir(A_ScriptDir)

; --- Includes (lib) ---
#Include ..\lib\settings.ahk
#Include ..\lib\regex.ahk
#Include ..\lib\json.ahk
#Include ..\lib\wsclient.ahk
#Include ..\lib\cdp_http.ahk
#Include ..\lib\cdp_js.ahk
#Include ..\lib\cdp.ahk
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
  btnStop  := App.Add("Button", "x+8 yp w90 h28", "Τερματισμός")
  btnCopy  := App.Add("Button", "x+24 yp w110 h28", "Αντιγραφή Log")
  btnClear := App.Add("Button", "x+8 yp w110 h28", "Καθαρισμός Log")
  btnExit  := App.Add("Button", "x+8 yp w90 h28", "Έξοδος")

  txtHead := App.Add("Text", "xm y+10 w760 h24 cBlue", "Έτοιμο. " Settings.APP_VERSION)
  txtLog  := App.Add("Edit", "xm y+6 w860 h360 ReadOnly Multi -Wrap +VScroll", "")
  App.Add("Text", "xm y+6", "Πιθανότητα επιλογής list1 (%):")
  sldProb := App.Add("Slider", "xm y+2 w300 Range0-100 TickInterval10", Settings.LIST1_PROB_PCT)
  lblProb := App.Add("Text", "x+8 yp", "list1: " Settings.LIST1_PROB_PCT "%")

  helpLine := App.Add("Text", "xm y+6 cGray", "Καθαρισμός, αποθήκευση και όλες οι παλιές συντομεύσεις έχουν αφαιρεθεί.")
  App.OnEvent("Size", (*) => GuiReflow())
  App.Show("w900 h600 Center")
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
  logInst.Write(Format("ℹ️ CDP Enabled: {}, Port: {}", (Settings.CDP_ENABLED ? "True" : "False"), Settings.CDP_PORT))

  ; Προφόρτωση λιστών
  flowCtl.LoadIdLists()
} catch Error as _eBoot {
  ; no-op
}

; --- Wire Events ---
try {
  btnStart.OnEvent("Click", (*) => OnStart())
  btnPause.OnEvent("Click", (*) => OnPauseResume())
  btnStop.OnEvent("Click",  (*) => OnStop())
  btnCopy.OnEvent("Click",  (*) => OnCopyLogs())
  btnClear.OnEvent("Click", (*) => OnClearLogs())
  btnExit.OnEvent("Click",  (*) => OnExitApp())

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
    lMargin := 12
    rMargin := 12
    topMargin := 12
    gap := 8

    x := lMargin
    y := topMargin

    btnStart.Move(x, y, 90, 28), x += 90 + gap
    btnPause.Move(x, y, 110, 28), x += 110 + gap
    btnStop.Move(x, y, 90, 28),   x += 90 + gap
    btnCopy.Move(x, y, 110, 28),  x += 110 + gap
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