; ==================== lib/settings.ahk ====================
#Requires AutoHotkey v2.0
class Settings {
    ; ------- Μεταδεδομένα / Εφαρμογή -------
    static APP_TITLE := "BH Automation — Edge/Chryseis"
    static APP_VERSION := "v2.8.2"

    ; ------- Συμπεριφορά UI / Popups -------
    static POPUP_T := 3
    static KEEP_EDGE_OPEN := true
    static ICON_NEUTRAL := "🔵"

    ; ------- Edge / Επιλογές εκτέλεσης -------
    static EDGE_WIN_SEL := "ahk_exe msedge.exe"
    static EDGE_EXE := "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
    static EDGE_PROFILE_NAME := "Chryseis"
    static PROFILE_DIR_FORCE := ""

    ; ------- Χρονισμοί / Καθυστερήσεις -------
    static EDGE_STEP_DELAY_MS := 1500

    ; ------- Paths δεδομένων -------
    static DATA_LIST_TXT := "..\data\list.txt"
    static DATA_RANDOM_TXT := "..\data\random.txt"

    ; ------- Πιθανότητα επιλογής list1 (0–100) -------
    static LIST1_PROB_PCT := 50

    ; ------- ΝΕΟ: Κλείσιμο windows με "άγνωστο" προφίλ (WMI/CommandLine κενό) -------
    ; Ενεργό μόνο όταν έχουμε βρει σωστό προφίλ για το νέο παράθυρο.
    static CLOSE_WINDOWS_WHEN_PROFILE_UNKNOWN := true
}
; ==================== End Of File ====================
