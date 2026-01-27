; ==================== main_v2.ahk (AHK v2) ====================
#Requires AutoHotkey v2.0
#SingleInstance Force

SetTitleMatchMode(2)
SetWorkingDir(A_ScriptDir)

; ===== Ρυθμίσεις / Σταθερές =====
EDGE_WIN     := "Microsoft Edge"
EDGE_EXE     := "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
EDGE_PROFILE := '--profile-directory="Default"'

; Playlists (όπως στο αρχικό)
URL_ALL      := "https://www.youtube.com/playlist?list=PL1TQ_pTmsiADD0QnjnvlfoRV3kDUaFtXc&playnext=1&autoplay=1"
URL_GAMES    := "https://www.youtube.com/playlist?list=PL1TQ_pTmsiAAz486-6cs7ds0EM5Ee8ssp&playnext=1&autoplay=1"
; Προαιρετικό Shorts (σχολιασμένο στο Main)
URL_SHORTS   := "https://www.youtube.com/playlist?list=PL1TQ_pTmsiADjbuLSuERlL9-gcV3FGFN2&playnext=1&autoplay=1"

; Fixed videos (όπως στο YTBHFixed)
FIXED := [
    "https://youtu.be/SHcfDzCJFMQ?autoplay=1",
    "https://youtu.be/V_1-7NvEQ8U?autoplay=1",
    "https://youtu.be/hRSXQtHdTzk?autoplay=1",
    "https://youtu.be/WVIlygtfWmk?autoplay=1"
]

; Χρόνοι (δευτερόλεπτα) – ρύθμισέ τους εδώ
T_SHORT := 60      ; ~2x Pause30sec
T_MED   := 90      ; ~3x Pause30sec
T_LONG  := 120     ; ~4x Pause30sec

; Πλήθος στοιχείων ανά ροή (όπως στο αρχικό)
CNT_ALL   := 18
CNT_GAMES := 62
; CNT_SHORTS := 25  ; αν θελήσεις και τα shorts

; ===== Hotkeys =====
F9::Reload()                                 ; Γρήγορο restart
F10::{
    Suspend(-1)                              ; Toggle pause/resume
    ToolTip(A_IsSuspended ? "⏸️ Παύση" : "▶️ Συνέχιση")
    SetTimer(() => ToolTip(), -1200)
}
F12::ExitApp()

; ===== Εκκίνηση κύριας ροής =====
Main()

; ==================== Ρουτίνες ====================
Main() {
    loop {
        ShowTip("Έναρξη κύκλου…")
        if !OpenEdge()
            continue

        ; Για καθαρή κατάσταση καρτελών
        Send("^1")
        Sleep(300)

        ; 1) Playlist ALL: 18 στοιχεία × 120 s, Next με Shift+N
        PlayPlaylist(URL_ALL, CNT_ALL, T_LONG, true)

        ; 2) Fixed set: 4 βίντεο × 60 s (χωρίς Next)
        PlayFixed(FIXED, T_SHORT)

        ; 3) Playlist GAMES: 62 στοιχεία × 90 s, Next με Shift+N
        PlayPlaylist(URL_GAMES, CNT_GAMES, T_MED, true)

        ; (Προαιρετικά) Shorts – ξε-σχολίασε τη γραμμή:
        ; PlayPlaylist(URL_SHORTS, CNT_SHORTS, T_SHORT, false)

        WinClose(EDGE_WIN)
        Sleep(1000)
        ShowTip("Τέλος κύκλου.")
    }
}

ShowTip(msg, ms := 1500) {
    ToolTip(msg)
    SetTimer(() => ToolTip(), -ms)
}

OpenEdge() {
    global EDGE_WIN, EDGE_EXE, EDGE_PROFILE
    if WinExist(EDGE_WIN) {
        WinActivate(EDGE_WIN)
        WinWaitActive(EDGE_WIN, , 3)
        WinMaximize(EDGE_WIN)
        Sleep(200)
        return true
    }
    Run('"' EDGE_EXE '" ' EDGE_PROFILE)
    if !WinWait(EDGE_WIN, , 10)
        return false
    WinActivate(EDGE_WIN)
    WinWaitActive(EDGE_WIN, , 3)
    WinMaximize(EDGE_WIN)
    Sleep(300)
    return true
}

GotoURL(url) {
    Send("^l")        ; Επιλογή address bar
    Sleep(150)
    SendText(url)     ; Γραφή ως κείμενο (χωρίς ερμηνεία ειδικών πλήκτρων)
    Send("{Enter}")
    Sleep(1200)       ; Μικρή αναμονή αρχικής φόρτωσης
}

WaitPlayable(timeoutSec := 10) {
    loop timeoutSec
        Sleep(1000)
}

PlayPlaylist(url, count, perItemSec, goNext := true) {
    GotoURL(url)
    WaitPlayable(8)
    ; Προαιρετικά: Send("k") ; toggle play
    loop count {
        TimerSleep(perItemSec)
        if goNext
            SendShiftN()
    }
}

PlayFixed(arr, perItemSec) {
    for , url in arr {
        GotoURL(url)
        WaitPlayable(5)
        ; Προαιρετικά: Send("k")
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
; ==================== End Of File ====================