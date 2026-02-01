; ==================== lib/initialize.ahk ====================
#Requires AutoHotkey v2.0
#Include "utils.ahk"
#Include "versions.ahk"
; Helpers εκκίνησης UI (Internet + helpLine) και ελαφρύς έλεγχος έκδοσης.
; Κανόνες: AHK v2, πολυγραμμικά if, πλήρη try/catch, χωρίς &&/\.

class Initializer
{
  ; Ενημερώνει τη helpLine με βάση το Internet check.
  ; Επιστρέφει true/false για online κατάσταση.
  static UpdateConnectivityHelp(wnd, timeoutMs := 3000)
  {
    helpCtrl := 0
    try {
      helpCtrl := wnd.GetControl("helpLine")
    } catch {
      helpCtrl := 0
    }

    ok := false
    try {
      ok := Utils.CheckInternet(timeoutMs)
    } catch {
      ok := false
    }

    try {
      if (helpCtrl) {
        if (ok) {
          helpCtrl.Text := "✅ Διαδικτυακή συνδεσιμότητα: OK"
        } else {
          helpCtrl.Text := "⚠️ Χωρίς σύνδεση Internet."
        }
      }
    } catch {
    }

    return ok
  }


  ; === ΝΕΑ ΠΛΗΡΗΣ ΥΛΟΠΟΙΗΣΗ ===
  ; Ελαφρύς έλεγχος έκδοσης (log only) με micro‑retry & ρητή κάλυψη local-miss.


  static BootVersionCheck(logger, timeoutMs := 3000)
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
  }

}


; ==================== End Of File ====================
