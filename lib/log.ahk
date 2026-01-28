; ==================== lib/log.ahk ====================
#Requires AutoHotkey v2.0
#Include "settings.ahk"
#Include "regex.ahk"

class Logger {
  __New(txtLogCtrl, txtHeadCtrl) {
    this.txtLog := txtLogCtrl
    this.txtHead := txtHeadCtrl
  }

  /**
   * Θέτει επικεφαλίδα με έκδοση εφαρμογής.
   */
  SetHeadline(text) {
    try {
      this.txtHead.Value := text " — " Settings.APP_VERSION
    } catch Error as _e {
      ; no-op
    }
  }

  /**
   * Γράφει γραμμή log (προστίθεται στην αρχή – reverse chronological).
   * Και κάνει scroll στο caret για να εμφανίζεται το νεότερο.
   */
  Write(text) {
    try {
      ts := FormatTime(A_Now, "HH:mm:ss")
      line := "[" ts "] " text

      cur := ""
      try {
        cur := this.txtLog.Value
      } catch Error as _eGet {
        cur := ""
      }

      if (cur != "") {
        this.txtLog.Value := line "`r`n" cur
      } else {
        this.txtLog.Value := line
      }

      hwnd := 0
      try {
        hwnd := this.txtLog.Hwnd
      } catch Error as _eHwnd {
        hwnd := 0
      }

      if (hwnd != 0) {
        ; EM_SETSEL(0,0) + EM_SCROLLCARET για να «κλειδώσουμε» στην αρχή
        DllCall("user32\SendMessage", "ptr", hwnd, "uint", 0xB1, "ptr", 0, "ptr", 0)
        DllCall("user32\SendMessage", "ptr", hwnd, "uint", 0xB7, "ptr", 0, "ptr", 0)
      }
    } catch Error as _e {
      ; no-op
    }
  }

  /**
   * Εμφανίζει popup και το καταγράφει.
   */
  ShowTimed(kind, text, title, iconOpt := "Iconi") {
    try {
      this.Write(Format("ℹ️ Popup: {} (T={}s)", kind, Settings.POPUP_T))
      MsgBox(text, title, iconOpt " T" Settings.POPUP_T)
    } catch Error as _e {
      ; no-op
    }
  }

  /**
   * Καθαρίζει το log.
   */
  Clear() {
    try {
      this.txtLog.Value := ""
    } catch Error as _e {
      ; no-op
    }
  }

  /**
   * Ύπνος με log (χωρίς &&/||, με πλήρη try/catch).
   */
  SleepWithLog(ms, label := "") {
    try {
      d := ms + 0
      if (d <= 0) {
        return
      }

      if (label != "") {
        this.Write(Format("⏳ Καθυστέρηση {} ms — {}", d, label))
      } else {
        this.Write(Format("⏳ Καθυστέρηση {} ms", d))
      }

      Sleep(d)
    } catch Error as e {
      try {
        this.Write(Format("⚠️ Αδυναμία καθυστέρησης: {} ({}:{})", e.Message, e.File, e.Line))
      } catch Error as _e2 {
        ; no-op
      }
    }
  }

  /**
   * Ασφαλές logging εξαιρέσεων (χωρίς IsSet σε ιδιότητες, χωρίς &&/||).
   */
  SafeErrorLog(prefix, e) {
    try {
      ; What
      what := "n/a"
      try {
        what := e.What
      } catch Error as _eWhat {
        what := "n/a"
      }
      if (what = "") {
        what := "n/a"
      }

      ; File
      file := "n/a"
      try {
        file := e.File
      } catch Error as _eFile {
        file := "n/a"
      }
      if (file = "") {
        file := "n/a"
      }

      ; Line
      line := "n/a"
      try {
        line := e.Line
      } catch Error as _eLine {
        line := "n/a"
      }
      if (line = "") {
        line := "n/a"
      }

      ; Message
      msg := "Unknown error"
      try {
        msg := e.Message
      } catch Error as _eMsg {
        msg := "Unknown error"
      }
      if (msg = "") {
        msg := "Unknown error"
      }

      this.Write(Format("{} {} — What={}, File={}, Line={}", prefix, msg, what, file, line))
    } catch Error as _eLog {
      try {
        this.Write(prefix " (error while logging exception)")
      } catch Error as _eSilent {
        ; no-op
      }
    }
  }
}
; ==================== End Of File ====================
