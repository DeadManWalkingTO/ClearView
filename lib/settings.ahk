; ==================== lib/settings.ahk ====================
#Requires AutoHotkey v2.0

class Settings {
  static APP_TITLE := "BH Automation — Edge/Chryseis"
  static APP_VERSION := "v2.11.0"

  static POPUP_T := 3
  static KEEP_EDGE_OPEN := true
  static ICON_NEUTRAL := "🔵"

  static EDGE_WIN_SEL := "ahk_exe msedge.exe"
  static EDGE_EXE := "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
  static EDGE_PROFILE_NAME := "Chryseis"
  static PROFILE_DIR_FORCE := ""

  static EDGE_STEP_DELAY_MS := 1500
  static STEP_DELAY_MS := 5000

  static DATA_LIST_TXT := "..\data\list.txt"
  static DATA_RANDOM_TXT := "..\data\random.txt"

  static LIST1_PROB_PCT := 50
  static CLOSE_ALL_OTHER_WINDOWS := false

  ; ❌ Αφαιρέθηκε: PAYLOAD_JS_PATH (δεν υπάρχει πλέον λογική διάρκειας)
}
; ==================== End Of File ====================
