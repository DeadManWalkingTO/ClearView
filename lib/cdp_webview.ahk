; ==================== lib/cdp_webview.ahk ====================
#Requires AutoHotkey v2.0
#Include "regex.ahk"

; -----------------------------------------------------------------------------
; WebViewCDP (Port-less) — Αξιολόγηση JavaScript μέσα στη σελίδα μέσω address bar
; -----------------------------------------------------------------------------
; Συνοπτικά:
; - Εκτελεί μικρό JS (IIFE) απευθείας στον Edge χωρίς WebSocket/CDP port.
; - Επιστρέφει αποτέλεσμα μέσω προσωρινής μεταβολής του document.title σε "CV_DUR:<number>".
; Κανόνες:
; - Πλήρη try/catch (πολυγραμμικά), χωρίς && / ||.
; - Χρήση RegexLib μόνο για ασφαλή quotes/backslash.
; -----------------------------------------------------------------------------

class WebViewCDP {
  static VERSION := "v1.0.2"

  /**
   * Υπολογίζει διάρκεια YouTube (σε δευτ.) από το ενεργό tab του Edge.
   * @param {Integer} hWnd        HWND του παραθύρου Edge.
   * @param {Integer} timeoutMs   Timeout ανάγνωσης τίτλου (default: 3000 ms).
   * @return {Integer} seconds    >=0 επιτυχία, -1 σε αποτυχία.
   */
  static GetYouTubeDurationSeconds(hWnd, timeoutMs := 3000) {
    local ok, js, marker, val
    if (hWnd = 0) {
      return -1
    }

    marker := "CV_DUR:"

    try {
      js := WebViewCDP._buildDurationJS(marker)
    } catch Error as _eBuild {
      return -1
    }

    ok := WebViewCDP._sendJsViaAddressBar(hWnd, js)
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

  ; ---------------- Internals ----------------

  /**
   * Συνθέτει έγκυρο one-line "javascript:(function(){...})();void 0".
   * Χρησιμοποιεί RegexLib μόνο για quotes/backslash.
   */
  static _buildDurationJS(marker) {
    local s, SQT, DQ, cssSel, prefixOk, prefixErr, js
    s   := RegexLib.Str
    SQT := RegexLib.Chars.SQT      ; "'"
    DQ  := s.DQ()                  ; double-quote (")
    ; CSS selector '.ytp-time-duration'
    cssSel   := SQT ".ytp-time-duration" SQT
    prefixOk := SQT marker SQT
    prefixErr:= SQT marker "ERR" SQT

    ; Καθαρό JS, χωρίς περιττά escapes:
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
   * Στέλνει JS μέσω address bar (Ctrl+L → Send → Enter).
   */
  static _sendJsViaAddressBar(hWnd, js) {
    try {
      WinActivate("ahk_id " hWnd)
      WinWaitActive("ahk_id " hWnd, , 3)
      Send("^{l}")
      Sleep(150)
      Send(js)
      Sleep(150)
      Send("{Enter}")
      Sleep(250)
      return true
    } catch Error as _eSend {
      return false
    }
  }

  /**
   * Poll τίτλου παραθύρου για ανάγνωση "CV_DUR:<num>".
   * Επιστρέφει κενό string σε timeout ή "CV_DUR:ERR".
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