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

  ; ΝΕΟ: Καθαρός SSOT έλεγχος εκδόσεων με επιστροφή αποτελέσματος (ΧΩΡΙΣ UI side-effects)
  ; Επιστρέφει object: { online: bool, localVer: "vX.Y[.Z]", remoteVer: "vX.Y[.Z]", cmp: -1|0|1, error: ""|"no_internet"|"local_missing"|"remote_missing" }
  static CheckVersions(logger := 0, timeoutMs := 3000)
  {
    res := { online: false, localVer: "", remoteVer: "", cmp: 0, error: "" }

    okNet := false
    try {
      okNet := Utils.CheckInternet(timeoutMs)
    } catch {
      okNet := false
    }
    res.online := okNet

    if (!okNet) {
      try {
        if (logger) {
          logger.Write("⚠️ Χωρίς σύνδεση Internet. Παράλειψη ελέγχου έκδοσης.")
        }
      } catch {
      }
      res.error := "no_internet"
      return res
    }

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
        if (logger) {
          logger.Write("⛔ Αδυναμία ανάγνωσης τοπικής έκδοσης.")
        }
      } catch {
      }
      res.error := "local_missing"
      return res
    }
    res.localVer := localVer

    remoteUrl := "https://raw.githubusercontent.com/DeadManWalkingTO/ClearView/main/lib/settings.ahk"
    remoteVer := Versions.TryGetRemoteAppVersion(remoteUrl, 4000, logger)
    if (remoteVer = "")
    {
      try {
        if (logger) {
          logger.Write("⛔ Αδυναμία ανάγνωσης απομακρυσμένης έκδοσης.")
        }
      } catch {
      }
      res.error := "remote_missing"
      return res
    }
    res.remoteVer := remoteVer

    cmp := Versions.CompareSemVer(localVer, remoteVer)
    res.cmp := cmp
    return res
  }

  ; Ελαφρύς έλεγχος έκδοσης (UI side-effects): γράφει σε helper+logs με βάση το αποτέλεσμα του CheckVersions(...)
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

    info := Initializer.CheckVersions(logger, timeoutMs)

    ; Internet off
    if (!info.online)
    {
      try {
        if (helpCtrl) {
          helpCtrl.Text := "⚠️ Χωρίς σύνδεση Internet."
        }
      } catch {
      }
      return
    }

    ; Σφάλματα ανάγνωσης
    if (info.error != "")
    {
      try {
        if (helpCtrl) {
          if (info.error = "local_missing") {
            helpCtrl.Text := "⛔ Αδυναμία ανάγνωσης τοπικής έκδοσης."
          } else if (info.error = "remote_missing") {
            helpCtrl.Text := "⛔ Αδυναμία ανάγνωσης απομακρυσμένης έκδοσης."
          } else {
            helpCtrl.Text := "⛔ Άγνωστο σφάλμα ελέγχου έκδοσης."
          }
        }
      } catch {
      }
      return
    }

    ; Κανονικές καταστάσεις
    if (info.cmp = 0)
    {
      try {
        if (logger) {
          logger.Write("✅ Η έκδοση της εφαρμογής είναι η τελευταία. local=" info.localVer " → remote=" info.remoteVer ".")
        }
        if (helpCtrl) {
          helpCtrl.Text := "✅ Η έκδοση της εφαρμογής είναι η τελευταία.: local=" info.localVer " → remote=" info.remoteVer "."
        }
      } catch {
      }
      return
    }

    if (info.cmp = 1)
    {
      try {
        if (logger) {
          logger.Write("ℹ️ Η έκδοση της εφαρμογής είναι νεότερη: local=" info.localVer " → remote=" info.remoteVer ".")
        }
        if (helpCtrl) {
          helpCtrl.Text := "ℹ️ Η έκδοση της εφαρμογής είναι νεότερη: local=" info.localVer " → remote=" info.remoteVer "."
        }
      } catch {
      }
      return
    }

    ; cmp = -1 → remote newer
    try {
      if (logger) {
        logger.Write("⬇️ Διαθέσιμη νεότερη έκδοση: local=" info.localVer " → remote=" info.remoteVer ".")
      }
      if (helpCtrl) {
        helpCtrl.Text := "⬇️ Διαθέσιμη νεότερη έκδοση: local=" info.localVer " → remote=" info.remoteVer "."
      }
    } catch {
    }
  }
}
; ==================== End Of File ====================
