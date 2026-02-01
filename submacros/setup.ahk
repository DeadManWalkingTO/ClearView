; ==================== submacros/setup.ahk ====================
#Requires AutoHotkey v2.0
#Include "..\lib\settings.ahk"
#Include "..\lib\regex.ahk"
#Include "..\lib\edge.ahk"
#Include "..\lib\edge_profile.ahk" ; SSOT: StartEdgeWithAppProfile(url, newWindow := true, logger := 0)
#Include ".\updater.ahk" ; ⬅️ ΝΕΟ: Updater με Skip/Proceed πολιτική

; Κλάση υπεύθυνη για τα κουμπιά "Εγκατάσταση" (1,2,3,4):
; - Εντοπίζει τα controls από το UiWindow (Init)
; - Παρέχει Enable()/Disable()
; - Κάνει WireEvents(logger) για σύνδεση ενεργειών
; - "1": Popup (Icon=info, τίτλος "Ρύθμιση Προφίλ", OK) -> άνοιγμα Edge (ίδιο προφίλ) στο https://www.bing.com/
; - "2": Popup (Icon=info, τίτλος "Ρύθμιση YouTube", OK) -> άνοιγμα Edge (ίδιο προφίλ) στο https://www.youtube.com/
; - "3": Popup (Icon=info, τίτλος "Ρύθμιση Προσθέτου", OK) -> άνοιγμα Edge (ίδιο προφίλ) στο Add-on URL (YouTube Ad AutoSkipper)
; - "4": Popup -> εκτέλεση Updater.RunUpdateFlow(logger) (SKIP/PROCEED)
; Κανόνες: AHK v2, πολυγραμμικά if, πλήρη try/catch, χωρίς &&/\\.

class SetupController
{
  __New(uiWindow)
  {
    this._wnd := uiWindow
    this._btns := Map()
    this._logger := 0
  }

  ; Καλείται αφού το UiWindow.AddControls() έχει δημιουργήσει τα controls.
  Init()
  {
    try {
      this._btns["1"] := this._wnd.GetControl("btnInst1")
    } catch {
      this._btns["1"] := 0
    }
    try {
      this._btns["2"] := this._wnd.GetControl("btnInst2")
    } catch {
      this._btns["2"] := 0
    }
    try {
      this._btns["3"] := this._wnd.GetControl("btnInst3")
    } catch {
      this._btns["3"] := 0
    }
    try {
      this._btns["4"] := this._wnd.GetControl("btnInst4")
    } catch {
      this._btns["4"] := 0
    }
  }

  WireEvents(logger := 0)
  {
    this._logger := logger
    ; --- "1": Popup -> OK -> άνοιγμα Edge (SSOT) στο https://www.bing.com/
    this._wireBtn("1", (*) => this._Action_ProfileSetup_OpenEdgeBing_SSO())
    ; --- "2": Popup -> OK -> άνοιγμα Edge (SSOT) στο https://www.youtube.com/
    this._wireBtn("2", (*) => this._Action_YTSetup_OpenEdgeYouTube_SSO())
    ; --- "3": Popup -> OK -> άνοιγμα Edge (SSOT) στο πρόσθετο (YouTube Ad AutoSkipper)
    this._wireBtn("3", (*) => this._Action_ExtSetup_OpenEdgeAddon_SSO())
    ; --- "4": Popup -> Updater.RunUpdateFlow(logger) (SKIP/PROCEED σύμφωνα με πολιτική)
    this._wireBtn("4", (*) => this._Action_Update_RunUpdater_SSO())
  }

  Enable()
  {
    for k, btn in this._btns
    {
      try {
        if (btn) {
          btn.Enabled := true
        }
      } catch {
      }
    }
  }

  Disable()
  {
    for k, btn in this._btns
    {
      try {
        if (btn) {
          btn.Enabled := false
        }
      } catch {
      }
    }
  }

  ; ==================== ΕΝΕΡΓΕΙΕΣ ====================

  ; "1": Προφίλ → Bing
  _Action_ProfileSetup_OpenEdgeBing_SSO()
  {
    msg := "Θα ανοίξει ο EDGE με νέες ρυθμίσεις. Παρακαλώ επιβεβαιώστε τις λειτουργίες και τις ρυθμίσεις."
    title := "Ρύθμιση Προφίλ"
    try {
      MsgBox(msg, title, "Iconi")
    } catch {
      ; Αν αποτύχει, συνεχίζουμε
    }
    url := "https://www.bing.com/"
    try {
      StartEdgeWithAppProfile(url, true, this._logger)
      this._safeLog("🌐 Edge (app profile) → " url)
    } catch {
      this._safeLog("❌ Αποτυχία εκκίνησης Edge (SSOT).")
    }
  }

  ; "2": YouTube
  _Action_YTSetup_OpenEdgeYouTube_SSO()
  {
    msg := "Θα ανοίξει το YouTube με νέες ρυθμίσεις. Παρακαλώ επιβεβαιώστε τις λειτουργίες και τις ρυθμίσεις."
    title := "Ρύθμιση YouTube"
    try {
      MsgBox(msg, title, "Iconi")
    } catch {
      ; Αν αποτύχει η εμφάνιση, συνεχίζουμε
    }
    url := "https://www.youtube.com/"
    try {
      StartEdgeWithAppProfile(url, true, this._logger)
      this._safeLog("🌐 Edge (app profile) → " url)
    } catch {
      this._safeLog("❌ Αποτυχία εκκίνησης Edge (SSOT) για YouTube.")
    }
  }

  ; "3": Add-on (YouTube Ad AutoSkipper)
  _Action_ExtSetup_OpenEdgeAddon_SSO()
  {
    msg := "Θα ανοίξει η σελίδα με το πρόσθετο για τις διαφημίσεις. Παρακαλώ να το εγκαταστήσετε."
    title := "Ρύθμιση Προσθέτου"
    try {
      MsgBox(msg, title, "Iconi")
    } catch {
      ; Αν αποτύχει η εμφάνιση, συνεχίζουμε
    }
    url := "https://microsoftedge.microsoft.com/addons/detail/youtube-ad-autoskipper/pemnfpmeljjngpfccgchgbocjdddjpio"
    try {
      StartEdgeWithAppProfile(url, true, this._logger)
      this._safeLog("🌐 Edge (app profile) → " url)
    } catch {
      this._safeLog("❌ Αποτυχία εκκίνησης Edge (SSOT) για το πρόσθετο.")
    }
  }

  ; "4": Updater (SKIP/PROCEED)
  _Action_Update_RunUpdater_SSO()
  {
    msg := "Η εφαρμογή θα ελέγξει για νεότερη έκδοση και θα ενημερωθεί αν υπάρχει."
    title := "Εγκατάσταση νέας έκδοσης"
    try {
      MsgBox(msg, title, "Iconi")
    } catch {
    }
    try {
      Updater.RunUpdateFlow(this._logger) ; θα κάνει ExitApp αν προχωρήσει σε update
    } catch {
      this._safeLog("❌ Αποτυχία εκτέλεσης Updater.")
    }
  }

  ; ==================== Internals ====================
  _wireBtn(key, fn)
  {
    btn := 0
    try {
      btn := this._btns[key]
    } catch {
      btn := 0
    }
    if (btn)
    {
      try {
        btn.OnEvent("Click", fn)
      } catch {
      }
    }
  }

  _safeLog(msg)
  {
    try {
      if (this._logger) {
        this._logger.Write(msg)
      }
    } catch {
    }
  }
}
; ==================== End Of File ====================
