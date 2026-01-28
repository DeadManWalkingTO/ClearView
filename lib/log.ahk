; ==================== lib/log.ahk ====================
#Requires AutoHotkey v2.0
#Include "settings.ahk"

class Logger {
  __New(txtLogCtrl, txtHeadCtrl) {
    this.txtLog := txtLogCtrl
    this.txtHead := txtHeadCtrl
  }

  SetHeadline(text) {
    this.txtHead.Value := text " — " Settings.APP_VERSION
  }

  Write(text) {
    ts := FormatTime(A_Now, "HH:mm:ss")
    line := "[" ts "] " text
    cur := this.txtLog.Value
    if (cur != "") {
      this.txtLog.Value := line "`r`n" cur
    } else {
      this.txtLog.Value := line
    }
    ; Σωστός μονός backslash στο DllCall path
    hwnd := this.txtLog.Hwnd
    DllCall("user32\SendMessage", "ptr", hwnd, "uint", 0xB1, "ptr", 0, "ptr", 0)
    DllCall("user32\SendMessage", "ptr", hwnd, "uint", 0xB7, "ptr", 0, "ptr", 0)
  }

  ShowTimed(kind, text, title, iconOpt := "Iconi") {
    ; FIX: Σωστά placeholders {}
    this.Write(Format("ℹ️ Popup: {} (T={}s)", kind, Settings.POPUP_T))
    MsgBox(text, title, iconOpt " T" Settings.POPUP_T)
  }

  Clear() {
    this.txtLog.Value := ""
  }

  SleepWithLog(ms, label := "") {
    try {
      d := ms + 0
      if (d <= 0) {
        return
      }
      if (label != "") {
        ; FIX: Σωστά placeholders {}
        this.Write(Format("⏳ Καθυστέρηση {} ms — {}", d, label))
      } else {
        this.Write(Format("⏳ Καθυστέρηση {} ms", d))
      }
      Sleep(d)
    } catch Error as e {
      this.Write(Format("⚠️ Αδυναμία καθυστέρησης: {} ({}:{})", e.Message, e.File, e.Line))
    }
  }

  ; Ασφαλής ανάγνωση ιδιοτήτων εξαίρεσης χωρίς IsSet και χωρίς &&/||
  SafeErrorLog(prefix, e) {
    try {
      what := "n/a"
      try {
        what := e.What
      } catch {
        what := "n/a"
      }
      if (what = "") {
        what := "n/a"
      }
      file := "n/a"
      try {
        file := e.File
      } catch {
        file := "n/a"
      }
      if (file = "") {
        file := "n/a"
      }
      line := "n/a"
      try {
        line := e.Line
      } catch {
        line := "n/a"
      }
      if (line = "") {
        line := "n/a"
      }
      msg := "Unknown error"
      try {
        msg := e.Message
      } catch {
        msg := "Unknown error"
      }
      if (msg = "") {
        msg := "Unknown error"
      }
      this.Write(Format("{} {} — What={}, File={}, Line={}", prefix, msg, what, file, line))
    } catch {
      this.Write(prefix " (error while logging exception)")
    }
  }
}
; ==================== End Of File ====================
