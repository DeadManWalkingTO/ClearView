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
        this.txtHead.Value := text "  —  " Settings.APP_VERSION
    }

    Write(text) {
        ; Προστασίες πριν το Title Case:
        ; 1) Το "(T=3s)" για να μη χαλάει.
        t := StrReplace(text, "(T=3s)", "__TIME_SUFFIX__")

        ; 2) Εκδόσεις τύπου vX.Y.Z (π.χ. v2.0.2) για να μη γίνει "V2.0.2".
        ;    Αποθηκεύουμε όλες τις εμφανίσεις σε placeholders και τις επαναφέρουμε μετά.
        savedVer := Map()
        verIdx := 0
        pos := 1
        while RegExMatch(t, "\bv\d+\.\d+\.\d+\b", &m, pos) {
            verIdx++
            ph := "__VER_" verIdx "__"
            savedVer[ph] := m[0]
            t := SubStr(t, 1, m.Pos(0) - 1) . ph . SubStr(t, m.Pos(0) + m.Len(0))
            pos := InStr(t, ph) + StrLen(ph)
        }

        ; Normalize → Title Case (μόνο για λατινικά tokens)
        t := this._normalizeSpaces(t)
        t := this._toTitleCaseLatinOnly(t)

        ; Επαναφορά εκδόσεων
        for ph, original in savedVer
            t := StrReplace(t, ph, original)

        ; Επαναφορά "(T=3s)"
        t := StrReplace(t, "__TIME_SUFFIX__", "(T=3s)")

        ; Επιλογή εικονιδίου + render (νεότερα επάνω)
        icon := this._pickIcon(t)
        ts := FormatTime(A_Now, "HH:mm:ss")
        line := "[" ts "] " icon " " t

        cur := this.txtLog.Value
        this.txtLog.Value := (cur != "") ? (line "`r`n" cur) : line

        ; caret top χωρίς focus
        hwnd := this.txtLog.Hwnd
        DllCall("user32\SendMessage", "ptr", hwnd, "uint", 0xB1, "ptr", 0, "ptr", 0)
        DllCall("user32\SendMessage", "ptr", hwnd, "uint", 0xB7, "ptr", 0, "ptr", 0)
    }

    ShowTimed(kind, text, title, iconOpt := "Iconi") {
        ; Log line: "Popup: Kind (T=3s)"
        this.Write(Format("Popup: {} (T={}s)", kind, Settings.POPUP_T))
        MsgBox(text, title, iconOpt " T" Settings.POPUP_T)
    }

    Clear() {
        this.txtLog.Value := ""
    }

    ; --- Internals ---
    _normalizeSpaces(s) {
        s := StrReplace(s, "`r", " ")
        s := StrReplace(s, "`n", " ")
        s := StrReplace(s, "`t", " ")
        return Trim(RegExReplace(s, "\s+", " "))
    }

    ; Title Case ΜΟΝΟ για λατινικές λέξεις. Ελληνικά/άλλα script μένουν ως έχουν.
    _toTitleCaseLatinOnly(s) {
        parts := StrSplit(s, " ")
        outs := []
        for _, p in parts {
            if (p = "")
                continue
            if RegExMatch(p, "^[A-Za-z]") {
                outs.Push(StrUpper(SubStr(p, 1, 1)) SubStr(p, 2))
            } else {
                outs.Push(p)
            }
        }
        return this._join(outs, " ")
    }

    _join(arr, sep := " ") {
        out := ""
        for i, v in arr {
            if (i > 1) out .= sep
                out .= v
        }
        return out
    }

    _pickIcon(msgTC) {
        if InStr(msgTC, "Popup:")                         ; ενημερωτικό popup
            return "ℹ️"
        if InStr(msgTC, "Profile Warn")                   ; προειδοποίηση
            return "⚠️"
        if InStr(msgTC, "Open Edge New Window")           ; ταχεία κίνηση
            return "⏩"
        if InStr(msgTC, "New Tab")                        ; νέα καρτέλα
            return "➡️"
        if InStr(msgTC, "Edge Ready")                     ; έτοιμο/OK
            return "✅"
        if InStr(msgTC, "Cycle Done")                     ; ολοκλήρωση
            return "✨"
        if InStr(msgTC, "Paused")                         ; παύση
            return "⏸️"
        if InStr(msgTC, "Stop Requested")                 ; stop
            return "❌"
        if InStr(msgTC, "Start Pressed") or InStr(msgTC, "Resumed")
            return "▶️"
        ; Default (ουδέτερο)
        return Settings.ICON_NEUTRAL
    }
}
; ==================== End Of File ====================
