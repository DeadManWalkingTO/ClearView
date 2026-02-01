; ==================== submacros/updater.ahk ====================
#Requires AutoHotkey v2.0
#Include "..\lib\settings.ahk"
#Include "..\lib\regex.ahk"
#Include "..\lib\utils.ahk"
#Include "..\lib\versions.ahk"
#Include "..\lib\initialize.ahk"  ; ⬅️ ΝΕΟ: χρησιμοποιούμε το SSOT για versions

; Updater (Adapter):
; - Κάνει *έλεγχο/σύγκριση* εκδόσεων μέσω Initializer.CheckVersions(logger, timeoutMs)
; - Προχωρά σε update (λήψη main.zip + κλήση update.bat) ΜΟΝΟ όταν remote > local (cmp = -1)
; - Διατηρεί ίδιο API: Updater.RunUpdateFlow(logger), ώστε το setup.ahk να μην αλλάξει.
; - Κανόνες: AHK v2, πολυγραμμικά if, πλήρη try/catch, χωρίς &&/\\.

class Updater
{
  static RunUpdateFlow(logger := 0)
  {
    ; 1) Έλεγχος/σύγκριση μέσω Initializer.CheckVersions (SSOT)
    info := Initializer.CheckVersions(logger, 3000)

    ; Internet off
    if (!info.online)
    {
      try {
        MsgBox("Δεν υπάρχει σύνδεση στο Internet. Παρακαλώ δοκιμάστε ξανά.", "Έλεγχος σύνδεσης", "Iconi")
      } catch {
      }
      return
    }

    ; Σφάλμα ανάγνωσης
    if (info.error != "")
    {
      try {
        if (info.error = "local_missing") {
          MsgBox("Αδυναμία ανάγνωσης τοπικής έκδοσης.", "Σφάλμα", "Iconx")
        } else if (info.error = "remote_missing") {
          MsgBox("Αδυναμία ανάγνωσης απομακρυσμένης έκδοσης.", "Σφάλμα", "Iconx")
        } else {
          MsgBox("Σφάλμα ελέγχου έκδοσης.", "Σφάλμα", "Iconx")
        }
      } catch {
      }
      return
    }

    ; cmp: 0 → τελευταία
    if (info.cmp = 0)
    {
      try {
        MsgBox("Η έκδοση της εφαρμογής είναι η τελευταία και δεν χρειάζεται αναβάθμιση.", "Εγκατάσταση νέας έκδοσης", "Iconi")
      } catch {
      }
      return
    }

    ; cmp: 1 → τοπική νεότερη (dev build)
    if (info.cmp = 1)
    {
      try {
        MsgBox("Τρέχεις νεότερη έκδοση από την απομακρυσμένη. Η αναβάθμιση παραλείπεται.", "Εγκατάσταση νέας έκδοσης", "Iconi")
      } catch {
      }
      return
    }

    ; cmp: -1 → Proceed: remote > local
    if (logger)
    {
      try {
        logger.Write("⬇️ Διαθέσιμη νεότερη έκδοση: local=" info.localVer " → remote=" info.remoteVer)
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

    ; 2) Λήψη ZIP
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

    ; 3) Εκτέλεση update.bat (ίδια λογική με πριν)
    batPath := A_ScriptDir "\update.bat"
    appRoot := Versions.GetAppRoot()

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

    ; 4) Κλείσιμο app για αντικατάσταση
    ExitApp
  }

  ; --- Internals ---
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
