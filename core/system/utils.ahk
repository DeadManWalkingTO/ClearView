; ==================== lib/utils.ahk ====================
#Requires AutoHotkey v2.0
; Στόχος: Καθαρές, stateless, κοινές βοηθητικές συναρτήσεις για όλο το project.
; Κανόνες: Χωρίς imports, χωρίς πρόσβαση σε Settings/Logger/UI state.
; Στυλ: Πολυγραμμικά if, πλήρη try/catch, χωρίς &&/\\ (σύμφωνα με τους κανόνες του project).

class Utils {
  ; -------------------- Αριθμητικά / Έλεγχοι --------------------
  ; Επιστρέφει έναν ακέραιο v περιορισμένο στο [minV, maxV]
  static ClampInt(v, minV, maxV) {
    local x := 0
    try {
      x := v + 0
    } catch {
      x := v
    }
    if (x < minV) {
      x := minV
    }
    if (x > maxV) {
      x := maxV
    }
    return x
  }

  ; Ασφαλές parse σε ακέραιο με default
  static TryParseInt(v, default := 0) {
    try {
      return v + 0
    } catch {
      return default
    }
  }

  ; Ασφαλές parse σε float με default
  static TryParseFloat(v, default := 0.0) {
    try {
      return v + 0.0
    } catch {
      return default
    }
  }

  ; Τυχαίος ακέραιος στο [minV, maxV] με ασφάλεια ορίων
  static RandomInt(minV, maxV) {
    local a := Utils.TryParseInt(minV, 0)
    local b := Utils.TryParseInt(maxV, 0)
    if (b < a) {
      local t := a
      a := b
      b := t
    }
    try {
      return Round(Random(a, b))
    } catch {
      return a
    }
  }

  ; -------------------- Χρόνοι / Μορφοποιήσεις --------------------
  ; Μετατρέπει ms -> sec με παραμετρικό αριθμό δεκαδικών (default 1)
  static MsToSec(ms, decimals := 1) {
    local d := 1
    try {
      d := decimals + 0
    } catch {
      d := 1
    }
    if (d < 0) {
      d := 0
    }
    local s := 0.0
    try {
      s := (ms + 0) / 1000.0
    } catch {
      s := 0.0
    }
    try {
      return Round(s, d)
    } catch {
      return s
    }
  }

  ; Επιστρέφει "Xm YYs ZZZms" από ms (ίδιο style με το υπάρχον _fmtDurationMs)
  static FormatDurationMs(ms) {
    local total := Utils.TryParseInt(ms, 0)
    if (total < 0) {
      total := 0
    }
    local m := Floor(total / 60000)
    local rem := Mod(total, 60000)
    local s := Floor(rem / 1000)
    local msRem := Mod(rem, 1000)

    local sTxt := ""
    if (s < 10) {
      sTxt := "0" s
    } else {
      sTxt := "" s
    }
    local msTxt := ""
    if (msRem < 10) {
      msTxt := "00" msRem
    } else {
      if (msRem < 100) {
        msTxt := "0" msRem
      } else {
        msTxt := "" msRem
      }
    }
    return m "m " sTxt "s " msTxt "ms"
  }

  ; -------------------- Γεωμετρία / Συντεταγμένες --------------------
  ; Επιστρέφει true αν το σημείο (sx, sy) βρίσκεται εντός του ορθογωνίου (gx, gy, gw, gh).
  ; Προσοχή: θεωρεί half-open όρια [gx, gx+gw), [gy, gy+gh).
  static IsPointInRect(sx, sy, gx, gy, gw, gh) {
    if (gw > 0) {
      if (gh > 0) {
        if (sx >= gx) {
          if (sx < (gx + gw)) {
            if (sy >= gy) {
              if (sy < (gy + gh)) {
                return true
              }
            }
          }
        }
      }
    }
    return false
  }

  ; -------------------- Δίκτυο / Συνδεσιμότητα --------------------
  ; SSOT: Έλεγχος Internet (NCSI-like).
  ; Επιστρέφει true αν ληφθεί ακριβές "Microsoft Connect Test" από msftconnecttest.com
  ; μέσα στο timeout. Διαφορετικά false.
  static CheckInternet(timeoutMs := 3000) {
    url := "http://www.msftconnecttest.com/connecttest.txt"
    ok := false
    try {
      whr := ComObject("WinHttp.WinHttpRequest.5.1")
      whr.Open("GET", url, true)
      whr.SetTimeouts(timeoutMs, timeoutMs, timeoutMs, timeoutMs)
      whr.Send()
      whr.WaitForResponse(timeoutMs)
      txt := ""
      try {
        txt := whr.ResponseText
      } catch {
        txt := ""
      }
      if (txt = "Microsoft Connect Test") {
        ok := true
      }
    } catch {
      ok := false
    }
    return ok
  }
}
; ==================== End Of File ====================
