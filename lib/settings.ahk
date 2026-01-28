; ==================== lib/settings.ahk ====================
#Requires AutoHotkey v2.0

class Settings {
  ; ---- Μεταδεδομένα / Εφαρμογή ----
  static APP_TITLE := "BH Automation — Edge/Chryseis"
  static APP_VERSION := "v2.11.0"

  ; ---- Συμπεριφορά UI / Popups ----
  static POPUP_T := 3            ; Διάρκεια MsgBox (s)
  static KEEP_EDGE_OPEN := true         ; Να παραμένει ανοιχτό το παράθυρο στο τέλος
  static ICON_NEUTRAL := "🔵"         ; Προεπιλεγμένο εικονίδιο/emoji κατάστασης

  ; ---- Edge / Επιλογές εκτέλεσης ----
  static EDGE_WIN_SEL := "ahk_exe msedge.exe"
  static EDGE_EXE := "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
  static EDGE_PROFILE_NAME := "Chryseis"
  static PROFILE_DIR_FORCE := ""           ; Αν δοθεί τιμή, παρακάμπτει ανίχνευση προφίλ

  ; ---- Χρονισμοί / Καθυστερήσεις ----
  static EDGE_STEP_DELAY_MS := 1500       ; Μικρή καθυστέρηση μεταξύ βημάτων Edge
  static STEP_DELAY_MS := 5000      ; Γενική καθυστέρηση (π.χ. πριν/μετά το play)

  ; ---- Paths δεδομένων ----
  static DATA_LIST_TXT := "..\data\list.txt"
  static DATA_RANDOM_TXT := "..\data\random.txt"

  ; ---- Πιθανότητα επιλογής list1 (0–100) ----
  static LIST1_PROB_PCT := 50

  ; ---- Κλείσιμο άλλων παραθύρων ----
  static CLOSE_ALL_OTHER_WINDOWS := false

  ; ❌ Αφαιρέθηκαν: CDP_ENABLED, CDP_PORT (δεν χρησιμοποιούνται πλέον)
}
; ==================== End Of File ====================
