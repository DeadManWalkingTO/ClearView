; ==================== lib/lists.ahk ====================
#Requires AutoHotkey v2.0
#Include "settings.ahk"

; Υπηρεσία λιστών:
; - Φορτώνει list1/list2 από τα paths του Settings.
; - Δεν κάνει τυχαία επιλογή (αυτό μεταφέρθηκε στο videopicker.ahk).
; - Παρέχει μετρητές και accessors για ανάγνωση των πινάκων.

class ListsService {
  __New() {
    this._list1 := []
    this._list2 := []
  }

  Load(logger := 0) {
    this._list1 := this._readIdsFromFile(Settings.DATA_LIST_TXT)
    this._list2 := this._readIdsFromFile(Settings.DATA_RANDOM_TXT)

    try {
      if (logger) {
        logger.Write(Format("📥 list1: {1} ids", this._list1.Length))
        logger.Write(Format("📥 list2: {1} ids", this._list2.Length))
      }
    } catch Error as _eLog {
    }

    if (this._list1.Length = 0) {
      if (this._list2.Length = 0) {
        try {
          if (logger) {
            logger.Write("❌ Και οι 2 λίστες είναι άδειες – η ροή σταματάει.")
          }
        } catch Error as _eWarn {
        }
        throw Error("Empty lists")
      }
    }
  }

  Count1() {
    return this._list1.Length
  }

  Count2() {
    return this._list2.Length
  }

  IsEmpty() {
    if (this._list1.Length = 0) {
      if (this._list2.Length = 0) {
        return true
      }
    }
    return false
  }

  ; Accessors: επιστρέφουν τους εσωτερικούς πίνακες για ανάγνωση.
  GetList1() {
    return this._list1
  }

  GetList2() {
    return this._list2
  }

  ; ----------------- Internals -----------------
  _readIdsFromFile(path) {
    local arr := []
    local txt := ""
    try {
      txt := FileRead(path, "UTF-8")
    } catch Error as _eRead {
      txt := ""
    }

    if (txt != "") {
      txt := StrReplace(txt, "`r")
      for line in StrSplit(txt, "`n") {
        local id := ""
        id := Trim(line)
        if (id != "") {
          arr.Push(id)
        }
      }
    }
    return arr
  }
}
; ==================== End Of File ====================
