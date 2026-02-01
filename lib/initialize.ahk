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


  static BootVersionCheck(logger, timeoutMs := 3000, wnd := 0)
  {
    helpCtrl := 0
    try {
      if (wnd) {
        helpCtrl := wnd.GetControl("helpLine")
      }
    } catch {
      helpCtrl := 0
    }

    ; 1) Internet check (NCSI) μέσω SSOT
    if (!Utils.CheckInternet())
    {

      try {
        if (logger) {
          logger.Write("⚠️ Χωρίς σύνδεση Internet. Παράλειψη ελέγχου έκδοσης.")
        }
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
      ; ΠΡΙΝ: MsgBox("Αδυναμία ανάγνωσης τοπικής έκδοσης.", "Σφάλμα", "Iconx")
      try {
        if (logger) {
          logger.Write("⛔ Αδυναμία ανάγνωσης τοπικής έκδοσης.")
        }
      } catch {
      }
      return
    }

    remoteUrl := "https://raw.githubusercontent.com/DeadManWalkingTO/ClearView/main/lib/settings.ahk"
    remoteVer := Versions.TryGetRemoteAppVersion(remoteUrl, 4000, logger)
    if (remoteVer = "")
    {
      ; ΠΡΙΝ: MsgBox("Αδυναμία ανάγνωσης απομακρυσμένης έκδοσης.", "Σφάλμα", "Iconx")
      try {
        if (logger) {
          logger.Write("⛔ Αδυναμία ανάγνωσης απομακρυσμένης έκδοσης.")
        }
      } catch {
      }
      return
    }

    ; 3) Σύγκριση SemVer
    cmp := Versions.CompareSemVer(localVer, remoteVer)
    if (cmp = 0)
    {
      ; local = remote → τελευταία έκδοση.
      try {
        if (logger) {
          logger.Write("✅ Η έκδοση της εφαρμογής είναι η τελευταία.")
        }
        if (helpCtrl) {
          helpCtrl.Text := "✅ Η έκδοση της εφαρμογής είναι η τελευταία."
        }
      } catch {
      }
      return
    }

    if (cmp = 1)
    {
      ; local > remote → πιθανό dev build. Δεν κάνουμε downgrade.
      try {
        if (logger) {
          logger.Write("ℹ️ Η έκδοση της εφαρμογής είναι νεότερη.")
        }

        if (helpCtrl) {
          helpCtrl.Text := "ℹ️ Η έκδοση της εφαρμογής είναι νεότερη."
        }

      } catch {
      }
      return
    }

    ; remote > local (cmp = -1)
    if (logger)
    {
      try {
        logger.Write("⬇️ Διαθέσιμη νεότερη έκδοση: local=" localVer " → remote=" remoteVer)
      } catch {
      }
      if (helpCtrl) {
        helpCtrl.Text := " ⬇️ Διαθέσιμη νεότερη έκδοση: local = " localVer " → remote = " remoteVer
      }
    }
  }
}


; ==================== End Of File ====================
