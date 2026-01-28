; ==================== submacros\main.ahk (AHK v2) ====================
#Requires AutoHotkey v2.0
#SingleInstance Force
SetTitleMatchMode(2)
SetWorkingDir(A_ScriptDir)

#Include ..\lib\settings.ahk
#Include ..\lib\log.ahk
#Include ..\lib\edge.ahk
#Include ..\lib\flow.ahk

; ---- GUI ----
App := Gui("+AlwaysOnTop +Resize", Settings.APP_TITLE " — " Settings.APP_VERSION)
App.SetFont("s10", "Segoe UI")

btnStart := App.Add("Button", "xm ym w90 h28", "Έναρξη")
btnPause := App.Add("Button", "x+8 yp w110 h28", "Παύση")
btnStop := App.Add("Button", "x+8 yp w90 h28", "Τερματισμός")
btnCopy := App.Add("Button", "x+24 yp w110 h28", "Αντιγραφή Log")
btnClear := App.Add("Button", "x+8 yp w110 h28", "Καθαρισμός Log")
btnExit := App.Add("Button", "x+8 yp w90 h28", "Έξοδος")

txtHead := App.Add("Text", "xm y+10 w760 h24 cBlue", "Έτοιμο. " Settings.APP_VERSION)
txtLog := App.Add("Edit", "xm y+6 w860 h360 ReadOnly Multi -Wrap +VScroll", "")

helpLine := App.Add("Text", "xm y+6 cGray"
    , "Καθαρισμός, αποθήκευση και όλες οι παλιές συντομεύσεις έχουν αφαιρεθεί.")

App.OnEvent("Size", (*) => GuiReflow())
App.Show("w900 h560 Center")

; ---- Services ----
logInst := Logger(txtLog, txtHead)
edgeSvc := EdgeService(Settings.EDGE_EXE, Settings.EDGE_WIN_SEL)
flowCtl := FlowController(logInst, edgeSvc, Settings)

; ---- Defaults ----
if (Settings.DATA_LIST_TXT = "")
    Settings.DATA_LIST_TXT := A_ScriptDir "\..\data\list.txt"
if (Settings.DATA_RANDOM_TXT = "")
    Settings.DATA_RANDOM_TXT := A_ScriptDir "\..\data\random.txt"

; ---- Boot Logs ----
logInst.Write("ℹ️ Έναρξη Εφαρμογής.")
logInst.Write("ℹ️ Έκδοση: " Settings.APP_VERSION)
logInst.Write("ℹ️ Εκτελέσιμο Edge: " Settings.EDGE_EXE)
logInst.Write("ℹ️ Προφίλ: " Settings.EDGE_PROFILE_NAME)
logInst.Write("ℹ️ Διατήρηση Παραθύρου: " (Settings.KEEP_EDGE_OPEN ? "Ναι" : "Όχι"))
logInst.Write("ℹ️ Η Εφαρμογή Ξεκίνησε.")

; ---- Wire Events ----
btnStart.OnEvent("Click", (*) => OnStart())
btnPause.OnEvent("Click", (*) => OnPauseResume())
btnStop.OnEvent("Click", (*) => OnStop())
btnCopy.OnEvent("Click", (*) => OnCopyLogs())
btnClear.OnEvent("Click", (*) => OnClearLogs())
btnExit.OnEvent("Click", (*) => OnExitApp())

; ---- Handlers ----
OnStart() {
    global flowCtl, logInst
    if flowCtl.IsRunning() {
        logInst.SetHeadline("ℹ️ Ήδη Εκτελείται."), logInst.Write("ℹ️ Πατήθηκε ενώ εκτελείται")
        return
    }
    flowCtl.StartRun()
}

OnPauseResume() {
    global flowCtl, logInst, btnPause
    if !flowCtl.IsRunning() {
        logInst.SetHeadline("ℹ️ Δεν Εκτελείται Ροή."), logInst.Write("ℹ️ Αγνοήθηκε")
        return
    }
    if flowCtl.TogglePause() {
        btnPause.Text := "Συνέχεια"
        logInst.SetHeadline("⏸️ Παύση"), logInst.Write("⏸️ Παύση")
    } else {
        btnPause.Text := "Παύση"
        logInst.SetHeadline("▶️ Συνέχεια"), logInst.Write("▶️ Συνέχεια")
    }
}

OnStop() {
    global flowCtl, logInst
    if !flowCtl.IsRunning() {
        logInst.SetHeadline("ℹ️ Δεν Εκτελείται Ροή."), logInst.Write("ℹ️ Αγνοήθηκε")
        return
    }
    flowCtl.RequestStop()
    logInst.SetHeadline("🛑 Τερματισμός…"), logInst.Write("🛑 Αίτημα Τερματισμού")
}

OnCopyLogs() {
    global txtLog, logInst
    A_Clipboard := txtLog.Value
    logInst.Write("📋 Αντιγραφή Log Στο Πρόχειρο")
    logInst.SetHeadline("📋 Αντιγράφηκε")
}

OnClearLogs() {
    global logInst
    logInst.Clear()
    logInst.SetHeadline("🧹 Καθαρίστηκε")
    logInst.Write("🧹 Καθαρισμός Log")
}

OnExitApp() {
    global logInst
    logInst.SetHeadline("🚪 Έξοδος"), logInst.Write("🚪 Τερματισμός")
    ExitApp
}

; ---- Ενιαία Οριζόντια Σειρά Κουμπιών ----
GuiReflow() {
    global App, btnStart, btnPause, btnStop, btnCopy, btnClear, btnExit, txtHead, txtLog, helpLine
    App.GetPos(, , &W, &H)

    lMargin := 12
    rMargin := 12
    topMargin := 12
    gap := 8

    ; Σειριακή διάταξη κουμπιών
    x := lMargin, y := topMargin
    btnStart.Move(x, y, 90, 28), x += 90 + gap
    btnPause.Move(x, y, 110, 28), x += 110 + gap
    btnStop.Move(x, y, 90, 28), x += 90 + gap
    btnCopy.Move(x, y, 110, 28), x += 110 + gap
    btnClear.Move(x, y, 110, 28), x += 110 + gap
    btnExit.Move(x, y, 90, 28)

    txtHead.Move(lMargin, y + 28 + 10, W - lMargin - rMargin, 24)
    topLog := y + 28 + 10 + 24 + 6

    helpLine.Move(lMargin, H - topMargin - 20, W - lMargin - rMargin, 20)
    txtLog.Move(lMargin, topLog, W - lMargin - rMargin, (H - topLog - topMargin - 24) - 24)
}
; ==================== End Of File ====================
