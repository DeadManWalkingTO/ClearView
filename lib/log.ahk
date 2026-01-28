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
        ; Καμία αλλοίωση κειμένου: γράφουμε ακριβώς το input
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
        ; Σωστά placeholders "{}" για το Format()
        this.Write(Format("ℹ️ Popup: {} (T={}s)", kind, Settings.POPUP_T))
        MsgBox(text, title, iconOpt " T" Settings.POPUP_T)
    }

    Clear() {
        this.txtLog.Value := ""
    }

    ; --- ΝΕΟ: Καθυστέρηση με logging ---
    ; Χρήση: logInst.SleepWithLog(Settings.STEP_DELAY_MS, "Μετά την πλοήγηση")
    SleepWithLog(ms, label := "") {
        try {
            d := ms + 0
            if (d <= 0) {
                return
            }
            ; Μήνυμα προς το Log
            if (label != "") {
                this.Write(Format("⏳ Καθυστέρηση {} ms — {}", d, label))
            } else {
                this.Write(Format("⏳ Καθυστέρηση {} ms", d))
            }
            Sleep(d)
        } catch Error as e {
            ; Αν κάτι πάει στραβά, απλώς μην εμποδίσεις τη ροή
            this.Write(Format("⚠️ Αδυναμία καθυστέρησης: {} ({}:{})", e.Message, e.File, e.Line))
        }
    }
}
; ==================== End Of File ====================
