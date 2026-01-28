; ==================== lib/cdp_webview.ahk ====================
#Requires AutoHotkey v2.0
#Include "regex.ahk"

; -----------------------------------------------------------------------------
; WebViewCDP (Port-less) — Αξιολόγηση JavaScript μέσα στη σελίδα μέσω address bar
; -----------------------------------------------------------------------------
; Στόχος
; - Εκτέλεση μικρού JS (IIFE) απευθείας στον Edge χωρίς WebSocket/CDP port.
; - Επιστροφή αποτελέσματος (π.χ. διάρκειας YouTube) μέσω προσωρινής μεταβολής
;   του document.title σε "CV_DUR:<number>".
;
; Κανόνες:
; - AHK v2: Πλήρη try/catch blocks (καμία μονογραμμική catch).
; - Χωρίς τελεστές && / || (διαδοχικά if).
; - Σύνθεση όλων των strings/regex με RegexLib.Chars/Str/Escape για συνέπεια.
; -----------------------------------------------------------------------------

class WebViewCDP {
  static VERSION := "v1.0.1"

  /**
   * Υπολογίζει διάρκεια YouTube (σε δευτ.) από το ενεργό tab του Edge.
   * Μηχανισμός:
   *  - Εκτελεί IIFE JS μέσω "javascript:..." στην address bar.
   *  - Το JS αλλάζει προσωρινά το document.title σε "CV_DUR:<αριθμός>".
   *  - Το AHK διαβάζει τον τίτλο παραθύρου και εξάγει το αποτέλεσμα.
   *
   * @param {Integer} hWnd        HWND του παραθύρου Edge (νέο παράθυρο που άνοιξες).
   * @param {Integer} timeoutMs   Συνολικό timeout ανάγνωσης τίτλου (default: 3000 ms).
   * @return {Integer} seconds    >=0 επιτυχία, -1 σε αποτυχία.
   */
  static GetYouTubeDurationSeconds(hWnd, timeoutMs := 3000) {
    local ok, js, marker, val
    if (hWnd = 0) {
      return -1
    }

    ; Marker για document.title
    marker := "CV_DUR:"

    ; Σύνθεση one-line JS (χωρίς backticks/newlines) με RegexLib helpers
    try {
      js := WebViewCDP._buildDurationJS(marker)
    } catch Error as _eBuild {
      return -1
    }

    ; Αποστολή στην address bar & εκτέλεση
    ok := WebViewCDP._sendJsViaAddressBar(hWnd, js)
    if (!ok) {
      return -1
    }

    ; Ανάγνωση τίτλου με polling μέχρι timeout
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
   * Χτίζει το one-line javascript:... payload που υπολογίζει τη διάρκεια
   * και γράφει title="CV_DUR:<num>" ή "CV_DUR:ERR" σε αποτυχία.
   * Χρησιμοποιεί RegexLib.Chars/Str για ασφαλή quotes/backslashes.
   */
  static _buildDurationJS(marker) {
    local c, s, SQT, DQ, BS, cssSel, emptyStr, prefixOk, prefixErr, js

    c := RegexLib.Chars
    s := RegexLib.Str

    ; Βασικές σταθερές για quoting
    SQT := c.SQT               ; "'"
    DQ  := s.DQ()              ; Chr(34)
    BS  := s.BS()              ; "\"

    ; CSS selector με ασφαλή quoting: '.ytp-time-duration'
    cssSel := SQT . ".ytp-time-duration" . SQT

    ; Κενή συμβολοσειρά '' για JS
    emptyStr := SQT . SQT

    ; Προθέματα τίτλου (quoted για JS)
    ; 'CV_DUR:' και 'CV_DUR:ERR'
    prefixOk  := SQT . marker      . SQT
    prefixErr := SQT . marker . "ERR" . SQT

    ; JS (one-line, χωρίς &&/||, χωρίς ternary, με ; στο τέλος)
    ; Προσοχή: Αποφεύγουμε backticks στο AHK string. Όλα τα quotes/γραμμή είναι ασφαλή.
    js :=
      "javascript:(function(){try{"
      . "var el=document.querySelector(" . cssSel . ");"
      . "var t='';if(el){t=el.textContent;}var s=(''+t).trim();"
      . "if(s===''){document.title=" . prefixErr . ";return;}"
      . "var parts=s.split(':');var arr=[];var i=0;"
      . "for(i=0;i<parts.length;i++){var x=(''+parts[i]).trim();var y=Number(x);arr.push(y);}"
      . "if(arr.length===0){document.title=" . prefixErr . ";return;}"
      . "var total=0;"
      . "if(arr.length===3){total=arr[0]*3600+arr[1]*60+arr[2];}"
      . "else{if(arr.length===2){total=arr[0]*60+arr[1];}else{total=arr[0];}}"
      . "if(!Number.isFinite(total)){document.title=" . prefixErr . ";return;}"
      . "document.title=" . prefixOk . "+total;"
      . "}catch(e){document.title=" . prefixErr . ";}})();void 0"

    return js
  }

  /**
   * Στέλνει JS μέσω address bar (Ctrl+L → paste → Enter).
   */
  static _sendJsViaAddressBar(hWnd, js) {
    try {
      WinActivate("ahk_id " hWnd)
      WinWaitActive("ahk_id " hWnd, , 3)
      Send("^{l}")
      Sleep(120)
      Send(js)
      Sleep(120)
      Send("{Enter}")
      Sleep(200)
      return true
    } catch Error as _eSend {
      return false
    }
  }

  /**
   * Poll τίτλου παραθύρου για ανάγνωση "CV_DUR:<num>".
   * Επιστρέφει κενό string σε timeout ή σε "CV_DUR:ERR".
   *
   * Χρησιμοποιεί regex pattern συντεθειμένο με RegexLib (χωρίς ωμά strings).
   */
  static _readMarkerFromTitle(hWnd, marker, timeoutMs) {
    local start, title, pat, m, escMarker, c

    c := RegexLib.Chars
    start := A_TickCount

    ; Παράγουμε regex: "CV_DUR:(\d+)" με ασφαλή σύνθεση
    ; 1) Escape του marker για ασφάλεια
    escMarker := RegexLib.Escape(marker)
    ; 2) Συνθέτουμε captured group για digits: (\d+)
    pat := escMarker . c.LPAREN . c.DIGIT . c.PLUS . c.RPAREN

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
          ; Αν έχει ακριβώς "CV_DUR:ERR" (ασφαλές check χωρίς &&/||)
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

  /**
   * Επιστρέφει τα αρχικά ψηφία του s (π.χ. "603 more" -> "603") με RegexLib.
   * (Helper που δεν χρησιμοποιείται πλέον από _readMarkerFromTitle, αλλά παραμένει)
   */
  static _extractLeadingNumber(s) {
    local c, m
    c := RegexLib.Chars
    m := ""
    try {
      ; Παράγουμε ^\s*(\d+) ως pattern:
      ; ^  -> anchor
      ; \s* -> προαιρετικά κενά
      ; (\d+) -> captured group digits
      pat := "^" . c.WS . c.STAR . c.LPAREN . c.DIGIT . c.PLUS . c.RPAREN
      if RegExMatch(s, pat, &m) {
        return m[1]
      }
    } catch Error as _eNum {
      ; no-op
    }
    return ""
  }
}
; ==================== End Of File ====================