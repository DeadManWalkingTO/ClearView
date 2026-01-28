; ==================== lib/settings.ahk ====================
#Requires AutoHotkey v2.0
; Single Source of Truth (SSOT):
; Όλες οι ρυθμίσεις/σταθερές της εφαρμογής δηλώνονται εδώ.
class Settings {
    ; ------- Μεταδεδομένα / Εφαρμογή -------
    static APP_TITLE := "BH Automation — Edge/Chryseis"
    static APP_VERSION := "v2.8.2" ; αλλάζεις εδώ την έκδοση

    ; ------- Συμπεριφορά UI / Popups -------
    static POPUP_T := 3 ; διάρκεια ενημερωτικών πλαισίων (δευτ.)
    static KEEP_EDGE_OPEN := true ; να παραμένει ανοιχτό το νέο παράθυρο Edge
    static ICON_NEUTRAL := "🔵" ; συμβατότητα

    ; ------- Edge / Επιλογές εκτέλεσης -------
    static EDGE_WIN_SEL := "ahk_exe msedge.exe" ; selector για WinGetList/Activate
    static EDGE_EXE := "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
    static EDGE_PROFILE_NAME := "Chryseis" ; εμφανιζόμενο όνομα προφίλ
    static PROFILE_DIR_FORCE := "" ; π.χ. "Profile 3" για bypass

    ; ------- Paths δεδομένων -------
    ; Αν μείνουν κενά, ΠΛΕΟΝ ΔΕΝ γίνεται αρχικοποίηση από main.ahk — είναι σταθερά εδώ.
    static DATA_LIST_TXT := "..\data\list.txt"
    static DATA_RANDOM_TXT := "..\data\random.txt"

    ; --- ΝΕΟ: Πιθανότητα επιλογής list1 (0–100) ---
    static LIST1_PROB_PCT := 50
}
; ==================== End Of File ====================
