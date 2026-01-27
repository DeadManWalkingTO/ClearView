; ==================== main.ahk (AHK v1) ====================
; Σταθερό automation για Edge + YouTube
; - Ανοίγει Edge (προφίλ Default)
; - Παίζει Playlists & Fixed videos με χρονικά διαστήματα
; - Next με Shift+N
; - Κλείνει το Edge και επαναλαμβάνει σε κύκλους
; -----------------------------------------------------------

#SingleInstance Force
#NoEnv
SendMode Input
SetTitleMatchMode 2
SetWorkingDir %A_ScriptDir%
; Προαιρετικά: CoordMode, Mouse, Window

; ===== Ρυθμίσεις / Σταθερές =====
global EDGE_WIN      := "Microsoft Edge"
global EDGE_EXE      := "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
global EDGE_PROFILE  := "--profile-directory=""Default"""

; Playlists (όπως στο αρχικό σου)
global URL_ALL       := "https://www.youtube.com/playlist?list=PL1TQ_pTmsiADD0QnjnvlfoRV3kDUaFtXc&playnext=1&autoplay=1"
global URL_GAMES     := "https://www.youtube.com/playlist?list=PL1TQ_pTmsiAAz486-6cs7ds0EM5Ee8ssp&playnext=1&autoplay=1"
; Προαιρετικό Shorts (είναι σχολιασμένο στο Main)
global URL_SHORTS    := "https://www.youtube.com/playlist?list=PL1TQ_pTmsiADjbuLSuERlL9-gcV3FGFN2&playnext=1&autoplay=1"

; Fixed videos (όπως στο YTBHFixed)
global FIXED := ["https://youtu.be/SHcfDzCJFMQ?autoplay=1"
               , "https://youtu.be/V_1-7NvEQ8U?autoplay=1"
               , "https://youtu.be/hRSXQtHdTzk?autoplay=1"
               , "https://youtu.be/WVIlygtfWmk?autoplay=1"]

; Χρόνοι (δευτερόλεπτα) – ρύθμισέ τους εδώ
global T_SHORT := 60      ; ~2x Pause30sec του αρχικού σε κάποια σημεία
global T_MED   := 90      ; ~3x Pause30sec
global T_LONG  := 120     ; ~4x Pause30sec

; Πλήθος στοιχείων ανά ροή (όπως στο αρχικό)
global CNT_ALL   := 18
global CNT_GAMES := 62
; global CNT_SHORTS := 25  ; αν θες να παίξεις και τα shorts

; ===== Hotkeys =====
F9::Reload                 ; Γρήγορο restart του script
F10::Suspend               ; Pause/Resume όλων των hotkeys & timers
F12::ExitApp               ; Έξοδος

; ===== Κύριος Βρόχος =====
Main:
Loop
{
    TrayTip, Macro, Start cycle…, 2, 1

    if !OpenEdge()
        continue

    ; Για καθαρή κατάσταση καρτελών
    Send, ^1
    Sleep, 300

    ; 1) Playlist ALL: 18 στοιχεία * 120 s, Next με Shift+N
    PlayPlaylist(URL_ALL, CNT_ALL, T_LONG, true)

    ; 2) Fixed set: 4 βίντεο * 60 s (χωρίς Next, αφού ανοίγουμε νέο URL κάθε φορά)
    PlayFixed(FIXED, T_SHORT)

    ; 3) Playlist GAMES: 62 στοιχεία * 90 s, Next με Shift+N
    PlayPlaylist(URL_GAMES, CNT_GAMES, T_MED, true)

    ; (Προαιρετικά) Shorts – ξε-σχολίασε αν θέλεις
    ; PlayPlaylist(URL_SHORTS, CNT_SHORTS, T_SHORT, false)

    ; Κλείσιμο Edge και μικρή παύση πριν νέο κύκλο
    WinClose, %EDGE_WIN%
    Sleep, 1000
    TrayTip, Macro, End cycle., 2, 1
}
return

; ==================== Ρουτίνες ====================

OpenEdge() {
    global EDGE_WIN, EDGE_EXE, EDGE_PROFILE
    ; Αν είναι ήδη ανοιχτό, απλά φέρ’ το μπροστά
    if WinExist(EDGE_WIN) {
        WinActivate, %EDGE_WIN%
        WinWaitActive, %EDGE_WIN%, , 3
        WinMaximize, %EDGE_WIN%
        Sleep, 200
        return true
    }

    ; Άνοιγμα Edge με συγκεκριμένο προφίλ
    Run, "%EDGE_EXE%" %EDGE_PROFILE%
    if !WinWait(EDGE_WIN, "", 10)
        return false

    WinActivate, %EDGE_WIN%
    WinWaitActive, %EDGE_WIN%, , 3
    WinMaximize, %EDGE_WIN%
    Sleep, 300
    return true
}

GotoURL(url) {
    ; Αξιόπιστη επιλογή address bar (Ctrl+L), clear & Enter
    Send, ^l
    Sleep, 150
    ; Προσοχή: SendInput για ταχύτητα
    SendInput, %url%
    Send, {Enter}
    ; Μικρή αναμονή για αρχική απόκριση
    Sleep, 1200
}

WaitPlayable(timeoutSec := 10) {
    ; Απλή αναμονή πριν ξεκινήσει η μέτρηση
    ; (Μπορείς να προσθέσεις ImageSearch/PixelSearch εδώ, αν θέλεις ανίχνευση UI)
    loop, %timeoutSec%
        Sleep, 1000
}

PlayPlaylist(url, count, perItemSec, goNext := true) {
    GotoURL(url)
    WaitPlayable(8)
    ; Προαιρετικά: Send, k   ; toggle play, αν χρειάζεται

    Loop, %count%
    {
        TimerSleep(perItemSec)
        if (goNext)
            SendShiftN()
    }
}

PlayFixed(arr, perItemSec) {
    for index, url in arr
    {
        GotoURL(url)
        WaitPlayable(5)
        ; Προαιρετικά: Send, k
        TimerSleep(perItemSec)
    }
}

TimerSleep(sec) {
    ; Μετρητής σε δευτερόλεπτα (σιωπηλός). Αν θες feedback, βάλε ToolTip.
    Loop, %sec%
        Sleep, 1000
}

SendShiftN() {
    ; Next video στο YouTube
    Send, +n
    Sleep, 200
}
; ==================== End of File ====================