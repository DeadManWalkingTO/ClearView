; ==================== lib/log.ahk ====================
#Requires AutoHotkey v2.0
#Include "settings.ahk"
#Include "regex.ahk"

class Logger
{
  __New(txtLogCtrl, txtHeadCtrl)
  {
    this.txtLog := txtLogCtrl
    this.txtHead := txtHeadCtrl
  }

  /**
   * [ΔΙΑΤΗΡΕΙΤΑΙ ΓΙΑ ΣΥΜΒΑΤΟΤΗΤΑ]
   * Θέτει επικεφαλίδα (παλιά συμπεριφορά: μόνο head, με έκδοση).
   * ΣΗΜ.: Στο νέο μοντέλο προτιμάται η χρήση Both(text).
   */
  SetHeadline(text)
  {
    try {
      if (this.txtHead) {
        this.txtHead.Value := text " — " Settings.APP_VERSION
      }
    } catch Error as _e {
      ; no-op
    }
  }

  /**
   * ΝΕΟ: Ενιαία συνάρτηση logging.
   * Γράφει στο log (με timestamp) ΚΑΙ θέτει το head με το ΙΔΙΟ ΑΚΡΙΒΩΣ κείμενο.
   * Το head παίρνει ολόκληρη τη γραμμή του log, π.χ. "[12:34:56] μήνυμα".
   */
  Both(text)
  {
    try {
      ; 1) Σύνθεση γραμμής log με timestamp (reverse chronological)
      local ts := FormatTime(A_Now, "HH:mm:ss")
      local line := "[" ts "] " text

      ; 2) Ενημέρωση head με ΤΟ ΙΔΙΟ κείμενο (απαίτηση)
      try {
        if (this.txtHead) {
          this.txtHead.Value := line
        }
      } catch Error as _eHead {
        ; no-op
      }

      ; 3) Εγγραφή στο log (νεότερο στην κορυφή)
      try {
        local cur := ""
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

        ; 4) Scroll caret στην αρχή ώστε να φαίνεται το νεότερο
        local hwnd := 0
        try {
          hwnd := this.txtLog.Hwnd
        } catch Error as _eHwnd {
          hwnd := 0
        }
        if (hwnd != 0) {
          ; EM_SETSEL(0,0) + EM_SCROLLCARET
          DllCall("user32\SendMessage", "ptr", hwnd, "uint", 0xB1, "ptr", 0, "ptr", 0)
          DllCall("user32\SendMessage", "ptr", hwnd, "uint", 0xB7, "ptr", 0, "ptr", 0)
        }
      } catch Error as _eLog {
        ; no-op
      }
    } catch Error as _e {
      ; no-op
    }
  }

  /**
   * [ΣΥΜΒΑΤΟΤΗΤΑ → ΝΕΑ ΣΥΜΠΕΡΙΦΟΡΑ]
   * Πλέον Write(text) = Both(text) για να ενημερώνει και head και log.
   */
  Write(text)
  {
    try {
      this.Both(text)
    } catch Error as _e {
      ; no-op
    }
  }

  /**
   * Εμφανίζει popup ΚΑΙ το καταγράφει (μέσω Write→Both).
   */
  ShowTimed(kind, text, title, iconOpt := "Iconi")
  {
    try {
      this.Write(Format("ℹ️ Popup: {1} (T={2}s)", kind, Settings.POPUP_T))
      MsgBox(text, title, iconOpt " T" Settings.POPUP_T)
    } catch Error as _e {
      ; no-op
    }
  }

  /**
   * Καθαρίζει το log.
   */
  Clear()
  {
    try {
      this.txtLog.Value := ""
    } catch Error as _e {
      ; no-op
    }
  }

  /**
   * Ύπνος με log (χωρίς &&/||, με πλήρη try/catch).
   * Πλέον, επειδή καλεί Write, ενημερώνεται και το head.
   */
  SleepWithLog(ms, label := "")
  {
    try {
      local d := ms + 0
      if (d <= 0) {
        return
      }
      if (label != "") {
        this.Write(Format("⏳ Καθυστέρηση {1} ms — {2}", d, label))
      } else {
        this.Write(Format("⏳ Καθυστέρηση {1} ms", d))
      }
      Sleep(d)
    } catch Error as e {
      try {
        this.Write(Format("⚠️ Αδυναμία καθυστέρησης: {1} ({2}:{3})", e.Message, e.File, e.Line))
      } catch Error as _e2 {
        ; no-op
      }
    }
  }

  /**
   * Ασφαλές logging εξαιρέσεων (χωρίς IsSet σε ιδιότητες, χωρίς &&/||).
   * Πλέον, επειδή καλεί Write, ενημερώνεται και το head.
   */
  SafeErrorLog(prefix, e)
  {
    try {
      ; What
      local what := "n/a"
      try {
        what := e.What
      } catch Error as _eWhat {
        what := "n/a"
      }
      if (what = "") {
        what := "n/a"
      }

      ; File
      local file := "n/a"
      try {
        file := e.File
      } catch Error as _eFile {
        file := "n/a"
      }
      if (file = "") {
        file := "n/a"
      }

      ; Line
      local line := "n/a"
      try {
        line := e.Line
      } catch Error as _eLine {
        line := "n/a"
      }
      if (line = "") {
        line := "n/a"
      }

      ; Message
      local msg := "Unknown error"
      try {
        msg := e.Message
      } catch Error as _eMsg {
        msg := "Unknown error"
      }
      if (msg = "") {
        msg := "Unknown error"
      }

      this.Write(Format("{1} {2} — What={3}, File={4}, Line={5}", prefix, msg, what, file, line))
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
