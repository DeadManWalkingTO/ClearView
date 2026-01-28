; ==================== lib/settings.ahk ====================
#Requires AutoHotkey v2.0
class Settings {
    ; ------- Μεταδεδομένα / Εφαρμογή -------
    static APP_TITLE := "BH Automation — Edge/Chryseis"
    static APP_VERSION := "v2.11.0"

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

    ; ------- ΜΟΝΗ επιλογή για κλείσιμο άλλων παραθύρων -------
    ; Αν true: κλείνουμε όλα τα άλλα Edge windows (χωρίς ανίχνευση προφίλ).
    ; Προεπιλογή: false
    static CLOSE_ALL_OTHER_WINDOWS := false

    ; ------- CDP / Remote Debugging -------
    static CDP_ENABLED := true
    static CDP_PORT := 9222
}
; ==================== End Of File ====================
