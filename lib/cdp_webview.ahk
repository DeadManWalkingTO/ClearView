; ==================== lib/cdp_webview.ahk ====================
#Requires AutoHotkey v2.0
#Include "regex.ahk"

; -----------------------------------------------------------------------------
; WebViewCDP (Port-less): Υπολογισμός διάρκειας YouTube μέσω JS injection.
; Στρατηγική:
; 1) Προσπάθεια από address bar: javascript:(function(){...})();void 0
; 2) Αν αποτύχει γρήγορα, fallback: DevTools Console (F12/CTRL+SHIFT+J) → paste → Enter.
; Επιστροφή: seconds >= 0, αλλιώς -1.
; -----------------------------------------------------------------------------

class WebViewCDP {
  static VERSION := "v1.1.0"

  /**
   * Υπολογίζει διάρκεια YouTube (σε δευτ.) από το ενεργό tab του Edge.
   * @param {Integer} hWnd        HWND παραθύρου Edge.
   * @param {Integer} timeoutMs   Συνολικό timeout (default: 3000 ms).
   * @return {Integer} seconds    >=0 επιτυχία, -1 αποτυχία.
   */
  static GetYouTubeDurationSeconds(hWnd, timeoutMs := 3000) {
    local marker, tStart, left, res

    if (hWnd = 0) {
      return -1
    }

    marker := "CV_DUR:"

    ; --- 1) Address bar προσπάθεια (γρήγορη) ---
    res := WebViewCDP._tryAddressBar(hWnd, marker, 900)  ; μικρό timeout για άμεσο feedback
    if (res >= 0) {
      return res
    }

    ; --- 2) Fallback: DevTools Console injection ---
    left := timeoutMs - 900
    if (left < 800) {
      left := 800
    }
    res := WebViewCDP._tryDevToolsConsole(hWnd, marker, left)
    return res
  }

  ; ---------------- Internals ----------------

  /**
   * Address bar: στέλνει valid one-line javascript: payload και διαβάζει τίτλο.
   */
  static _tryAddressBar(hWnd, marker, timeoutMs) {
    local js, ok, val
    try {
      js := WebViewCDP._buildAddressBarJS(marker)
    } catch Error as _eBuild {
      return -1
    }

    ok := WebViewCDP._sendToAddressBar(hWnd, js)
    if (!ok) {
      return -1
    }

    try {
      val := WebViewCDP._readMarkerFromTitle(hWnd, marker, timeoutMs)
    } catch Error as _eRead {
      val := ""
    }

    if (val = "") {
      return -1
    }
    return val + 0
  }

  /**
   * DevTools Console injection: ανοίγει κονσόλα, επικολλά JS, Enter, διαβάζει τίτλο.
   * Δεν απαιτεί TCP port.
   */
  static _tryDevToolsConsole(hWnd, marker, timeoutMs) {
    local js, ok, val

    try {
      js := WebViewCDP._buildConsoleJS(marker)  ; IIFE, χωρίς "javascript:"
    } catch Error as _eBuildC {
      return -1
    }

    ; Άνοιγμα DevTools Console (δοκιμάζουμε Ctrl+Shift+J, αλλιώς F12)
    try {
      WinActivate("ahk_id " hWnd)
      WinWaitActive("ahk_id " hWnd, , 3)
      Send("^+j")       ; Open Console panel (Edge/Chromium)
      Sleep(400)
      ; Fallback σε F12 αν δεν άνοιξε σωστά
      Send("{F12}")
      Sleep(400)
    } catch Error as _eOpen {
      ; no-op
    }

    ; Επικόλληση JS στην κονσόλα (clipboard ή απευθείας Send)
    ; Χρησιμοποιούμε clipboard για αξιοπιστία σε μεγάλες γραμμές.
    try {
      oldClip := A_Clipboard
    } catch Error as _eGetClip {
      oldClip := ""
    }

    try {
      A_Clipboard := js
      Sleep(120)
      Send("^v")
      Sleep(150)
      Send("{Enter}")
      Sleep(250)
    } catch Error as _ePaste {
      ; Αν αποτύχει το paste, δοκιμάζουμε απευθείας Send(js)
      try {
        Send(js)
        Sleep(150)
        Send("{Enter}")
        Sleep(250)
      } catch Error as _eSend {
        ; no-op
      }
    } finally {
      try {
        A_Clipboard := oldClip
      } catch Error as _eRestore {
        ; no-op
      }
    }

    ; Δίνουμε λίγο χρόνο να αλλάξει ο τίτλος και τον διαβάζουμε
    try {
      val := WebViewCDP._readMarkerFromTitle(hWnd, marker, timeoutMs)
    } catch Error as _eRead2 {
      val := ""
    }

    ; Κλείσιμο DevTools (προαιρετικά)
    try {
      Send("{F12}")
      Sleep(200)
    } catch Error as _eClose {
      ; no-op
    }

    if (val = "") {
      return -1
    }
    return val + 0
  }

  ; --- Builders ---

  /**
   * Address bar payload: "javascript:(function(){try{...}catch(e){...}})();void 0"
   * Χρήση RegexLib μόνο για quotes/backslash (όχι για συντακτικά σύμβολα JS).
   */
  static _buildAddressBarJS(marker) {
    local s, SQT, cssSel, prefixOk, prefixErr, js
    s := RegexLib.Str
    SQT := RegexLib.Chars.SQT

    cssSel := SQT ".ytp-time-duration" SQT
    prefixOk := SQT marker SQT
    prefixErr := SQT marker "ERR" SQT

    js :=
      "javascript:(function(){try{"
      . "var el=document.querySelector(" cssSel ");"
      . "var t='';if(el){t=el.textContent;}var s=(''+t).trim();"
      . "if(s===''){document.title=" prefixErr ";return;}"
      . "var parts=s.split(':');var arr=[],i=0;"
      . "for(i=0;i<parts.length;i++){var x=(''+parts[i]).trim();var y=Number(x);arr.push(y);}"
      . "if(arr.length===0){document.title=" prefixErr ";return;}"
      . "var total=0;"
      . "if(arr.length===3){total=arr[0]*3600+arr[1]*60+arr[2];}"
      . "else{if(arr.length===2){total=arr[0]*60+arr[1];}else{total=arr[0];}}"
      . "if(!Number.isFinite(total)){document.title=" prefixErr ";return;}"
      . "document.title=" prefixOk "+total;"
      . "}catch(e){document.title=" prefixErr ";}})();void 0"

    return js
  }

  /**
   * Console payload: IIFE "(function(){try{...}catch(e){...}})();"
   */
  static _buildConsoleJS(marker) {
    local s, SQT, cssSel, prefixOk, prefixErr, js
    s := RegexLib.Str
    SQT := RegexLib.Chars.SQT

    cssSel := SQT ".ytp-time-duration" SQT
    prefixOk := SQT marker SQT
    prefixErr := SQT marker "ERR" SQT

    js :=
      "(function(){try{"
      . "var el=document.querySelector(" cssSel ");"
      . "var t='';if(el){t=el.textContent;}var s=(''+t).trim();"
      . "if(s===''){document.title=" prefixErr ";return;}"
      . "var parts=s.split(':');var arr=[],i=0;"
      . "for(i=0;i<parts.length;i++){var x=(''+parts[i]).trim();var y=Number(x);arr.push(y);}"
      . "if(arr.length===0){document.title=" prefixErr ";return;}"
      . "var total=0;"
      . "if(arr.length===3){total=arr[0]*3600+arr[1]*60+arr[2];}"
      . "else{if(arr.length===2){total=arr[0]*60+arr[1];}else{total=arr[0];}}"
      . "if(!Number.isFinite(total)){document.title=" prefixErr ";return;}"
      . "document.title=" prefixOk "+total;"
      . "}catch(e){document.title=" prefixErr ";}})();"

    return js
  }

  ; --- Send / Read helpers ---

  static _sendToAddressBar(hWnd, text) {
    try {
      WinActivate("ahk_id " hWnd)
      WinWaitActive("ahk_id " hWnd, , 3)
      Send("^{l}")
      Sleep(150)
      Send(text)
      Sleep(150)
      Send("{Enter}")
      Sleep(250)
      return true
    } catch Error as _eSend {
      return false
    }
  }

  /**
   * Διαβάζει τίτλο και επιστρέφει το (\d+) μετά από marker (π.χ. "CV_DUR:603").
   * Επιστρέφει "" σε timeout ή "ERR".
   */
  static _readMarkerFromTitle(hWnd, marker, timeoutMs) {
    local start, title, pat, m, escMarker, c
    c := RegexLib.Chars
    start := A_TickCount

    escMarker := RegexLib.Escape(marker)
    pat := escMarker . c.LPAREN . c.DIGIT . c.PLUS . c.RPAREN  ; CV_DUR:(\d+)

    while (A_TickCount - start < timeoutMs) {
      try {
        title := WinGetTitle("ahk_id " hWnd)
      } catch Error as _eTitle {
        title := ""
      }

      if (title != "") {
        try {
          if RegExMatch(title, pat, &m) {
            return m[1]
          }
          if (InStr(title, marker "ERR") > 0) {
            return ""
          }
        } catch Error as _ePat {
          ; no-op
        }
      }
      Sleep(120)
    }
    return ""
  }
}
; ==================== End Of File ====================
