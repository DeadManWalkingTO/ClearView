; ==================== main_v2_app.ahk (AHK v2) ====================
#Requires AutoHotkey v2.0
#SingleInstance Force

SetTitleMatchMode(2)
SetWorkingDir(A_ScriptDir)

; ===== Σταθερές / Ρυθμίσεις =====
EDGE_WIN     := "ahk_exe msedge.exe"
EDGE_PROC    := "msedge.exe"
; Προσαρμόστε αν χρειάζεται (x64 συνήθως: C:\Program Files\Microsoft\Edge\Application\msedge.exe)
EDGE_EXE     := "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
EDGE_PROFILE_NAME := "Chryseis"

; Playlists & videos
URL_ALL      := "https://www.youtube.com/playlist?list=PL1TQ_pTmsiADD0QnjnvlfoRV3kDUaFtXc&playnext=1&autoplay=1"
URL_GAMES    := "https://www.youtube.com/playlist?list=PL1TQ_pTmsiAAz486-6cs7ds0EM5Ee8ssp&playnext=1&autoplay=1"
; URL_SHORTS := "https://www.youtube.com/playlist?list=PL1TQ_pTmsiADjbuLSuERlL9-gcV3FGFN2&playnext=1&autoplay=1"

FIXED := [
    "https://youtu.be/SHcfDzCJFMQ?autoplay=1",
    "https://youtu.be/V_1-7NvEQ8U?autoplay=1",
    "https://youtu.be/hRSXQtHdTzk?autoplay=1",
    "https://youtu.be/WVIlygtfWmk?autoplay=1"
]

; Χρόνοι (s) & πλήθη
T_SHORT := 60
T_MED   := 90
T_LONG  := 120
CNT_ALL   := 18
CNT_GAMES := 62
; CNT_SHORTS := 25

; ===== Κατάσταση Εκτέλεσης =====
gRunning := false
gPaused := false
gStopRequested := false

; ===== GUI Εφαρμογής =====
App := Gui("+AlwaysOnTop +Resize", "YT Automation — Edge/Chryseis")
App.SetFont("s10", "Segoe UI")

; Γραμμή κουμπιών
btnStart := App.Add("Button", "xm ym w90 h28", "Start")
btnPause := App.Add("Button", "x+8 yp w110 h28", "Pause")
btnStop  := App.Add("Button", "x+8 yp w90 h28",  "Stop")

; Headline (μία γραμμή) & Log (πολλαπλές)
txtHead := App.Add("Text", "xm y+10 w760 h24 cBlue", "Έτοιμο.")
txtLog  := App.Add("Edit", "xm y+6 w760 h360 ReadOnly Multi -Wrap +VScroll"
                  , "[Log] Εκκίνηση εφαρμογής…")

; Προσαρμογή layout σε resize
App.OnEvent("Size", (*) => GuiReflow())

; Συνδέσεις γεγονότων
btnStart.OnEvent("Click", (*) => OnStart())
btnPause.OnEvent("Click", (*) => OnPauseResume())
btnStop.OnEvent("Click",  (*) => OnStop())

; Hotkeys μέσα στην app (προαιρετικά)
; ^+l καθαρισμός log, ^+s αποθήκευση log
App.Add("Text", "xm y+6 cGray", "Ctrl+Shift+L: Clear log    Ctrl+Shift+S: Save log")

; Εμφάνιση GUI (κεντραρισμένο αρχικά)
App.Show("w800 h520 Center")
Log("Εφαρμογή ξεκίνησε.")

; ===== Βοηθητικές (GUI) =====
GuiReflow() {
    global App, btnStart, btnPause, btnStop, txtHead, txtLog
    ; Απλό flow: κουμπιά επάνω, head κάτω από αυτά, log από κάτω ως fill
    ; Υπολογισμός πλάτους/ύψους παραθύρου
    App.GetPos(, , &W, &H)
    margin := 12

    ; Στοιχεία: 3 κουμπιά στην ίδια γραμμή ξεκινούν στο margin
    btnStart.Move(margin, margin, 90, 28)
    btnPause.Move(margin + 90 + 8, margin, 110, 28)
    btnStop.Move(margin + 90 + 8 + 110 + 8, margin, 90, 28)

    ; Headline
    txtHead.Move(margin, margin + 28 + 10, W - 2*margin, 24)

    ; Log
    topLog := margin + 28 + 10 + 24 + 6
    txtLog.Move(margin, topLog, W - 2*margin, H - topLog - margin - 24)
}

SetHeadline(text) {
    global txtHead
    txtHead.Value := text
}

Log(text) {
    global txtLog
    ts := FormatTime(A_Now, "HH:mm:ss")
    cur := txtLog.Value
    if (cur != "")
        cur .= "`r`n"
    cur .= "[" ts "] " text
    txtLog.Value := cur
    ; Scroll-to-bottom χωρίς να κλέβουμε focus από Edge
    hwnd := txtLog.Hwnd
    DllCall("user32\SendMessage", "ptr", hwnd, "uint", 0xB1, "ptr", -1, "ptr", -1) ; EM_SETSEL
    DllCall("user32\SendMessage", "ptr", hwnd, "uint", 0xB7, "ptr", 0, "ptr", 0)   ; EM_SCROLLCARET
}

; Hotkeys για Log
#HotIf WinActive("YT Automation — Edge/Chryseis")
^+l::{
    txtLog.Value := ""
    SetHeadline("Log καθαρίστηκε.")
}
^+s::{
    if !DirExist("logs")
        DirCreate("logs")
    fn := Format("logs\status_{:04}{:02}{:02}_{:02}{:02}{:02}.txt"
        , A_YYYY, A_MM, A_DD, A_Hour, A_Min, A_Sec)
    FileAppend(txtLog.Value, fn, "UTF-8")
    SetHeadline("Log saved → " fn), Log("Log saved → " fn)
}
#HotIf

; ===== Χειριστές Κουμπιών =====
OnStart() {
    global gRunning, gPaused, gStopRequested
    if gRunning {
        SetHeadline("Ήδη εκτελείται.")
        return
    }
    gRunning := true
    gPaused := false
    gStopRequested := false
    SetHeadline("Εκκίνηση ροής…"), Log("Start pressed")
    ; Εκτέλεση της ροής (blocking, αλλά με πολλά Sleep ώστε να δουλεύει το GUI)
    try {
        RunFlow()
    } catch e {
        Log("Σφάλμα: " e.Message)
    }
    gRunning := false
    gPaused := false
    gStopRequested := false
    SetHeadline("Έτοιμο."), Log("Flow finished / stopped")
}

OnPauseResume() {
    global gRunning, gPaused
    if !gRunning {
        SetHeadline("Δεν εκτελείται ροή.")
        return
    }
    gPaused := !gPaused
    if gPaused {
        btnPause.Text := "Resume"
        SetHeadline("⏸️ Παύση"), Log("Paused")
    } else {
        btnPause.Text := "Pause"
        SetHeadline("▶️ Συνέχιση"), Log("Resumed")
    }
}

OnStop() {
    global gRunning, gStopRequested
    if !gRunning {
        SetHeadline("Δεν εκτελείται ροή.")
        return
    }
    gStopRequested := true
    SetHeadline("Τερματισμός…"), Log("Stop requested")
}

; ===== Ροή Αυτοματισμού =====
RunFlow() {
    global EDGE_PROFILE_NAME, URL_ALL, URL_GAMES, FIXED, T_LONG, T_SHORT, T_MED, CNT_ALL, CNT_GAMES
    ; 1) Βρες φάκελο προφίλ από display name
    SetHeadline("Εύρεση φακέλου προφίλ…"), Log("Resolve profile by name: " EDGE_PROFILE_NAME)
    profDir := ResolveEdgeProfileDirByName(EDGE_PROFILE_NAME)
    if (profDir = "") {
        SetHeadline("⚠️ Δεν βρέθηκε φάκελος για: " EDGE_PROFILE_NAME), Log("Profile dir NOT found; try as-is")
        profArg := '--profile-directory="' EDGE_PROFILE_NAME '"'
    } else {
        SetHeadline("Βρέθηκε: " profDir), Log("Profile dir: " profDir)
        profArg := '--profile-directory="' profDir '"'
    }
    profArg .= " --new-window"

    ; 2) Άνοιξε ΝΕΟ παράθυρο Edge στο προφίλ
    CheckAbortOrPause()
    SetHeadline("Άνοιγμα νέου παραθύρου Edge…"), Log("OpenEdgeNewWindow")
    hNew := OpenEdgeNewWindow(profArg)
    if (!hNew) {
        SetHeadline("❌ Αποτυχία ανοίγματος Edge."), Log("OpenEdgeNewWindow failed")
        return
    }
    WinActivate("ahk_id " hNew)
    WinWaitActive("ahk_id " hNew, , 5)
    WinMaximize("ahk_id " hNew)
    Sleep(200)
    SetHeadline("Edge έτοιμος (" EDGE_PROFILE_NAME ")"), Log("Edge ready")

    ; 3) Ροές — νέα καρτέλα πριν από κάθε ενότητα
    ; ALL
    CheckAbortOrPause()
    NewTab(hNew)
    PlayPlaylist(URL_ALL, CNT_ALL, T_LONG, true)
    ; FIXED
    CheckAbortOrPause()
    NewTab(hNew)
    PlayFixed(FIXED, T_SHORT)
    ; GAMES
    CheckAbortOrPause()
    NewTab(hNew)
    PlayPlaylist(URL_GAMES, CNT_GAMES, T_MED, true)
    ; Προαιρετικά SHORTS (αν ενεργοποιήσεις)
    ; CheckAbortOrPause()
    ; NewTab(hNew)
    ; PlayPlaylist(URL_SHORTS, CNT_SHORTS, T_SHORT, false)

    ; 4) Κλείσιμο ΜΟΝΟ του νέου παραθύρου
    WinClose("ahk_id " hNew)
    WinWaitClose("ahk_id " hNew, , 5)
    SetHeadline("Κύκλος ολοκληρώθηκε."), Log("Cycle done")
}

; ===== Έλεγχοι Pause / Stop =====
CheckAbortOrPause() {
    global gPaused, gStopRequested
    while gPaused {
        Sleep(150)
        ; επιτρέπει στο GUI να ανταποκριθεί
    }
    if gStopRequested
        throw Error("Stopped by user")
}

; ===== Βοηθητικές Αυτοματισμού (Edge/YT) =====
ResolveEdgeProfileDirByName(displayName) {
    base := EnvGet("LOCALAPPDATA") "\Microsoft\Edge\User Data\"
    if !DirExist_(base)
        return ""

    candidates := ["Default"]
    Loop Files, base "*", "D" {
        dirName := A_LoopFileName
        if RegExMatch(dirName, "^Profile\s+\d+$")
            candidates.Push(dirName)
    }

    esc := RegexEscape(displayName)
    for _, cand in candidates {
        pref := base cand "\Preferences"
        if !FileExist(pref)
            continue
        txt := ""
        try txt := FileRead(pref, "UTF-8")
        catch
            continue
        if RegExMatch(txt, '"profile"\s*:\s*\{[^}]*"name"\s*:\s*"' esc '"')
            return cand
        if RegExMatch(txt, '"name"\s*:\s*"' esc '"')
            return cand
    }
    return ""
}

OpenEdgeNewWindow(profileArg) {
    global EDGE_EXE, EDGE_WIN
    before := WinGetList(EDGE_WIN)
    try Run('"' EDGE_EXE '" ' profileArg)
    catch {
        return 0
    }
    tries := 40  ; ~10s
    loop tries {
        Sleep(250)
        after := WinGetList(EDGE_WIN)
        hNew := FindNewWindowHandle(before, after)
        if (hNew)
            return hNew
    }
    return 0
}

FindNewWindowHandle(beforeArr, afterArr) {
    seen := Map()
    for _, h in beforeArr
        seen[h] := true
    for _, h in afterArr {
        if !seen.Has(h)
            return h
    }
    return 0
}

NewTab(hWnd) {
    SetHeadline("Άνοιγμα νέας καρτέλας…"), Log("NewTab")
    WinActivate("ahk_id " hWnd)
    WinWaitActive("ahk_id " hWnd, , 3)
    Send("^t")
    Sleep(250)
}

GotoURL(url) {
    SetHeadline("Μετάβαση σε URL…"), Log(url)
    Send("^l")
    Sleep(150)
    SendText(url)
    Send("{Enter}")
    Sleep(1200)
}

WaitPlayable(timeoutSec := 10) {
    loop timeoutSec {
        CheckAbortOrPause()
        Sleep(1000)
    }
}

PlayPlaylist(url, count, perItemSec, goNext := true) {
    SetHeadline("Φόρτωση playlist…"), Log("Playlist URL: " url)
    GotoURL(url)
    WaitPlayable(8)
    SetHeadline(Format("Playlist ({} στοιχεία)…", count)), Log("Playlist begin (" count ")")
    loop count {
        CheckAbortOrPause()
        SetHeadline(Format("Item {}/{} — {} s", A_Index, count, perItemSec))
        Log(Format("Item {}/{} start", A_Index, count))
        if TimerSleep(perItemSec) = "STOP"
            return
        if goNext {
            SetHeadline("Επόμενο (Shift+N)…")
            SendShiftN()
            Log(Format("Item {}/{} next", A_Index, count))
        }
    }
}

PlayFixed(arr, perItemSec) {
    idx := 0
    for , url in arr {
        idx++
        CheckAbortOrPause()
        SetHeadline(Format("Fixed {}/{} — φόρτωση…", idx, arr.Length))
        Log("Fixed URL: " url)
        GotoURL(url)
        WaitPlayable(5)
        SetHeadline(Format("Fixed {}/{} — {} s", idx, arr.Length, perItemSec))
        Log(Format("Fixed {}/{} start", idx, arr.Length))
        if TimerSleep(perItemSec) = "STOP"
            return
    }
}

TimerSleep(sec) {
    global gPaused, gStopRequested
    loop sec {
        if gStopRequested
            return "STOP"
        while gPaused
            Sleep(150)
        Sleep(1000)
    }
    return ""
}

SendShiftN() {
    Send("+n")
    Sleep(200)
}

; ===== Helpers =====
DirExist_(path) => InStr(FileExist(path), "D") > 0

RegexEscape(str) => RegExReplace(str, "([\\.^$*+?()\\[\\]{}|])", "\\$1")