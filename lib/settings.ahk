; ==================== lib/settings.ahk ====================
#Requires AutoHotkey v2.0

class Settings {
  ; --- Μεταδεδομένα / Εφαρμογή ---
  static APP_TITLE := "BH Automation — Edge/Chryseis"
  static APP_VERSION := "v3.2.2"   ; Έκδοση

  ; --- UI / Popups ---
  static POPUP_T := 3
  static KEEP_EDGE_OPEN := true
  static ICON_NEUTRAL := "🔵"

  ; --- Edge ---
  static EDGE_WIN_SEL := "ahk_exe msedge.exe"
  static EDGE_EXE := "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
  static EDGE_PROFILE_NAME := "Chryseis"
  static PROFILE_DIR_FORCE := ""

  ; --- Χρονισμοί ---
  static EDGE_STEP_DELAY_MS := 1500
  static STEP_DELAY_MS := 5000

  ; --- Paths δεδομένων ---
  static DATA_LIST_TXT := "..\data\list.txt"
  static DATA_RANDOM_TXT := "..\data\random.txt"

  ; --- Πιθανότητες ---
  static LIST1_PROB_PCT := 50
  static CLOSE_ALL_OTHER_WINDOWS := false

  ; --- Continuous loop (σε λεπτά - για συμβατότητα / fallback) ---
  static LOOP_MIN_MINUTES := 5
  static LOOP_MAX_MINUTES := 10

  ; --- Continuous loop (σε milliseconds - ακρίβεια logs) ---
  ; Προεπιλογή: ίδια όρια με τα λεπτά (5'–10'), αλλά σε ms
  static LOOP_MIN_MS := 5 * 60 * 1000
  static LOOP_MAX_MS := 10 * 60 * 1000
}
; ==================== End Of File ====================
