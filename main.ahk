; ==================== main_v2_status.ahk (AHK v2) ====================
#Requires AutoHotkey v2.0
#SingleInstance Force

SetTitleMatchMode(2)
SetWorkingDir(A_ScriptDir)

; ===== Ρυθμίσεις / Σταθερές =====
EDGE_WIN     := "Microsoft Edge"
; Προσαρμόστε αν χρειάζεται (x64 συνήθως είναι C:\Program Files\Microsoft\Edge\Application\msedge.exe)
EDGE_EXE     := "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
EDGE_PROFILE := '--profile-directory="Default"'

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

; ===== Status Panel (module) =====
class Status {
    static gui := ""
    static txt := ""
    static w := 380, h := 90       ; μέγεθος παραθύρου
    static margin := 12            ; απόσταση από άκρη οθόνης

    ; Δείξε panel (αν υπάρχει ήδη, απλά ενημερώνει)
    static Show(initialText := "Έναρξη…") {
        if (Status.gui != "") {
            Status.Update(initialText)
            return
        }
        ; +AlwaysOnTop: πάντα πάνω
        ; -Caption: χωρίς title bar
        ; +ToolWindow: μικρό/non-taskbar window
        ; +E0x08000000: WS_EX_NOACTIVATE (ΔΕΝ παίρνει focus)
        ; Προαιρετικό click-through: προσθέστε +E0x20 (WS_EX_TRANSPARENT)
        Status.gui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x08000000")
        ; --> Αν θες click-through, άλλαξε την προηγούμενη γραμμή σε:
        ; Status.gui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x08000000 +E0x20")

        Status.gui.BackColor := "0x101010"  ; σκούρο background
        f := Status.gui.Add("Text", "xm ym cWhite", initialText)
        f.SetFont("s10", "Segoe UI")
        Status.txt := f

        ; Τοποθέτηση: επάνω-δεξιά της κύριας περιοχής εργασίας
        left := top := right := bottom := 0
        MonitorGetWorkArea(1, &left, &top, &right, &bottom)  ; Πρωτεύουσα οθόνη
        x := right - Status.w - Status.margin
        y := top   + Status.margin

        Status.gui.Show(Format("x{} y{} w{} h{} NA", x, y, Status.w, Status.h))
        ; Ελαφριά διαφάνεια
        WinSetTransparent(230, Status.gui.Hwnd)
    }

    ; Ανανέωση κειμένου
    static Update(text) {
        if (Status.gui = "")
            Status.Show(text)
        else
            Status.txt.Value := text
    }

    ; Κλείσιμο
    static Close() {
        if (Status.gui != "") {
            Status.gui.Destroy()
            Status.gui := ""
            Status.txt := ""
        }
    }
}

; ===== Hotkeys =====
F9::Reload()  ; Restart script
F10::{
    Suspend(-1)                              ; Pause/Resume
    Status.Update(A_IsSuspended ? "⏸️ Παύση" : "▶️ Συνέχιση")
}
F12::{
    Status.Close()
    ExitApp()
}

; ===== Προβολή status με την εκκίνηση =====
Status.Show("Το script ξεκίνησε…")
Main()  ; Εκκίνηση κύριας ροής

; ==================== Ρουτίνες ====================
Main() {
    loop {
        Status.Update("Έναρξη κύκλου…")
        if !OpenEdge() {
            Status.Update("Αποτυχία ενεργοποίησης Edge. Επανάληψη σε 3 s…")
            Sleep(3000)
            continue
        }

        ; Καθαρή κατάσταση καρτελών
        Send("^1")
        Sleep(300)

        ; 1) Playlist ALL
        PlayPlaylist(URL_ALL, CNT_ALL, T_LONG, true)

        ; 2) Fixed videos
        PlayFixed(FIXED, T_SHORT)

        ; 3) Playlist GAMES
        PlayPlaylist(URL_GAMES, CNT_GAMES, T_MED, true)

        ; (Προαιρετικά) Shorts
        ; PlayPlaylist(URL_SHORTS, CNT_SHORTS, T_SHORT, false)

        WinClose(EDGE_WIN)
        Sleep(500)
        Status.Update("Κύκλος ολοκληρώθηκε. Νέος κύκλος σε 1 s…")
        Sleep(500)
    }
}

OpenEdge() {
    global EDGE_WIN, EDGE_EXE, EDGE_PROFILE
    Status.Update("Άνοιγμα/Ενεργοποίηση Edge…")

    if WinExist(EDGE_WIN) {
        WinActivate(EDGE_WIN)
        if !WinWaitActive(EDGE_WIN, , 3)
            return false
        WinMaximize(EDGE_WIN)
        Sleep(200)
        Status.Update("Edge έτοιμος.")
        return true
    }

    Run('"' EDGE_EXE '" ' EDGE_PROFILE)
    if !WinWait(EDGE_WIN, , 10)
        return false

    WinActivate(EDGE_WIN)
    if !WinWaitActive(EDGE_WIN, , 3)
        return false

    WinMaximize(EDGE_WIN)
    Sleep(300)
    Status.Update("Edge έτοιμος.")
    return true
}

GotoURL(url) {
    Status.Update("Μετάβαση σε URL…")
    Send("^l")           ; Focus address bar
    Sleep(150)
    SendText(url)        ; Ασφαλής εγγραφή
    Send("{Enter}")
    Sleep(1200)          ; Αρχική αναμονή φόρτωσης
}

WaitPlayable(timeoutSec := 10) {
    ; Placeholder για UI detection (ImageSearch/PixelSearch) αν χρειαστεί
    loop timeoutSec
        Sleep(1000)
}

PlayPlaylist(url, count, perItemSec, goNext := true) {
    Status.Update("Φόρτωση playlist…")
    GotoURL(url)
    WaitPlayable(8)
    Status.Update(Format("Playlist σε εξέλιξη ({} στοιχεία)…", count))
    loop count {
        Status.Update(Format("Playlist: στοιχείο {}/{} — αναμονή {} s", A_Index, count, perItemSec))
        TimerSleep(perItemSec)
        if goNext {
            Status.Update("Μετάβαση στο επόμενο (Shift+N)…")
            SendShiftN()
        }
    }
}

PlayFixed(arr, perItemSec) {
    idx := 0
    for , url in arr {
        idx++
        Status.Update(Format("Fixed βίντεο {}/{} — φόρτωση…", idx, arr.Length))
        GotoURL(url)
        WaitPlayable(5)
        Status.Update(Format("Fixed {}/{} — αναμονή {} s", idx, arr.Length, perItemSec))
        TimerSleep(perItemSec)
    }
}

TimerSleep(sec) {
    ; Διακριτικός μετρητής. Αν θες ορατό countdown, μπορείς να καλείς Status.Update ανά 5 s.
    loop sec
        Sleep(1000)
}

SendShiftN() {
    Send("+n")
    Sleep(200)
}
; ==================== End Of File ====================