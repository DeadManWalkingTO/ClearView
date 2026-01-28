; ==================== lib/log.ahk ====================
#Requires AutoHotkey v2.0
#Include "settings.ahk"

class Logger {
    __New(txtLogCtrl, txtHeadCtrl) {
        this.txtLog := txtLogCtrl
        this.txtHead := txtHeadCtrl
    }

    ; --- Public API ---
    SetHeadline(text) {
        this.txtHead.Value := text " — " Settings.APP_VERSION
    }

    Write(text) {
        ; Χωρίς αλλοίωση κειμένου: καταγράφουμε ακριβώς ό,τι δόθηκε
        ts := FormatTime(A_Now, "HH:mm:ss")
        line := "[" ts "] " text
        cur := this.txtLog.Value
        this.txtLog.Value := (cur != "") ? (line "`r`n" cur) : line
        ; caret top
        hwnd := this.txtLog.Hwnd
        DllCall("user32\SendMessage", "ptr", hwnd, "uint", 0xB1, "ptr", 0, "ptr", 0)
        DllCall("user32\SendMessage", "ptr", hwnd, "uint", 0xB7, "ptr", 0, "ptr", 0)
    }

    ShowTimed(kind, text, title, iconOpt := "Iconi") {
        this.Write(Format("ℹ️ Popup: {} (T={}s)", kind, Settings.POPUP_T))
        MsgBox(text, title, iconOpt " T" Settings.POPUP_T)
    }

    Clear() {
        this.txtLog.Value := ""
    }

    ; --- ΝΕΟ: Καθυστέρηση με logging ---
    ; Παράδειγμα: logInst.SleepWithLog(Settings.STEP_DELAY_MS, "μετά την πλοήγηση")
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
            this.Write(Format("⚠️ Αδυναμία καθυστέρησης: {} ({}:{})", e.Message, e.File, e.Line))
        }
    }

    ; --- Προαιρετικό helper: ασφαλές logging εξαιρέσεων ---
    SafeErrorLog(prefix, e) {
        try {
            what := (IsSet(e.What) && e.What != "" ? e.What : "n/a")
            file := (IsSet(e.File) && e.File != "" ? e.File : "n/a")
            line := (IsSet(e.Line) && e.Line != "" ? e.Line : "n/a")
            msg := (IsSet(e.Message) && e.Message != "" ? e.Message : "Unknown error")
            this.Write(Format("{} {} — What={}, File={}, Line={}", prefix, msg, what, file, line))
        } catch {
            this.Write(prefix " (error while logging exception)")
        }
    }
}
; ==================== End Of File ====================
