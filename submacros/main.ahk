; ==================== submacros\main.ahk (AHK v2) ====================
#Requires AutoHotkey v2.0
#SingleInstance Force

SetTitleMatchMode(2)
SetWorkingDir(A_ScriptDir)

; ---- Includes προς lib (από submacros → ανεβαίνουμε ένα επίπεδο) ----
#Include ..\lib\settings.ahk
#Include ..\lib\log.ahk      ; class Logger
#Include ..\lib\edge.ahk     ; class EdgeService
#Include ..\lib\flow.ahk     ; class FlowController

; ---- SSOT: χωρίς INI ----
; (Όλες οι ρυθμίσεις προέρχονται από Settings.*)

; ---- GUI ----
App := Gui("+AlwaysOnTop +Resize", Settings.APP_TITLE " — " Settings.APP_VERSION)
App.SetFont("s10", "Segoe UI")

; Κουμπιά σε ελληνικά
btnStart := App.Add("Button", "xm ym w90 h28", "Έναρξη")
btnPause := App.Add("Button", "x+8 yp w110 h28", "Παύση")
btnStop := App.Add("Button", "x+8 yp w90 h28", "Τερματισμός")
btnCopy := App.Add("Button", "x+24 yp w110 h28", "Αντιγραφή Log")
btnClear := App.Add("Button", "x+8 yp w110 h28", "Καθαρισμός Log")

txtHead := App.Add("Text", "xm y+10 w760 h24 cBlue", "Έτοιμο. " Settings.APP_VERSION)
txtLog := App.Add("Edit", "xm y+6 w860 h360 ReadOnly Multi -Wrap +VScroll", "")

; Βοήθεια σε ελληνικά
helpLine := App.Add("Text", "xm y+6 cGray"
    , "Ctrl+Shift+L: Καθαρισμός log   Ctrl+Shift+S: Αποθήκευση log   Ctrl+Shift+A: Σχετικά")

App.OnEvent("Size", (*) => GuiReflow())
App.Show("w900 h560 Center")

; ---- Services ----
logInst := Logger(txtLog, txtHead)
edgeSvc := EdgeService(Settings.EDGE_EXE, Settings.EDGE_WIN_SEL)
flowCtl := FlowController(logInst, edgeSvc, Settings)

; Defaults για paths δεδομένων
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

; ---- Wire events ----
btnStart.OnEvent("Click", (*) => OnStart())
btnPause.OnEvent("Click", (*) => OnPauseResume())
btnStop.OnEvent("Click", (*) => OnStop())
btnCopy.OnEvent("Click", (*) => OnCopyLogs())
btnClear.OnEvent("Click", (*) => OnClearLogs())

#HotIf WinActive(Settings.APP_TITLE " — " Settings.APP_VERSION)
^+l:: OnClearLogs()
^+s:: {
    if !DirExist("logs")
        DirCreate("logs")
    fn := Format("logs\καταγραφή_{:04}{:02}{:02}_{:02}{:02}{:02}.txt"
        , A_YYYY, A_MM, A_DD, A_Hour, A_Min, A_Sec)
    FileAppend(txtLog.Value, fn, "UTF-8")
    logInst.SetHeadline("💾 Το Log Αποθηκεύτηκε → " fn), logInst.Write("💾 Το Log Αποθηκεύτηκε → " fn)
}
^+a:: ShowAbout()
#HotIf

; ---- Handlers ----
OnStart() {
    global flowCtl, logInst
    if flowCtl.IsRunning() {
        logInst.SetHeadline("ℹ️ Ήδη Εκτελείται.")
        logInst.Write("ℹ️ Η Έναρξη Πατήθηκε Ενώ Εκτελείται — Αγνοήθηκε")
        return
    }
    flowCtl.StartRun()
}

OnPauseResume() {
    global flowCtl, logInst, btnPause
    if !flowCtl.IsRunning() {
        logInst.SetHeadline("ℹ️ Δεν Εκτελείται Ροή.")
        logInst.Write("ℹ️ Η Παύση/Συνέχεια Πατήθηκε Ενώ Δεν Εκτελείται — Αγνοήθηκε")
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
        logInst.SetHeadline("ℹ️ Δεν Εκτελείται Ροή.")
        logInst.Write("ℹ️ Ο Τερματισμός Πατήθηκε Ενώ Δεν Εκτελείται — Αγνοήθηκε")
        return
    }
    flowCtl.RequestStop()
    logInst.SetHeadline("🛑 Τερματισμός…"), logInst.Write("🛑 Αίτημα Τερματισμού")
}

OnCopyLogs() {
    global txtLog, logInst
    A_Clipboard := txtLog.Value
    logInst.Write("📋 Αντιγραφή Log Στο Πρόχειρο")
    logInst.SetHeadline("📋 Αντιγράφηκε Στο Πρόχειρο")
}

OnClearLogs() {
    global logInst
    logInst.Clear()
    logInst.SetHeadline("🧹 Το Log Καθαρίστηκε.")
    logInst.Write("🧹 Καθαρισμός Από Χρήστη")
}

ShowAbout() {
    global logInst
    MsgBox(Settings.APP_TITLE " — " Settings.APP_VERSION "`n"
        . "Προφίλ (εμφάνιση): " Settings.EDGE_PROFILE_NAME "`n"
        . "Διαδρομή Edge: " Settings.EDGE_EXE "`n"
        . "Παραμονή παραθύρου: " (Settings.KEEP_EDGE_OPEN ? "Ναι" : "Όχι")
        , "Σχετικά", "Iconi")
    logInst.Write(Format("ℹ️ About Shown — { } { }", Settings.APP_TITLE, Settings.APP_VERSION))
}

GuiReflow() {
    global App, btnStart, btnPause, btnStop, btnCopy, btnClear, txtHead, txtLog, helpLine
    App.GetPos(, , &W, &H)
    margin := 12
    btnStart.Move(margin, margin, 90, 28)
    btnPause.Move(margin + 90 + 8, margin, 110, 28)
    btnStop.Move(margin + 90 + 8 + 110 + 8, margin, 90, 28)
    btnCopy.Move(W - margin - 110 - 8 - 110, margin, 110, 28)
    btnClear.Move(W - margin - 110, margin, 110, 28)
    txtHead.Move(margin, margin + 28 + 10, W - 2 * margin, 24)
    topLog := margin + 28 + 10 + 24 + 6
    helpLine.Move(margin, H - margin - 20, W - 2 * margin, 20)
    txtLog.Move(margin, topLog, W - 2 * margin, (H - topLog - margin - 24) - 24)
}
; ==================== End Of File ====================
