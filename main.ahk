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

; ===== Status Panel (module) =====
class Status {
    static gui := ""
    static txt := ""
    static w := 420, h := 90
    static margin := 12

    static Show(initialText := "Έναρξη…") {
        if (Status.gui != "") {
            Status.Update(initialText)
            return
        }
        ; +E0x08000000: No-Activate (δεν παίρνει focus)
        Status.gui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x08000000")
        ; Αν θέλεις click-through: πρόσθεσε +E0x20 στην παραπάνω γραμμή
        Status.gui.BackColor := "0x101010"
        t := Status.gui.Add("Text", "xm ym cWhite", initialText)
        t.SetFont("s10", "Segoe UI")
        Status.txt := t

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
    global EDGE_PROFILE_NAME
    ; 1) Επίλυση φακέλου προφίλ από εμφανιζόμενο όνομα (π.χ. Chryseis → Profile 3)
    profDir := ResolveEdgeProfileDirByName(EDGE_PROFILE_NAME)
    if (profDir = "") {
        Status.Update("⚠️ Δεν βρέθηκε φάκελος για προφίλ: " EDGE_PROFILE_NAME ". Θα δοκιμάσω ως έχει…")
        profArg := '--profile-directory="' EDGE_PROFILE_NAME '"'
    } else {
        profArg := '--profile-directory="' profDir '"'
    }
    ; ΠΑΝΤΑ νέο παράθυρο αυτού του προφίλ (ανεξαρτήτως άλλων Edge)
    profArg .= " --new-window"

    loop {
        Status.Update("Άνοιγμα νέου παραθύρου Edge…")
        ; Άνοιξε νέο ΠΑΡΑΘΥΡΟ Edge στο ζητούμενο προφίλ και πάρε τον νέο hWnd
        hNew := OpenEdgeNewWindow(profArg)
        if (!hNew) {
            Status.Update("Αποτυχία ανοίγματος Edge. Επανάληψη σε 3 s…")
            Sleep(3000)
            continue
        }
        WinActivate("ahk_id " hNew)
        WinWaitActive("ahk_id " hNew, , 5)
        WinMaximize("ahk_id " hNew)
        Sleep(200)
        Status.Update("Edge έτοιμος (" EDGE_PROFILE_NAME ").")

        ; === Κάθε ροή σε ΝΕΑ καρτέλα ===
        NewTab(hNew), PlayPlaylist(URL_ALL,   CNT_ALL,   T_LONG, true)
        NewTab(hNew), PlayFixed(FIXED,        T_SHORT)
        NewTab(hNew), PlayPlaylist(URL_GAMES, CNT_GAMES, T_MED,  true)
        ; Προαιρετικά:
        ; NewTab(hNew), PlayPlaylist(URL_SHORTS, CNT_SHORTS, T_SHORT, false)

        ; Κλείσε ΜΟΝΟ το νέο παράθυρο (όχι όλο τον Edge)
        WinClose("ahk_id " hNew)
        WinWaitClose("ahk_id " hNew, , 5)
        Status.Update("Κύκλος ολοκληρώθηκε. Νέος κύκλος σε 1 s…")
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

    ; Εκτέλεση (δεν μας νοιάζει αν τρέχει άλλος Edge – ανοίγουμε ΝΕΟ)
    try Run('"' EDGE_EXE '" ' profileArg)  ; π.χ. --profile-directory="Profile 3" --new-window
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
    Status.Update("Άνοιγμα νέας καρτέλας…")
    WinActivate("ahk_id " hWnd)
    WinWaitActive("ahk_id " hWnd, , 3)
    Send("^t")
    Sleep(250)
}

GotoURL(url) {
    Status.Update("Μετάβαση σε URL…")
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

; ===== Helpers =====
DirExist_(path) {
    ; Επιστρέφει true αν υπάρχει directory
    return InStr(FileExist(path), "D") > 0
}

RegexEscape(str) {
    ; Escape των regex metacharacters
    return RegExReplace(str, "([\\.^$*+?()\\[\\]{}|])", "\\$1")
}
; ==================== End Of File ====================