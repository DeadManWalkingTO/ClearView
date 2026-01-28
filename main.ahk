; ==================== main_v2_app_clean.ahk (AHK v2) ====================
#Requires AutoHotkey v2.0
#SingleInstance Force

SetTitleMatchMode(2)
SetWorkingDir(A_ScriptDir)

; ===== Σταθερές / Ρυθμίσεις =====
EDGE_WIN     := "ahk_exe msedge.exe"
EDGE_PROC    := "msedge.exe"
; Αν έχεις 64-bit Edge, άλλαξε διαδρομή:
EDGE_EXE     := "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
EDGE_PROFILE_NAME := "Chryseis"

; ===== Κατάσταση Εκτέλεσης =====
gRunning := false
gPaused := false
gStopRequested := false

; ===== GUI Εφαρμογής =====
App := Gui("+AlwaysOnTop +Resize", "YT Automation — Edge/Chryseis (CLEAN)")
App.SetFont("s10", "Segoe UI")

; Γραμμή κουμπιών
btnStart := App.Add("Button", "xm ym w90 h28", "Start")
btnPause := App.Add("Button", "x+8 yp w110 h28", "Pause")
btnStop  := App.Add("Button", "x+8 yp w90 h28",  "Stop")

; Headline & Log
txtHead := App.Add("Text", "xm y+10 w760 h24 cBlue", "Έτοιμο.")
txtLog  := App.Add("Edit", "xm y+6 w760 h360 ReadOnly Multi -Wrap +VScroll"
                  , "[Log] Εκκίνηση εφαρμογής…")

; Resize layout
App.OnEvent("Size", (*) => GuiReflow())

; Events
btnStart.OnEvent("Click", (*) => OnStart())
btnPause.OnEvent("Click", (*) => OnPauseResume())
btnStop.OnEvent("Click",  (*) => OnStop())

; Help line
App.Add("Text", "xm y+6 cGray", "Ctrl+Shift+L: Clear log    Ctrl+Shift+S: Save log")

; Show GUI
App.Show("w800 h520 Center")
Log("Εφαρμογή ξεκίνησε (clean).")

; ===== GUI Helpers =====
GuiReflow() {
    global App, btnStart, btnPause, btnStop, txtHead, txtLog
    App.GetPos(, , &W, &H)
    margin := 12
    btnStart.Move(margin, margin, 90, 28)
    btnPause.Move(margin + 90 + 8, margin, 110, 28)
    btnStop.Move(margin + 90 + 8 + 110 + 8, margin, 90, 28)
    txtHead.Move(margin, margin + 28 + 10, W - 2*margin, 24)
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
    hwnd := txtLog.Hwnd
    DllCall("user32\SendMessage", "ptr", hwnd, "uint", 0xB1, "ptr", -1, "ptr", -1) ; EM_SETSEL
    DllCall("user32\SendMessage", "ptr", hwnd, "uint", 0xB7, "ptr", 0, "ptr", 0)   ; EM_SCROLLCARET
}

; Hotkeys για Log μέσα στο παράθυρο της app
#HotIf WinActive("YT Automation — Edge/Chryseis (CLEAN)")
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

    try {
        RunFlow()
    } catch as e {
        Log("Σφάλμα: " e.Message)
    }

    gRunning := false
    gPaused := false
    gStopRequested := false
    SetHeadline("Έτοιμο."), Log("Flow finished / stopped")
}

OnPauseResume() {
    global gRunning, gPaused, btnPause
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

; ===== Κύρια Ροή (ΚΑΘΑΡΗ) =====
RunFlow() {
    global EDGE_PROFILE_NAME
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

    ; 3) --- PLACE YOUR TASKS HERE ---
    ; Επιλογή Α (default): άνοιγμα ΜΙΑΣ νέας κενής καρτέλας και τέλος
    OpenNewTab(hNew)
    SetHeadline("Νέα καρτέλα ανοιχτή — καμία άλλη ενέργεια."), Log("Idle ready")

    ; 4) Κλείσιμο ΜΟΝΟ του νέου παραθύρου (ή αφαίρεσέ το αν θες να μείνει ανοιχτό)
    ; Αν ΘΕΣ να μείνει ανοιχτό, σχολίασε τις 2 επόμενες γραμμές.
    WinClose("ahk_id " hNew)
    WinWaitClose("ahk_id " hNew, , 5)
    SetHeadline("Κύκλος ολοκληρώθηκε."), Log("Cycle done")
}

; ===== Έλεγχοι Pause / Stop =====
CheckAbortOrPause() {
    global gPaused, gStopRequested
    while gPaused {
        Sleep(150)
    }
    if gStopRequested
        throw Error("Stopped by user")
}

; ===== Ελάχιστες βοηθητικές =====
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

OpenNewTab(hWnd) {
    SetHeadline("Άνοιγμα νέας καρτέλας…"), Log("NewTab (blank)")
    WinActivate("ahk_id " hWnd)
    WinWaitActive("ahk_id " hWnd, , 3)
    Send("^t")
    Sleep(250)
}

; ===== Helpers =====
DirExist_(path) => InStr(FileExist(path), "D") > 0
RegexEscape(str) => RegExReplace(str, "([\\.^$*+?()\\[\\]{}|])", "\\$1")