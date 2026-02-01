; ==================== submacros/updater.ahk ====================
#Requires AutoHotkey v2.0
#Include "..\lib\settings.ahk"
#Include "..\lib\regex.ahk"
#Include "..\lib\utils.ahk"
#Include "..\lib\versions.ahk"

; Updater
; - Έλεγχος Internet (NCSI-like) μέσω Utils.CheckInternet (SSOT)
; - Ανάγνωση έκδοσης τοπικά (..\lib\settings.ahk) & απομακρυσμένα (raw GitHub)
; - Σύγκριση SemVer (vX.Y[.Z])
; - Skip όταν ίσες/τοπική νεότερη, Proceed μόνο όταν remote νεότερη
; - Λήψη ZIP (main.zip) και κλήση submacros\update.bat με args:
;   1) πλήρης διαδρομή ZIP, 2) πλήρης ρίζα εφαρμογής (γονικός του submacros)
; Κανόνες: AHK v2, πολυγραμμικά if, πλήρη try/catch, χωρίς &&/||.
class Updater
{
  ; ---------------- Public API ----------------
  static RunUpdateFlow(logger := 0)
  {
    ; 1) Internet check (NCSI) μέσω SSOT
    if (!Utils.CheckInternet()) {
      try {
        MsgBox("Δεν υπάρχει σύνδεση στο Internet. Παρακαλώ δοκιμάστε ξανά.", "Έλεγχος σύνδεσης", "Iconi")
      } catch {
      }
      return
    }

    ; 2) Εκδόσεις μέσω Versions (SSOT)
    settingsPath := Versions.GetLocalSettingsPath()
    if (logger)
    {
      try {
        logger.Write("🔎 settings.ahk (local): " settingsPath)
        if FileExist(settingsPath) {
          logger.Write("✅ settings.ahk υπάρχει στο δίσκο.")
        } else {
          logger.Write("❌ settings.ahk ΔΕΝ βρέθηκε στο δίσκο.")
        }
      } catch {
      }
    }

    localVer := Versions.TryReadLocalAppVersion(settingsPath, logger)
    if (localVer = "")
    {
      try {
        MsgBox("Αδυναμία ανάγνωσης τοπικής έκδοσης.", "Σφάλμα", "Iconx")
      } catch {
      }
      return
    }

    remoteUrl := "https://raw.githubusercontent.com/DeadManWalkingTO/ClearView/main/lib/settings.ahk"
    remoteVer := Versions.TryGetRemoteAppVersion(remoteUrl, 4000, logger)
    if (remoteVer = "")
    {
      try {
        MsgBox("Αδυναμία ανάγνωσης απομακρυσμένης έκδοσης.", "Σφάλμα", "Iconx")
      } catch {
      }
      return
    }

    ; 3) Σύγκριση SemVer
    cmp := Versions.CompareSemVer(localVer, remoteVer)
    if (cmp = 0)
    {
      try {
        MsgBox("Η έκδοση της εφαρμογής είναι η τελευταία και δεν χρειάζεται αναβάθμιση.", "Εγκατάσταση νέας έκδοσης", "Iconi")
      } catch {
      }
      return
    }
    if (cmp = 1)
    {
      ; local > remote → πιθανό dev build. Δεν κάνουμε downgrade.
      try {
        MsgBox("Τρέχεις νεότερη έκδοση από την απομακρυσμένη. Η αναβάθμιση παραλείπεται.", "Εγκατάσταση νέας έκδοσης", "Iconi")
      } catch {
      }
      return
    }

    ; 4) Proceed ONLY if remote > local (cmp = -1)
    if (logger)
    {
      try {
        logger.Write("⬇️ Διαθέσιμη νεότερη έκδοση: local=" localVer " → remote=" remoteVer)
      } catch {
      }
    }

    zipUrl := "https://github.com/DeadManWalkingTO/ClearView/archive/refs/heads/main.zip"
    tmpZip := Updater._composeTempZipPath()
    try {
      if FileExist(tmpZip) {
        FileDelete(tmpZip)
      }
    } catch {
    }

    ; Λήψη ZIP (AHK v2: throws on error)
    try {
      Download(zipUrl, tmpZip)
      if (logger) {
        logger.Write("⬇️ Λήψη πακέτου αναβάθμισης: " zipUrl)
      }
    } catch {
      try {
        MsgBox("Αποτυχία λήψης πακέτου αναβάθμισης.", "Σφάλμα", "Iconx")
      } catch {
      }
      return
    }

    ; 5) Κλήση update.bat με:
    ; arg1 = zipPath, arg2 = appRoot (γονικός φάκελος του submacros)
    batPath := A_ScriptDir "\update.bat"
    appRoot := Versions.GetAppRoot()

    ; Quoting με RegexLib για paths με κενά
    qBat := ""
    qZip := ""
    qRoot := ""
    try {
      qBat := RegexLib.Str.Quote(batPath)
      qZip := RegexLib.Str.Quote(tmpZip)
      qRoot := RegexLib.Str.Quote(appRoot)
    } catch {
      qBat := '"' batPath '"'
      qZip := '"' tmpZip '"'
      qRoot := '"' appRoot '"'
    }

    cmd := qBat " " qZip " " qRoot
    try {
      if (logger) {
        logger.Write("🛠️ Εκτέλεση updater: " batPath " (root=" appRoot ")")
      }
      Run(cmd, A_ScriptDir)
    } catch {
    }

    ; 6) Κλείσιμο εφαρμογής για να επιτραπεί η αντικατάσταση
    ExitApp
  }

  ; ---------------- Internals ----------------
  ; Παραμένει εδώ (όχι "version logic"): προσωρινό όνομα zip.
  static _composeTempZipPath()
  {
    ts := ""
    try {
      ts := FormatTime(A_Now, "yyyyMMdd-HHmmss")
    } catch {
      ts := A_TickCount
    }
    return A_Temp "\ClearView-main-" ts ".zip"
  }
}
; ==================== End Of File ====================
