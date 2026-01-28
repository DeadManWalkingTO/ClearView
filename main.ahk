; ==================== main_v2_app_clean.ahk (AHK v2) ====================
#Requires AutoHotkey v2.0
#SingleInstance Force

SetTitleMatchMode(2)
SetWorkingDir(A_ScriptDir)

; ===== Μεταδεδομένα εφαρμογής =====
APP_TITLE   := "BH Automation — Edge/Chryseis"
APP_VERSION := "v1.0.7"          ; bump: fix catch blocks + robust Local State reading

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

; ===== Κατάσταση Εκτέλεσης =====
gRunning := false
gPaused := false
gStopRequested := false

; ===== GUI Εφαρμογής =====
App := Gui("+AlwaysOnTop +Resize", APP_TITLE " — " APP_VERSION)
App.SetFont("s10", "Segoe UI")

; Γραμμή κουμπιών
btnStart := App.Add("Button", "xm ym w90 h28", "Start")
btnPause := App.Add("Button", "x+8 yp w110 h28", "Pause")
btnStop  := App.Add("Button", "x+8 yp w90 h28",  "Stop")

; Headline & Log (νεότερα επάνω)
txtHead := App.Add("Text", "xm y+10 w760 h24 cBlue", "Έτοιμο. " APP_VERSION)
txtLog  := App.Add("Edit", "xm y+6 w760 h360 ReadOnly Multi -Wrap +VScroll"
                  , "[Log] " APP_TITLE " — " APP_VERSION)

; Γραμμή βοήθειας
helpLine := App.Add("Text", "xm y+6 cGray"
  , "Ctrl+Shift+L: Clear log    Ctrl+Shift+S: Save log    Ctrl+Shift+A: About")

; Προσαρμογή layout σε resize
App.OnEvent("Size", (*) => GuiReflow())

; Events
btnStart.OnEvent("Click", (*) => OnStart())
btnPause.OnEvent("Click", (*) => OnPauseResume())
btnStop.OnEvent("Click",  (*) => OnStop())

; Εμφάνιση GUI
App.Show("w800 h560 Center")
Log("Εφαρμογή ξεκίνησε (clean). " APP_TITLE " — " APP_VERSION)

; ===== GUI Helpers =====
GuiReflow() {
    global App, btnStart, btnPause, btnStop, txtHead, txtLog, helpLine
    App.GetPos(, , &W, &H)
    margin := 12
    btnStart.Move(margin, margin, 90, 28)
    btnPause.Move(margin + 90 + 8, margin, 110, 28)
    btnStop.Move(margin + 90 + 8 + 110 + 8, margin, 90, 28)

    txtHead.Move(margin, margin + 28 + 10, W - 2*margin, 24)

    topLog := margin + 28 + 10 + 24 + 6
    helpLine.Move(margin, H - margin - 20, W - 2*margin, 20)
    txtLog.Move(margin, topLog, W - 2*margin, (H - topLog - margin - 24) - 24)
}

SetHeadline(text) {
    global txtHead, APP_VERSION
    txtHead.Value := text "  —  " APP_VERSION
}

; ===== Reverse-chronological Log (νεότερα επάνω) =====
Log(text) {
    global txtLog
    ts := FormatTime(A_Now, "HH:mm:ss")
    newLine := "[" ts "] " text
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

; Hotkeys για Log/Info μέσα στο παράθυρο της app
#HotIf WinActive(APP_TITLE " — " APP_VERSION)
^+l::{
    txtLog.Value := ""
    SetHeadline("Log καθαρίστηκε.")
    Log("Log cleared by user")
}
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

    ; Start popup + log (3s)
    msg := Format("Ξεκινάει η ροή αυτοματισμού.`nΈκδοση: {}", APP_VERSION)
    Log("Popup(Start): " msg)
    MsgBox(msg, "BH Automation — Start", "Iconi T3")

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
        warnMsg := Format('Δεν βρέθηκε φάκελος προφίλ για "{}".`nΘα δοκιμάσω με: {}', EDGE_PROFILE_NAME, profArg)
        Log("Popup(ProfileWarn): " warnMsg)
        MsgBox(warnMsg, "BH Automation — Προειδοποίηση", "Icon! T3")
    } else {
        SetHeadline("Βρέθηκε: " profDir), Log("Profile dir: " profDir)
        profArg := '--profile-directory="' profDir '"'
    }
    profArg .= " --new-window"

    ; 2) Άνοιξε ΝΕΟ παράθυρο Edge στο προφίλ
    CheckAbortOrPause()
    SetHeadline("Άνοιγμα νέου παραθύρου Edge…"), Log("OpenEdgeNewWindow: " profArg)
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

    ; Edge-ready popup + log (3s)
    readyMsg := Format('Edge ready ("{}").', EDGE_PROFILE_NAME)
    Log("Popup(EdgeReady): " readyMsg)
    MsgBox(readyMsg, "BH Automation — Edge", "Iconi T3")

    ; 3) --- PLACE YOUR TASKS HERE ---
    OpenNewTab(hNew)
    SetHeadline("Νέα καρτέλα ανοιχτή — καμία άλλη ενέργεια."), Log("Idle ready")

    ; 4) Κλείσιμο ή διατήρηση νέου παραθύρου
    if (!KEEP_EDGE_OPEN) {
        WinClose("ahk_id " hNew)
        WinWaitClose("ahk_id " hNew, , 5)
        SetHeadline("Κύκλος ολοκληρώθηκε."), Log("Cycle done")
    } else {
        SetHeadline("Κύκλος ολοκληρώθηκε (Edge παραμένει ανοιχτός).")
        Log("Cycle done (keep window open)")
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
; Προσπαθεί πρώτα από το "Local State" (profile.info_cache), μετά fallback διασχίζοντας "Preferences" ανά προφίλ.
ResolveEdgeProfileDirByName(displayName) {
    base := EnvGet("LOCALAPPDATA") "\Microsoft\Edge\User Data\"
    if !DirExist_(base)
        return ""

    esc := RegexEscape(displayName)

    ; 1) Δοκίμασε "Local State" (περιέχει χαρτογράφηση προφίλ → όνομα)
    localState := base "Local State"
    if FileExist(localState) {
        txt := ""
        try {
            txt := FileRead(localState, "UTF-8")
        } catch as e {
            txt := ""
        }
        if (txt != "") {
            ; pattern για να απομονώσουμε το μπλοκ info_cache
            pat := '"profile"\s*:\s*\{\s*"info_cache"\s*:\s*\{([\s\S]*?)\}\s*\}'
            if RegExMatch(txt, pat, &m) {
                cache := m[1]
                ; Βρες εγγραφές "dir":{"name":"..."}
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

    ; 2) Fallback: σάρωση φακέλων "Default" + "Profile *" και έλεγχος "Preferences"
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
; ==================== End Of File ====================