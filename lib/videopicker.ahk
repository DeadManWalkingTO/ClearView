; ==================== lib/videopicker.ahk ====================
#Requires AutoHotkey v2.0
#Include "settings.ahk"

; VideoPicker:
; - Δεν κάνει I/O: δέχεται ListsService (ή συμβατό API) που έχει ήδη φορτώσει list1/list2.
; - Αποφασίζει ποια λίστα θα προτιμήσει με βάση probPct (0..100).
; - Επιλέγει τυχαίο ID από την επιλεγμένη λίστα, με fallback στην άλλη αν είναι κενή.
; - Επιστρέφει αντικείμενο: { source: "list1"|"list2"|"none", id: "<YT_ID>"|"", url: "<YT_URL>"|"about:blank" }.
; - Τηρεί τους κανόνες AHK v2 του project (πολυγραμμικά if, πλήρη try/catch, χωρίς &&/||).

class VideoPicker {
  __New(listsService) {
    this.lists := listsService
  }

  ; Επιλογή τυχαίου βίντεο.
  ; probPct: πιθανότητα (0..100) να επιλεγεί η list1.
  ; logger: προαιρετικό Logger για ενημερωτικά/προειδοποιήσεις.
  Pick(probPct, logger := 0) {
    local p := 50
    try {
      p := probPct + 0
    } catch Error as _eP {
      p := 50
    }

    if (p < 0) {
      p := 0
    }
    if (p > 100) {
      p := 100
    }

    ; Απόφαση λίστας
    local r := 0
    local useList1 := false
    r := Random(0, 100)
    if (r < p) {
      useList1 := true
    } else {
      useList1 := false
    }

    ; Λήψη του κατάλληλου πίνακα από το lists service (με fallback)
    local sel := this._getListArray(useList1)
    if (sel.Length = 0) {
      sel := this._getListArray(!useList1)
    }

    if (sel.Length = 0) {
      try {
        if (logger) {
          logger.Write("⚠️ Καμία λίστα διαθέσιμη (list1/list2 κενές) — about:blank.")
        }
      } catch Error as _eLog {
      }
      return { source: "none", id: "", url: "about:blank" }
    }

    ; Τυχαία επιλογή ID
    local idx := 1
    idx := Random(1, sel.Length)
    local pick := ""
    try {
      pick := sel[idx]
    } catch Error as _eIdx {
      pick := ""
    }

    if (pick = "") {
      try {
        if (logger) {
          logger.Write("⚠️ Άκυρη επιλογή ID — about:blank.")
        }
      } catch Error as _eLog2 {
      }
      return { source: "none", id: "", url: "about:blank" }
    }

    ; Σύνθεση URL YouTube (watch)
    local url := ""
    url := "https://www.youtube.com/watch?v=" pick

    return { source: (useList1 ? "list1" : "list2"), id: pick, url: url }
  }

  ; ----------------- Internals -----------------
  _getListArray(useList1) {
    ; Περιμένουμε από το ListsService να παρέχει GetList1()/GetList2().
    if (useList1) {
      try {
        return this.lists.GetList1()
      } catch Error as _eL1 {
        return []
      }
    } else {
      try {
        return this.lists.GetList2()
      } catch Error as _eL2 {
        return []
      }
    }
  }
}
; ==================== End Of File ====================
