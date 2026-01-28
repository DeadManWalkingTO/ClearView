; ==================== main_v2_status_profile.ahk (AHK v2) ====================
#Requires AutoHotkey v2.0
#SingleInstance Force

SetTitleMatchMode(2)
SetWorkingDir(A_ScriptDir)

; ===== Ρυθμίσεις / Σταθερές =====
; Στόχευση παραθύρων/διεργασίας με το εκτελέσιμο (σταθερό σε όλες τις γλώσσες/τίτλους)
EDGE_WIN     := "ahk_exe msedge.exe"
EDGE_PROC    := "msedge.exe"

; Προσαρμόστε αν χρειάζεται (x64 συνήθως: C:\Program Files\Microsoft\Edge\Application\msedge.exe)
EDGE_EXE     := "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"

; === Το εμφανιζόμενο όνομα προφίλ που ΘΕΛΟΥΜΕ (όπως φαίνεται στο Edge UI) ===
EDGE_PROFILE_NAME := "Chryseis"

; Playlists
URL_ALL      := "https://www.youtube.com/playlist?list=PL1TQ_pTmsiADD0QnjnvlfoRV3kDUaFtXc&playnext=1&autoplay=1"
URL_GAMES    := "https://www.youtube.com/playlist?list=PL1TQ_pTmsiAAz486-6cs7ds0EM5Ee8ssp&playnext=1&autoplay=1"
; Προαιρετικό Shorts (σχολιασμένο στο Main)
URL_SHORTS   := "https://www.youtube.com/playlist?list=PL1TQ_pTmsiADjbuLSuERlL9-gcV3FGFN2&playnext=1&autoplay=1"

; Fixed videos
FIXED := [
    "https://youtu.be/SHcfDzCJFMQ?autoplay=1",
    "https://youtu.be/V_1-7NvEQ8U?autoplay=1",
    "https://youtu.be/hRSXQtHdTzk?autoplay=1",
    "https://youtu.be/WVIlygtfWmk?autoplay=1"
]

; Χρόνοι (s)
T_SHORT := 60
T_MED   := 90
T_LONG  := 120

; Πλήθος στοιχείων ανά ροή
CNT_ALL   := 18
CNT_GAMES := 62
; CNT_SHORTS := 25

; ===== Status Panel (βελτιωμένο: headline + rolling log με throttle) =====
class Status {
    static gui := ""
    static txtHead := ""
    static txtLog := ""
    static w := 520, h := 240
    static margin := 12
    static shownOnce := false
    static _buf := []           ; buffer pending UI updates (throttled)
    static _log := []           ; rolling log lines
    static _logMax := 200       ; max lines to keep
    static _timerOn := false

    ; Δημιουργία/προβολή (ή επαναφορά)
    static Show(initialText := "Έναρξη…") {
        if (Status.gui = "") {
            Status.gui := Gui("+AlwaysOnTop -Caption +ToolWindow +DPIScale +E0x08000000")
            Status.gui.BackColor := "0x101010"
            Status.gui.SetFont("s10", "Consolas")

            ; Headline (λευκό, έντονο)
            Status.txtHead := Status.gui.Add("Text", "xm ym w" (Status.w - 2*Status.margin) " cWhite", initialText)
            Status.txtHead.SetFont("s10 bold", "Consolas")

            ; Log: Edit ReadOnly + Vertical Scroll
            Status.txtLog := Status.gui.Add(
                "Edit"
              , "xm y+8 w" (Status.w - 2*Status.margin) " h" (Status.h - 64) " ReadOnly Multi -Wrap +VScroll cSilver"
              , "")

            ; Πρώτη εμφάνιση: κέντρο οθόνης (σίγουρη ορατότητα)
            if !Status.shownOnce {
                x := (A_ScreenWidth  - Status.w) // 2
                y := (A_ScreenHeight - Status.h) // 2
                Status.gui.Show(Format("x{} y{} w{} h{} NA", x, y, Status.w, Status.h))
                Status.shownOnce := true
            } else {
                left := top := right := bottom := 0
                MonitorGetWorkArea(1, &left, &top, &right, &bottom)
                x := right - Status.w - Status.margin
                y := top   + Status.margin
                Status.gui.Show(Format("x{} y{} w{} h{} NA", x, y, Status.w, Status.h))
            }

            ; Ελαφρύ “σπρώξιμο” στο top‑most layer
            WinSetAlwaysOnTop(false, "ahk_id " Status.gui.Hwnd)
            WinSetAlwaysOnTop(true , "ahk_id " Status.gui.Hwnd)

            ; Προσαρμογή διάταξης αν αλλάξει μέγεθος (μελλοντικά)
            Status.gui.OnEvent("Size", (*) => Status._Reflow())
        } else {
            Status.BringToFront()
        }
        Status.Set(initialText)
    }

    ; Θέτει τη γραμμή κατάστασης (headline)
    static Set(text) {
        if (Status.gui = "") {
            Status.Show(text)
            return
        }
        Status.txtHead.Value := text
    }

    ; Alias για συμβατότητα με παλαιότερες κλήσεις
    static Update(text) => Status.Set(text)

    ; Προσθέτει γραμμή στο rolling log
    static Log(text) {
        ts := FormatTime(A_Now, "HH:mm:ss")
        line := "[" ts "] " text
        Status._log.Push(line)
        while (Status._log.Length > Status._logMax)
            Status._log.RemoveAt(1)

        ; Buffer για UI (throttle)
        Status._buf.Push(1)
        if !Status._timerOn {
            ; FIX: έγκυρο callback (lambda)
            SetTimer(() => Status._FlushUI(), -250)
            Status._timerOn := true
        }
    }

    ; Καθαρισμός log
    static Clear() {
        Status._log := []
        Status._buf := []
        if (Status.txtLog != "")
            Status.txtLog.Value := ""
    }

    ; Εναλλαγή εμφάνισης/επαναφορά μπροστά
    static Toggle() {
        if (Status.gui = "")
            return Status.Show()
        if Status.gui.Visible {
            Status.gui.Hide()
        } else {
            Status.BringToFront()
            Status.gui.Show("NA")
        }
    }

    ; Φέρ’ το πάνω (χωρίς focus)
    static BringToFront() {
        if (Status.gui = "")
            return
        WinSetAlwaysOnTop(false, "ahk_id " Status.gui.Hwnd)
        WinSetAlwaysOnTop(true , "ahk_id " Status.gui.Hwnd)
    }

    ; Κλείσιμο
    static Close() {
        if (Status.gui != "") {
            Status.gui.Destroy()
            Status.gui := ""
            Status.txtHead := ""
            Status.txtLog := ""
            Status._buf := []
            Status._log := []
            Status._timerOn := false
            Status.shownOnce := false
        }
    }

    ; Εφαρμόζει pending ενημερώσεις στο UI (throttled) χωρίς να αλλάζει focus
    static _FlushUI() {
        Status._timerOn := false
        if (Status.gui = "" || Status.txtLog = "")
            return
        if (Status._buf.Length) {
            Status._buf := []
            Status.txtLog.Value := JoinLines(Status._log, "`r`n")
            ; Scroll-to-bottom με μηνύματα (χωρίς focus)
            hwnd := Status.txtLog.Hwnd
            ; EM_SETSEL (0xB1) με -1,-1 -> caret στο τέλος
            DllCall("user32\SendMessage", "ptr", hwnd, "uint", 0xB1, "ptr", -1, "ptr", -1)
            ; EM_SCROLLCARET (0xB7)
            DllCall("user32\SendMessage", "ptr", hwnd, "uint", 0xB7, "ptr", 0, "ptr", 0)
        }
    }

    ; Αναδιάταξη controls όταν αλλάζει μέγεθος (για μελλοντικά draggable panel)
    static _Reflow() {
        try {
            Status.txtHead.Move(, , Status.w - 2*Status.margin)
            Status.txtLog.Move(, , Status.w - 2*Status.margin, Status.h - 64)
        }
    }
}

; ===== Hotkeys =====
F8::Status.Toggle()   ; Show/Hide/Bring-to-front του panel
F9::Reload()          ; Restart script
F10::{
    Suspend(-1)       ; Pause/Resume
    Status.Set(A_IsSuspended ? "⏸️ Παύση" : "▶️ Συνέχιση")
    Status.Log(A_IsSuspended ? "Paused" : "Resumed")
}
F12::{
    Status.Log("Exit requested")
    Status.Close()
    ExitApp()
}

; Προαιρετικά: Clear/Save log
^+l::Status.Clear()   ; Ctrl+Shift+L: καθάρισε το log
^+s::{                ; Ctrl+Shift+S: αποθήκευση log σε αρχείο
    if !DirExist("logs")
        DirCreate("logs")
    fn := Format("logs\status_{:04}{:02}{:02}_{:02}{:02}{:02}.txt"
        , A_YYYY, A_MM, A_DD, A_Hour, A_Min, A_Sec)
    FileAppend(JoinLines(Status._log, "`r`n"), fn, "UTF-8")
    Status.Set("Log saved → " fn), Status.Log("Log saved → " fn)
}

; ===== Εκκίνηση =====
Status.Show("Το script ξεκίνησε…")
Status.Log("Bootstrap")
Main()

; ==================== Ρουτίνες ====================
Main() {
    global EDGE_PROFILE_NAME
    ; 1) Επίλυση φακέλου προφίλ από εμφανιζόμενο όνομα (π.χ. Chryseis → Profile 3)
    Status.Set("Εύρεση φακέλου προφίλ…"), Status.Log("Resolve profile by display name: " EDGE_PROFILE_NAME)
    profDir := ResolveEdgeProfileDirByName(EDGE_PROFILE_NAME)
    if (profDir = "") {
        Status.Set("⚠️ Δεν βρέθηκε φάκελος για: " EDGE_PROFILE_NAME), Status.Log("Profile dir NOT found; will try as-is")
        profArg := '--profile-directory="' EDGE_PROFILE_NAME '"'
    } else {
        Status.Set("Βρέθηκε φάκελος: " profDir), Status.Log("Profile dir: " profDir)
        profArg := '--profile-directory="' profDir '"'
    }
    ; ΠΑΝΤΑ νέο παράθυρο αυτού του προφίλ (ανεξάρτητα από άλλον Edge)
    profArg .= " --new-window"

    loop {
        Status.Set("Άνοιγμα νέου παραθύρου Edge…"), Status.Log("OpenEdgeNewWindow")
        hNew := OpenEdgeNewWindow(profArg)
        if (!hNew) {
            Status.Set("Αποτυχία ανοίγματος Edge. Retry σε 3 s…"), Status.Log("OpenEdgeNewWindow failed; sleep 3s")
            Sleep(3000)
            continue
        }
        WinActivate("ahk_id " hNew)
        WinWaitActive("ahk_id " hNew, , 5)
        WinMaximize("ahk_id " hNew)
        Sleep(200)
        Status.Set("Edge έτοιμος (" EDGE_PROFILE_NAME ")"), Status.Log("Edge ready")

        ; === Κάθε ροή σε ΝΕΑ καρτέλα ===
        NewTab(hNew), Status.Log("NewTab: ALL"),   PlayPlaylist(URL_ALL,   CNT_ALL,   T_LONG, true)
        NewTab(hNew), Status.Log("NewTab: FIXED"), PlayFixed(FIXED,        T_SHORT)
        NewTab(hNew), Status.Log("NewTab: GAMES"), PlayPlaylist(URL_GAMES, CNT_GAMES, T_MED,  true)
        ; Προαιρετικά:
        ; NewTab(hNew), Status.Log("NewTab: SHORTS"), PlayPlaylist(URL_SHORTS, CNT_SHORTS, T_SHORT, false)

        ; Κλείσε ΜΟΝΟ το νέο παράθυρο (όχι όλο τον Edge)
        WinClose("ahk_id " hNew)
        WinWaitClose("ahk_id " hNew, , 5)
        Status.Set("Κύκλος ολοκληρώθηκε. Νέος κύκλος σε 1 s…"), Status.Log("Cycle done")
        Sleep(1000)
    }
}

; --- Εντοπίζει τον φάκελο προφίλ με βάση το εμφανιζόμενο όνομα (π.χ. "Chryseis") ---
ResolveEdgeProfileDirByName(displayName) {
    base := EnvGet("LOCALAPPDATA") "\Microsoft\Edge\User Data\"
    if !DirExist_(base)
        return ""

    candidates := ["Default"]
    ; Πρόσθεσε όλους τους φακέλους τύπου "Profile <number>"
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

        ; Ψάξε το εμφανιζόμενο όνομα στο JSON του Preferences
        if RegExMatch(txt, '"profile"\s*:\s*\{[^}]*"name"\s*:\s*"' esc '"')
            return cand
        if RegExMatch(txt, '"name"\s*:\s*"' esc '"')
            return cand
    }
    return ""
}

; --- Άνοιγμα ΝΕΟΥ παραθύρου Edge για δεδομένο προφίλ, επιστρέφει hWnd του ΝΕΟΥ παραθύρου ---
OpenEdgeNewWindow(profileArg) {
    global EDGE_EXE, EDGE_WIN
    ; Λίστα παραθύρων ΠΡΙΝ
    before := WinGetList(EDGE_WIN)

    ; Εκτέλεση (ανοίγουμε ΝΕΟ παράθυρο, ανεξάρτητα αν τρέχει Edge)
    try Run('"' EDGE_EXE '" ' profileArg)
    catch {
        return 0
    }

    ; Εντόπισε το ΝΕΟ παράθυρο ως διαφορά λίστας
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

; --- Βρίσκει ποιο hWnd εμφανίστηκε στη δεύτερη λίστα και δεν υπήρχε στην πρώτη ---
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

; === Άνοιγμα νέας καρτέλας στο ΣΥΓΚΕΚΡΙΜΕΝΟ παράθυρο ===
NewTab(hWnd) {
    Status.Set("Άνοιγμα νέας καρτέλας…")
    WinActivate("ahk_id " hWnd)
    WinWaitActive("ahk_id " hWnd, , 3)
    Send("^t")
    Sleep(250)
}

GotoURL(url) {
    Status.Set("Μετάβαση σε URL…"), Status.Log(url)
    Send("^l")
    Sleep(150)
    SendText(url)
    Send("{Enter}")
    Sleep(1200)
}

WaitPlayable(timeoutSec := 10) {
    loop timeoutSec
        Sleep(1000)
}

PlayPlaylist(url, count, perItemSec, goNext := true) {
    Status.Set("Φόρτωση playlist…"), Status.Log("Playlist URL: " url)
    GotoURL(url)
    WaitPlayable(8)
    Status.Set(Format("Playlist σε εξέλιξη ({} στοιχεία)…", count)), Status.Log("Playlist begin (" count ")")
    loop count {
        Status.Set(Format("Playlist: στοιχείο {}/{} — αναμονή {} s", A_Index, count, perItemSec))
        Status.Log(Format("Item {}/{} start", A_Index, count))
        TimerSleep(perItemSec)
        if goNext {
            Status.Set("Μετάβαση στο επόμενο (Shift+N)…")
            SendShiftN()
            Status.Log(Format("Item {}/{} next", A_Index, count))
        }
    }
}

PlayFixed(arr, perItemSec) {
    idx := 0
    for , url in arr {
        idx++
        Status.Set(Format("Fixed βίντεο {}/{} — φόρτωση…", idx, arr.Length))
        Status.Log("Fixed URL: " url)
        GotoURL(url)
        WaitPlayable(5)
        Status.Set(Format("Fixed {}/{} — αναμονή {} s", idx, arr.Length, perItemSec))
        Status.Log(Format("Fixed {}/{} start", idx, arr.Length))
        TimerSleep(perItemSec)
    }
}

TimerSleep(sec) {
    loop sec
        Sleep(1000)
}

SendShiftN() {
    Send("+n")
    Sleep(200)
}

; ===== Helpers =====
DirExist_(path) {
    ; Επιστρέφει true αν υπάρχει directory
    return InStr(FileExist(path), "D") > 0
}

RegexEscape(str) {
    ; Escape των regex metacharacters
    return RegExReplace(str, "([\\.^$*+?()\\[\\]{}|])", "\\$1")
}

JoinLines(arr, sep := "`r`n") {
    ; Επιστρέφει ενιαίο string από array στοιχείων με διαχωριστικό `sep`
    out := ""
    for i, v in arr {
        if (i > 1)
            out .= sep
        out .= v
    }
    return out
}
; ==================== End Of File ====================