; ==================== main_v2_app_clean.ahk (AHK v2) ====================
#Requires AutoHotkey v2.0
#SingleInstance Force

SetTitleMatchMode(2)
SetWorkingDir(A_ScriptDir)

; ===== Μεταδεδομένα εφαρμογής =====
APP_TITLE   := "BH Automation — Edge/Chryseis"
APP_VERSION := "v1.0.20"         ; bump: default log icon ▪️ (emoji presentation) for stable width across lines

; ===== Ρυθμίσεις / Επιλογές =====
EDGE_WIN     := "ahk_exe msedge.exe"
EDGE_PROC    := "msedge.exe"
; Αν έχεις 64-bit Edge, άλλαξε διαδρομή:
EDGE_EXE     := "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
EDGE_PROFILE_NAME := "Chryseis"

; (Προαιρετικά) Αν ξέρεις ακριβώς τον φάκελο (π.χ. "Profile 3"), βάλε τιμή εδώ για να παρακαμφθεί η ανίχνευση:
PROFILE_DIR_FORCE := ""   ; π.χ. "Profile 3"  ("" = απενεργοποιημένο)

; Να παραμένει ανοιχτό το νέο παράθυρο Edge στο τέλος;
KEEP_EDGE_OPEN := true

; Καθολικό timeout για ενημερωτικά popups (σε δευτ.)
POPUP_T := 3

; ===== Κατάσταση Εκτέλεσης =====
gRunning := false
gPaused := false
gStopRequested := false

; ===== GUI Εφαρμογής =====
App := Gui("+AlwaysOnTop +Resize", APP_TITLE " — " APP_VERSION)
App.SetFont("s10", "Segoe UI")

; Γραμμή κουμπιών (Start/Pause/Stop + Copy/Clear)
btnStart := App.Add("Button", "xm ym w90 h28", "Start")
btnPause := App.Add("Button", "x+8 yp w110 h28", "Pause")
btnStop  := App.Add("Button", "x+8 yp w90 h28",  "Stop")
btnCopy  := App.Add("Button", "x+24 yp w110 h28", "Copy Logs")
btnClear := App.Add("Button", "x+8 yp w110 h28", "Clear Logs")

; Headline & Log (νεότερα επάνω)
txtHead := App.Add("Text", "xm y+10 w760 h24 cBlue", "Έτοιμο. " APP_VERSION)
txtLog  := App.Add("Edit", "xm y+6 w860 h360 ReadOnly Multi -Wrap +VScroll", "")

; Γραμμή βοήθειας
helpLine := App.Add("Text", "xm y+6 cGray"
  , "Ctrl+Shift+L: Clear log    Ctrl+Shift+S: Save log    Ctrl+Shift+A: About")

; Προσαρμογή layout σε resize
App.OnEvent("Size", (*) => GuiReflow())

; Events
btnStart.OnEvent("Click", (*) => OnStart())
btnPause.OnEvent("Click", (*) => OnPauseResume())
btnStop .OnEvent("Click", (*) => OnStop())
btnCopy .OnEvent("Click", (*) => OnCopyLogs())
btnClear.OnEvent("Click", (*) => OnClearLogs())

; Εμφάνιση GUI
App.Show("w900 h560 Center")
; Αρχική γραμμή στο log (χωρίς τίτλο/έκδοση, μόνο μήνυμα)
Log("Εφαρμογή ξεκίνησε.")

; ===== GUI Helpers =====
GuiReflow() {
    global App, btnStart, btnPause, btnStop, btnCopy, btnClear, txtHead, txtLog, helpLine
    App.GetPos(, , &W, &H)
    margin := 12

    ; Κουμπιά (σε μία σειρά)
    btnStart.Move(margin, margin, 90, 28)
    btnPause.Move(margin + 90 + 8, margin, 110, 28)
    btnStop .Move(margin + 90 + 8 + 110 + 8, margin, 90, 28)
    btnCopy .Move(W - margin - 110 - 8 - 110, margin, 110, 28)
    btnClear.Move(W - margin - 110,           margin, 110, 28)

    txtHead.Move(margin, margin + 28 + 10, W - 2*margin, 24)

    topLog := margin + 28 + 10 + 24 + 6
    helpLine.Move(margin, H - margin - 20, W - 2*margin, 20)
    txtLog.Move(margin, topLog, W - 2*margin, (H - topLog - margin - 24) - 24)
}

SetHeadline(text) {
    global txtHead, APP_VERSION
    txtHead.Value := text "  —  " APP_VERSION
}

; ===== Utilities: Title Case & Log =====
JoinTokens(arr, sep := " ") {
    out := ""
    for i, v in arr {
        if (i > 1)
            out .= sep
        out .= v
    }
    return out
}

; Single-line Title Case (με προστασία του suffix (T=3s))
ToTitleCase(text) {
    ; Normalize spaces
    t := StrReplace(text, "`r", " ")
    t := StrReplace(t,    "`n", " ")
    t := StrReplace(t,    "`t", " ")
    t := RegExReplace(t,  "\s+", " ")
    t := Trim(t)

    ; Προστασία "(T=3s)" για να μην αλλοιωθεί
    t := StrReplace(t, "(T=3s)", "__TIME_SUFFIX__")

    parts := StrSplit(t, " ")
    outParts := []
    for _, p in parts {
        if (p = "")
            continue
        first := SubStr(p, 1, 1)
        rest  := SubStr(p, 2)
        outParts.Push(StrUpper(first) rest)
    }
    tc := JoinTokens(outParts, " ")

    tc := StrReplace(tc, "__TIME_SUFFIX__", "(T=3s)")
    return tc
}

; Επιλογή Unicode icon ανά κατηγορία μηνύματος (input: Title Case string)
GetLogIconUnicode(msgTitleCase) {
    ; Σημ.: χρησιμοποιούμε emoji presentation (όπου χρειάζεται) για συνεπές πλάτος.
    if InStr(msgTitleCase, "Popup:")
        return "ℹ️"    ; information
    if InStr(msgTitleCase, "Profile Warn")
        return "⚠️"    ; warning
    if InStr(msgTitleCase, "Open Edge New Window")
        return "⏩"    ; fast-forward
    if InStr(msgTitleCase, "New Tab")
        return "➡️"    ; arrow forward
    if InStr(msgTitleCase, "Edge Ready")
        return "✅"    ; check mark
    if InStr(msgTitleCase, "Cycle Done")
        return "✨"    ; sparkles
    if InStr(msgTitleCase, "Paused")
        return "⏸️"    ; pause
    if InStr(msgTitleCase, "Stop Requested")
        return "❌"    ; cross mark
    if InStr(msgTitleCase, "Start Pressed") || InStr(msgTitleCase, "Resumed")
        return "▶️"    ; play
    ; Προεπιλογή: μικρό μαύρο τετράγωνο **με VS16** για ίδια εμφάνιση/πλάτος
    return "▪️"
}

; Reverse-chronological Log (νεότερα επάνω), Title Case, single-line, με Unicode icon μετά την ώρα
Log(text) {
    global txtLog
    tc := ToTitleCase(text)
    icon := GetLogIconUnicode(tc)
    ts := FormatTime(A_Now, "HH:mm:ss")
    newLine := "[" ts "] " icon " " tc

    cur := txtLog.Value
    if (cur != "")
        txtLog.Value := newLine "`r`n" cur
    else
        txtLog.Value := newLine

    ; caret top
    hwnd := txtLog.Hwnd
    DllCall("user32\SendMessage", "ptr", hwnd, "uint", 0xB1, "ptr", 0, "ptr", 0) ; EM_SETSEL(0,0)
    DllCall("user32\SendMessage", "ptr", hwnd, "uint", 0xB7, "ptr", 0, "ptr", 0) ; EM_SCROLLCARET
}

; Timed popup + log "(T=3s)"
; Μορφή στο log: "Popup: <Kind> (T=3s)" (θα πάρει Unicode icon από Log()).
ShowTimedMsg(kind, text, title, icon := "Iconi") {
    global POPUP_T
    Log(Format("Popup: {} (T={}s)", kind, POPUP_T))
    opt := icon " T" POPUP_T
    MsgBox(text, title, opt)
}

; ===== Hotkeys =====
#HotIf WinActive(APP_TITLE " — " APP_VERSION)
^+l::OnClearLogs()
^+s::{
    if !DirExist("logs")
        DirCreate("logs")
    fn := Format("logs\status_{:04}{:02}{:02}_{:02}{:02}{:02}.txt"
        , A_YYYY, A_MM, A_DD, A_Hour, A_Min, A_Sec)
    FileAppend(txtLog.Value, fn, "UTF-8")
    SetHeadline("Log saved → " fn), Log("Log saved → " fn)
}
^+a::ShowAbout()
#HotIf

ShowAbout() {
    global APP_TITLE, APP_VERSION, EDGE_EXE, EDGE_PROFILE_NAME, KEEP_EDGE_OPEN
    MsgBox( APP_TITLE " — " APP_VERSION "`n"
          . "Profile (display): " EDGE_PROFILE_NAME "`n"
          . "Edge path: " EDGE_EXE "`n"
          . "Keep window open: " (KEEP_EDGE_OPEN ? "Yes" : "No")
          , "About", "Iconi")
    Log(Format("About shown — {} {}", APP_TITLE, APP_VERSION))
}

OnCopyLogs() {
    global txtLog
    A_Clipboard := txtLog.Value
    Log("Logs copied to clipboard")
    SetHeadline("Logs copied to clipboard")
}

OnClearLogs() {
    global txtLog
    txtLog.Value := ""
    SetHeadline("Log καθαρίστηκε.")
    Log("Log cleared by user (button)")
}

; ===== Χειριστές Κουμπιών =====
OnStart() {
    global gRunning, gPaused, gStopRequested, APP_VERSION
    if gRunning {
        SetHeadline("Ήδη εκτελείται.")
        Log("Start pressed while already running — ignored")
        return
    }
    gRunning := true
    gPaused := false
    gStopRequested := false

    ; Start popup + log (T=3s)
    msg := Format("Ξεκινάει Η Ροή Αυτοματισμού — Έκδοση: {}", APP_VERSION)
    ShowTimedMsg("Start", msg, "BH Automation — Start", "Iconi")

    SetHeadline("Εκκίνηση ροής…"), Log("Start pressed — " APP_VERSION)

    try {
        RunFlow()
    } catch as e {
        Log("Σφάλμα: " e.Message)
        SetHeadline("Σφάλμα: " e.Message)
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
        Log("Pause/Resume clicked while not running — ignored")
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
        Log("Stop clicked while not running — ignored")
        return
    }
    gStopRequested := true
    SetHeadline("Τερματισμός…"), Log("Stop requested")
}

; ===== Κύρια Ροή (CLEAN) =====
RunFlow() {
    global EDGE_PROFILE_NAME, PROFILE_DIR_FORCE, KEEP_EDGE_OPEN
    ; 0) Αν έχεις “καρφωμένο” φάκελο, χρησιμοποίησέ τον
    if (PROFILE_DIR_FORCE != "") {
        profDir := PROFILE_DIR_FORCE
        Log("Profile dir (forced): " profDir)
    } else {
        ; 1) Βρες φάκελο προφίλ από display name — πρώτα μέσω Local State, μετά Preferences
        SetHeadline("Εύρεση φακέλου προφίλ…"), Log("Resolve profile by name: " EDGE_PROFILE_NAME)
        profDir := ResolveEdgeProfileDirByName(EDGE_PROFILE_NAME)
    }

    if (profDir = "") {
        SetHeadline("⚠️ Δεν βρέθηκε φάκελος για: " EDGE_PROFILE_NAME)
        Log("Profile dir NOT found; try as-is (using display name as folder)")
        profArg := '--profile-directory="' EDGE_PROFILE_NAME '"'
        warnMsg := Format('Δεν βρέθηκε φάκελος προφίλ για "{}". Θα δοκιμάσω με: {}', EDGE_PROFILE_NAME, profArg)
        ShowTimedMsg("ProfileWarn", warnMsg, "BH Automation — Προειδοποίηση", "Icon!")
    } else {
        SetHeadline("Βρέθηκε: " profDir), Log("Profile dir: " profDir)
        profArg := '--profile-directory="' profDir '"'
    }
    profArg .= " --new-window"

    ; 2) Άνοιξε ΝΕΟ παράθυρο Edge στο προφίλ
    CheckAbortOrPause()
    Log("Open Edge New Window: " profArg)
    hNew := OpenEdgeNewWindow(profArg)
    if (!hNew) {
        SetHeadline("❌ Αποτυχία ανοίγματος Edge."), Log("Open Edge New Window Failed")
        return
    }
    WinActivate("ahk_id " hNew)
    WinWaitActive("ahk_id " hNew, , 5)
    WinMaximize("ahk_id " hNew)
    Sleep(200)
    SetHeadline("Edge έτοιμος (" EDGE_PROFILE_NAME ")"), Log("Edge ready")

    ; Edge-ready popup (T=3s)
    readyMsg := Format('Edge Ready ("{}").', EDGE_PROFILE_NAME)
    ShowTimedMsg("EdgeReady", readyMsg, "BH Automation — Edge", "Iconi")

    ; 3) --- PLACE YOUR TASKS HERE ---
    SetHeadline("Άνοιγμα νέας καρτέλας…"), Log("New Tab (Blank)")
    WinActivate("ahk_id " hNew)
    WinWaitActive("ahk_id " hNew, , 3)
    Send("^t")
    Sleep(250)
    SetHeadline("Νέα καρτέλα ανοιχτή — καμία άλλη ενέργεια."), Log("Idle ready")

    ; 4) Κλείσιμο ή διατήρηση νέου παραθύρου
    if (!KEEP_EDGE_OPEN) {
        WinClose("ahk_id " hNew)
        WinWaitClose("ahk_id " hNew, , 5)
        SetHeadline("Κύκλος ολοκληρώθηκε."), Log("Cycle done")
    } else {
        SetHeadline("Κύκλος ολοκληρώθηκε (Edge παραμένει ανοιχτός).")
        Log("Cycle done (Keep window open)")
    }
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

; ===== Βοηθητικές: Profile Resolve =====
ResolveEdgeProfileDirByName(displayName) {
    base := EnvGet("LOCALAPPDATA") "\Microsoft\Edge\User Data\"
    if !DirExist_(base)
        return ""

    esc := RegexEscape(displayName)

    ; 1) Δοκίμασε "Local State"
    localState := base "Local State"
    if FileExist(localState) {
        txt := ""
        try {
            txt := FileRead(localState, "UTF-8")
        } catch as e {
            txt := ""
        }
        if (txt != "") {
            pat := '"profile"\s*:\s*\{\s*"info_cache"\s*:\s*\{([\s\S]*?)\}\s*\}'
            if RegExMatch(txt, pat, &m) {
                cache := m[1]
                pos := 1
                while RegExMatch(cache, '"([^"]+)"\s*:\s*\{[^}]*"name"\s*:\s*"([^"]+)"', &mm, pos) {
                    dir := mm[1], nm := mm[2]
                    if (nm = displayName)
                        return dir
                    pos := mm.Pos(0) + mm.Len(0)
                }
            }
        }
    }

    ; 2) Fallback: Preferences ανά προφίλ
    candidates := ["Default"]
    Loop Files, base "*", "D" {
        d := A_LoopFileName
        if RegExMatch(d, "^Profile\s+\d+$")
            candidates.Push(d)
    }
    for _, cand in candidates {
        pref := base cand "\Preferences"
        if !FileExist(pref)
            continue
        txt2 := ""
        try {
            txt2 := FileRead(pref, "UTF-8")
        } catch as e {
            txt2 := ""
        }
        if (txt2 = "")
            continue
        if RegExMatch(txt2, '"profile"\s*:\s*\{[^}]*"name"\s*:\s*"' esc '"')
            return cand
        if RegExMatch(txt2, '"name"\s*:\s*"' esc '"')
            return cand
    }
    return ""
}

; ===== Edge Window Handling =====
OpenEdgeNewWindow(profileArg) {
    global EDGE_EXE, EDGE_WIN
    before := WinGetList(EDGE_WIN)
    try {
        Run('"' EDGE_EXE '" ' profileArg)
    } catch as e {
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

; ===== Helpers =====
DirExist_(path) {
    return InStr(FileExist(path), "D") > 0
}
RegexEscape(str) {
    return RegExReplace(str, "([\\.^$*+?()\\[\\]{}|])", "\\$1")
}
; ==================== End Of File ====================