; ==================== lib/settings.ahk ====================
#Requires AutoHotkey v2.0
class Settings {
    ; --- Μεταδεδομένα / Εφαρμογή ---
    static APP_TITLE := "BH Automation — Edge/Chryseis"
    static APP_VERSION := "v11.1.1"

    ; --- Debug ---
    static VIDEO_DEBUG := true ; ή false για απενεργοποίηση

    ; --- UI / Popups ---
    static POPUP_T := 3
    static KEEP_EDGE_OPEN := true
    static ICON_NEUTRAL := "🔵"

    ; --- GUI ---
    static GUI_MIN_W := 670
    static GUI_MIN_H := 400

    ; --- Edge ---
    static EDGE_WIN_SEL := "ahk_exe msedge.exe"
    static EDGE_EXE := "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
    static EDGE_PROFILE_NAME := "Chryseis"
    static PROFILE_DIR_FORCE := ""

    ; --- Χρονισμοί ---
    static SMALL_DELAY_MS := 1500
    static MID_DELAY_MS := 3000
    static LARGE_DELAY_MS := 5000

    ; --- Paths ---
    static DATA_LIST_TXT := "..\data\list.txt"
    static DATA_RANDOM_TXT := "..\data\random.txt"

    ; --- Πιθανότητες ---
    static LIST1_PROB_PCT := 50
    static CLOSE_ALL_OTHER_WINDOWS := false

    ; --- Continuous Loop σε λεπτά ---
    static LOOP_MIN_MINUTES := 2 ; Assigning default value for minimum loop duration in minutes
    static LOOP_MAX_MINUTES := 5 ; Assigning default value for maximum loop duration in minutes

    ; --- Continuous Loop σε ms ---
    static LOOP_MIN_MS := Settings.LOOP_MIN_MINUTES * 60 * 1000
    static LOOP_MAX_MS := Settings.LOOP_MAX_MINUTES * 60 * 1000

    ; --- Continuous Loop Delay ---
    static WAIT_TICK_MS := 30000

    ; --- Pre-click policy ---
    static PRE_CLICK_ENABLED := true   ; Αν είναι true, θα γίνεται προ-κλικ μετά την πλοήγηση
    static CLICK_OCCURRED_THIS_VIDEO := false  ; Flag για να παρακολουθεί αν έχει γίνει κλικ στο τρέχον βίντεο

    ; --- Ιστορικά flags (κρατάμε ό,τι χρειάζεται μόνο) ---
    static SIMPLE_PLAY_FOCUS := true
    static SIMPLE_PLAY_HOME := false
    static SEND_K_KEY := false
    static SIMPLE_PLAY_Y_FACTOR := 0.50

    ; --- Video detection (διατηρούνται όσα δεν είναι fallback actions) ---
    static VIDEO_WHITE_THRESHOLD := 0xE8E8E8
    static VIDEO_WAIT_TIMEOUT_MS := 3500
}
; ==================== End Of File ====================
