; ==================== lib/settings.ahk ====================
#Requires AutoHotkey v2.0
; Single Source of Truth (SSOT):
; Όλες οι ρυθμίσεις/σταθερές της εφαρμογής δηλώνονται εδώ.
class Settings {
    ; ------- Μεταδεδομένα / Εφαρμογή -------
    static APP_TITLE := "BH Automation — Edge/Chryseis"
    static APP_VERSION := "v2.5.2" ; αλλάζεις εδώ την έκδοση

    ; ------- Συμπεριφορά UI / Popups -------
    static POPUP_T := 3 ; διάρκεια ενημερωτικών πλαισίων (δευτ.)
    static KEEP_EDGE_OPEN := true ; να παραμένει ανοιχτό το νέο παράθυρο Edge
    static ICON_NEUTRAL := "🔵" ; (δεν χρησιμοποιείται πλέον, αλλά μένει για συμβατότητα)

    ; ------- Edge / Επιλογές εκτέλεσης -------
    static EDGE_WIN_SEL := "ahk_exe msedge.exe" ; selector για WinGetList/Activate
    static EDGE_EXE := "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
    static EDGE_PROFILE_NAME := "Chryseis" ; εμφανιζόμενο όνομα προφίλ
    static PROFILE_DIR_FORCE := "" ; αν θες bypass resolver: π.χ. "Profile 3"

    ; ------- Paths δεδομένων (προαιρετικά) -------
    ; Αν μείνουν κενά, αρχικοποιούνται από το main.ahk σε ..\data\list.txt / ..\data\random.txt
    static DATA_LIST_TXT := ""
    static DATA_RANDOM_TXT := ""
}
; ==================== End Of File ====================
