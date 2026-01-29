; ==================== lib/ui_controller.ahk ====================
#Requires AutoHotkey v2.0
#Include "settings.ahk"
#Include "log.ahk"
#Include "flow.ahk"
#Include "ui_window.ahk"

class UiController {
  __New(uiWindow) {
    this._wnd := uiWindow
    this._logger := 0
    this._flow := 0
  }

  Init() {
    try {
      this._wnd.CreateWindow()
      this._wnd.AddControls()
      this._wnd.ShowWindow()
      this._wnd.GuiReflow()
      this._wnd.WirePositioning()
    } catch Error as _eInit {
      MsgBox("Αποτυχία αρχικοποίησης UI.", "Σφάλμα", "Iconx")
      ExitApp
    }
  }

  Bind(flowCtl, logger) {
    try {
      this._flow := flowCtl
      this._logger := logger
    } catch Error as _eBind {
      ; no-op
    }
  }

  WireEvents() {
    try {
      c := this._wnd.GetControls()
      c["btnStart"].OnEvent("Click", (*) => this.OnStart())
      c["btnPause"].OnEvent("Click", (*) => this.OnPauseResume())
      c["btnStop"].OnEvent("Click", (*) => this.OnStop())
      c["btnCopy"].OnEvent("Click", (*) => this.OnCopyLogs())
      c["btnClear"].OnEvent("Click", (*) => this.OnClearLogs())
      c["btnExit"].OnEvent("Click", (*) => this.OnExitApp())

      c["sldProb"].OnEvent("Change", (ctrl, info) => this.SliderProb_Changed(ctrl, info))
      c["chkClickToPlay"].OnEvent("Click", (ctrl, info := 0) => this.ChkClickToPlay_Changed(ctrl, info))
      c["edtLoopMin"].OnEvent("Change", (ctrl, info := 0) => this.OnLoopMinutesChanged(ctrl, info))
      c["edtLoopMax"].OnEvent("Change", (ctrl, info := 0) => this.OnLoopMinutesChanged(ctrl, info))
    } catch Error as _eWire {
      ; no-op
    }
  }

  Show() {
    ; Boot logs + Φόρτωση λιστών
    try {
      if (this._logger) {
        this._logger.Write("ℹ️ Έναρξη Εφαρμογής.")
        this._logger.Write(Format("ℹ️ Έκδοση: {1}", Settings.APP_VERSION))
        this._logger.Write(Format("ℹ️ Εκτελέσιμο Edge: {1}", Settings.EDGE_EXE))
        this._logger.Write(Format("ℹ️ Προφίλ: {1}", Settings.EDGE_PROFILE_NAME))
        this._logger.Write(Format("ℹ️ Διατήρηση Παραθύρου: {1}", (Settings.KEEP_EDGE_OPEN ? "Ναι" : "Όχι")))
        this._logger.Write(Format("ℹ️ Paths: list={1} - random={2}", Settings.DATA_LIST_TXT, Settings.DATA_RANDOM_TXT))
        this._logger.Write(Format("ℹ️ Πιθανότητα list1: {1}%", Settings.LIST1_PROB_PCT))
        this._logger.Write(Format("ℹ️ ClickToPlay: {1}", (Settings.CLICK_TO_PLAY ? "True" : "False")))
        this._logger.Write(Format("ℹ️ Close Other Windows: {1}", (Settings.CLOSE_ALL_OTHER_WINDOWS ? "True" : "False")))

        initMin := 0, initMax := 0
        try {
          initMin := Floor((Settings.LOOP_MIN_MS + 0) / 60000)
        } catch Error as _eB1 {
          try {
            initMin := Settings.LOOP_MIN_MINUTES + 0
          } catch Error as _eB1b {
            initMin := 5
          }
        }
        try {
          initMax := Floor((Settings.LOOP_MAX_MS + 0) / 60000)
        } catch Error as _eB2 {
          try {
            initMax := Settings.LOOP_MAX_MINUTES + 0
          } catch Error as _eB2b {
            initMax := 10
          }
        }
        if (initMax < initMin) {
          t2 := initMin, initMin := initMax, initMax := t2
        }
        this._logger.Write(Format("ℹ️ Διάστημα αναμονής (λεπτά): {1}–{2}", initMin, initMax))
      }
      if (this._flow) {
        this._flow.LoadIdLists()
      }
    } catch Error as _eBoot {
      ; no-op
    }
  }

  ; -------------------- Event Handlers --------------------
  OnStart() {
    try {
      if (!this._flow) {
        return
      }
      if this._flow.IsRunning() {
        this._logger.SetHeadline("ℹ️ Ήδη Εκτελείται.")
        this._logger.Write("ℹ️ Αγνοήθηκε")
        return
      }
      this._flow.StartRun()
    } catch Error as _eStart {
      ; no-op
    }
  }

  OnPauseResume() {
    try {
      if (!this._flow) {
        return
      }
      if !this._flow.IsRunning() {
        this._logger.SetHeadline("ℹ️ Δεν Εκτελείται Ροή.")
        this._logger.Write("ℹ️ Αγνοήθηκε")
        return
      }
      if this._flow.TogglePause() {
        try {
          this._wnd.GetControl("btnPause").Text := "Συνέχεια"
        } catch Error as _eBtn {
          ; no-op
        }
        this._logger.SetHeadline("⏸️ Παύση")
        this._logger.Write("⏸️ Παύση")
      } else {
        try {
          this._wnd.GetControl("btnPause").Text := "Παύση"
        } catch Error as _eBtn2 {
          ; no-op
        }
        this._logger.SetHeadline("▶️ Συνέχεια")
        this._logger.Write("▶️ Συνέχεια")
      }
    } catch Error as _ePause {
      ; no-op
    }
  }

  OnStop() {
    try {
      if (!this._flow) {
        return
      }
      if !this._flow.IsRunning() {
        this._logger.SetHeadline("ℹ️ Δεν Εκτελείται Ροή.")
        this._logger.Write("ℹ️ Αγνοήθηκε")
        return
      }
      this._flow.RequestStop()
      this._logger.SetHeadline("🛑 Τερματισμός…")
      this._logger.Write("🛑 Αίτημα Τερματισμού")
    } catch Error as _eStop {
      ; no-op
    }
  }

  OnCopyLogs() {
    try {
      txt := this._wnd.GetControl("txtLog")
      try {
        A_Clipboard := txt.Value
      } catch Error as _eClip {
        A_Clipboard := ""
      }
      this._logger.Write("📋 Αντιγραφή Log Στο Πρόχειρο")
      this._logger.SetHeadline("📋 Αντιγράφηκε")
    } catch Error as _eCopy {
      ; no-op
    }
  }

  OnClearLogs() {
    try {
      this._logger.Clear()
      this._logger.SetHeadline("🧼 Καθαρίστηκε")
      this._logger.Write("🧼 Καθαρισμός Log")
    } catch Error as _eClear {
      ; no-op
    }
  }

  OnExitApp() {
    try {
      this._logger.SetHeadline("🚪 Έξοδος")
      this._logger.Write("🚪 Τερματισμός")
    } catch Error as _eExit {
      ; no-op
    }
    ExitApp
  }

  SliderProb_Changed(ctrl, info) {
    try {
      Settings.LIST1_PROB_PCT := ctrl.Value
      try {
        this._wnd.GetControl("lblProb").Text := "list1: " Settings.LIST1_PROB_PCT "%"
      } catch Error as _eLbl {
        ; no-op
      }
      this._logger.Write("🎛️ Πιθανότητα list1 ενημερώθηκε σε " Settings.LIST1_PROB_PCT "%")
    } catch Error as _eSld {
      ; no-op
    }
  }

  ChkClickToPlay_Changed(ctrl, info := 0) {
    try {
      Settings.CLICK_TO_PLAY := (ctrl.Value = 1)
      this._logger.Write("☑️ Click To Play: " (Settings.CLICK_TO_PLAY ? "ON" : "OFF"))
    } catch Error as _eChk {
      ; no-op
    }
  }

  OnLoopMinutesChanged(ctrl, info := 0) {
    try {
      edtMin := this._wnd.GetControl("edtLoopMin")
      edtMax := this._wnd.GetControl("edtLoopMax")

      newMin := 0, newMax := 0
      try {
        newMin := Floor(edtMin.Value + 0)
      } catch Error as _eV1 {
        newMin := 0
      }
      try {
        newMax := Floor(edtMax.Value + 0)
      } catch Error as _eV2 {
        newMax := 0
      }

      if (newMin < 1) {
        newMin := 1
      }
      if (newMax < 1) {
        newMax := 1
      }
      if (newMin > 25) {
        newMin := 25
      }
      if (newMax > 25) {
        newMax := 25
      }
      if (newMax < newMin) {
        newMax := newMin
      }

      try {
        edtMin.Value := newMin
        edtMax.Value := newMax
      } catch Error as _eSetBack {
        ; no-op
      }

      minMs := newMin * 60000
      maxMs := newMax * 60000
      try {
        Settings.LOOP_MIN_MS := minMs
      } catch Error as _eSet1 {
        ; no-op
      }
      try {
        Settings.LOOP_MAX_MS := maxMs
      } catch Error as _eSet2 {
        ; no-op
      }

      try {
        this._logger.Write(Format("🛠️ Διάστημα αναμονής: {1}–{2} λεπτά ({3}–{4} ms)", newMin, newMax, minMs, maxMs))
      } catch Error as _eLog {
        ; no-op
      }
    } catch Error as _eAll {
      ; no-op
    }
  }
}
; ==================== End Of File ====================
