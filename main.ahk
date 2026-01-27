; ==================== main_v2_status_fixed_newtab.ahk (AHK v2) ====================
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
; Προφίλ που ζήτησες
EDGE_PROFILE := '--profile-directory="Chryseis"'

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
    static w := 380, h := 90
    static margin := 12

    static Show(initialText := "Έναρξη…") {
        if (Status.gui != "") {
            Status.Update(initialText)
            return
        }
        ; +E0x08000000: No-Activate (δεν παίρνει focus)
        Status.gui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x08000000")
        ; Αν θες click-through: πρόσθεσε +E0x20 στην παραπάνω γραμμή
        Status.gui.BackColor := "0x101010"
        f := Status.gui.Add("Text", "xm ym cWhite", initialText)
        f.SetFont("s10", "Segoe UI")
        Status.txt := f

        ; Τοποθέτηση: επάνω-δεξιά της κύριας οθόνης
        left := top := right := bottom := 0
        MonitorGetWorkArea(1, &left, &top, &right, &bottom)
        x := right - Status.w - Status.margin
        y := top   + Status.margin

        Status.gui.Show(Format("x{} y{} w{} h{} NA", x, y, Status.w, Status.h))
        WinSetTransparent(230, Status.gui.Hwnd)
    }

    static Update(text) {
        if (Status.gui = "")
            Status.Show(text)
        else
            Status.txt.Value := text
    }

    static Close() {
        if (Status.gui != "") {
            Status.gui.Destroy()
            Status.gui := ""
            Status.txt := ""
        }
    }
}

; ===== Hotkeys =====
F9::Reload()
F10::{
    Suspend(-1)
    Status.Update(A_IsSuspended ? "⏸️ Παύση" : "▶️ Συνέχιση")
}
F12::{
    Status.Close()
    ExitApp()
}

; ===== Εκκίνηση =====
Status.Show("Το script ξεκίνησε…")
Main()

; ==================== Ρουτίνες ====================
Main() {
    loop {
        Status.Update("Έναρξη κύκλου…")
        if !OpenEdge() {
            Status.Update("Αποτυχία ενεργοποίησης Edge. Επανάληψη σε 3 s…")
            Sleep(3000)
            continue
        }

        ; === ΝΕΟ: Αντί για 1η καρτέλα, άνοιξε ΝΕΑ καρτέλα πριν από κάθε ροή ===

        ; 1) Playlist ALL
        NewTab()
        PlayPlaylist(URL_ALL, CNT_ALL, T_LONG, true)

        ; 2) Fixed videos
        NewTab()
        PlayFixed(FIXED, T_SHORT)

        ; 3) Playlist GAMES
        NewTab()
        PlayPlaylist(URL_GAMES, CNT_GAMES, T_MED, true)

        ; (Προαιρετικά) Shorts
        ; NewTab()
        ; PlayPlaylist(URL_SHORTS, CNT_SHORTS, T_SHORT, false)

        ; Ορθό κλείσιμο & αναμονή κλεισίματος πριν νέο κύκλο
        WinClose(EDGE_WIN)
        if !WinWaitClose(EDGE_WIN, , 5) {
            WinClose(EDGE_WIN)
            WinWaitClose(EDGE_WIN, , 5)
        }
        Status.Update("Κύκλος ολοκληρώθηκε. Νέος κύκλος σε 1 s…")
        Sleep(1000)
    }
}

OpenEdge() {
    global EDGE_WIN, EDGE_PROC, EDGE_EXE, EDGE_PROFILE
    Status.Update("Άνοιγμα/Ενεργοποίηση Edge…")

    ; Αν υπάρχει ήδη παράθυρο Edge, ενεργοποίησέ το
    if WinExist(EDGE_WIN) {
        WinActivate(EDGE_WIN)
        if !WinWaitActive(EDGE_WIN, , 3)
            return false
        WinMaximize(EDGE_WIN)
        Sleep(200)
        Status.Update("Edge έτοιμος.")
        return true
    }

    ; Αν δεν τρέχει διεργασία, άνοιξε τον Edge με το ζητούμενο προφίλ
    if !ProcessExist(EDGE_PROC)
        Run('"' EDGE_EXE '" ' EDGE_PROFILE)

    ; Περίμενε να εμφανιστεί/ενεργοποιηθεί ΠΑΡΑΘΥΡΟ του Edge
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

; === Άνοιγμα νέας καρτέλας ===
NewTab() {
    Status.Update("Άνοιγμα νέας καρτέλας…")
    Send("^t")           ; Ctrl+T → New Tab
    Sleep(250)
}

GotoURL(url) {
    Status.Update("Μετάβαση σε URL…")
    Send("^l")           ; Focus address bar
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
    loop sec
        Sleep(1000)
}

SendShiftN() {
    Send("+n")
    Sleep(200)
}
; ==================== End Of File ====================