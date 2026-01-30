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
      c["edtLoopMin"].OnEvent("Change", (ctrl, info := 0) => this.OnLoopMinutesChanged(ctrl, info))
      c["edtLoopMax"].OnEvent("Change", (ctrl, info := 0) => this.OnLoopMinutesChanged(ctrl, info))
    } catch Error as _eWire {
    }
  }

  Show() {
    try {
      if (this._logger) {
        this._logger.Write("ℹ️ Έναρξη Εφαρμογής.")
        this._logger.Write(Format("ℹ️ Έκδοση: {1}", Settings.APP_VERSION))
        this._logger.Write(Format("ℹ️ Εκτελέσιμο Edge: {1}", Settings.EDGE_EXE))
        this._logger.Write(Format("ℹ️ Προφίλ: {1}", Settings.EDGE_PROFILE_NAME))
        this._logger.Write(Format("ℹ️ Διατήρηση Παραθύρου: {1}", (Settings.KEEP_EDGE_OPEN ? "Ναι" : "Όχι")))
        this._logger.Write(Format("ℹ️ Paths: list={1} - random={2}", Settings.DATA_LIST_TXT, Settings.DATA_RANDOM_TXT))
        this._logger.Write(Format("ℹ️ Πιθανότητα list1: {1}%", Settings.LIST1_PROB_PCT))

        initMin := Floor((Settings.LOOP_MIN_MS + 0) / 60000)
        initMax := Floor((Settings.LOOP_MAX_MS + 0) / 60000)
        this._logger.Write(Format("ℹ️ Διάστημα αναμονής (λεπτά): {1}–{2}", initMin, initMax))
      }
      ; *** ΣΗΜΑΝΤΙΚΟ ***
      ; ΑΦΑΙΡΕΘΗΚΕ: this._flow.LoadIdLists()
    } catch Error as _eBoot {
    }
  }

  OnStart() {
    try {
      if (!this._flow)
        return

      if this._flow.IsRunning() {
        this._logger.SetHeadline("ℹ️ Ήδη Εκτελείται.")
        this._logger.Write("ℹ️ Αγνοήθηκε")
        return
      }

      this._flow.StartRun()

    } catch Error as _eStart {
    }
  }

  OnPauseResume() {
    try {
      if (!this._flow)
        return

      if !this._flow.IsRunning() {
        this._logger.SetHeadline("ℹ️ Δεν Εκτελείται Ροή.")
        this._logger.Write("ℹ️ Αγνοήθηκε")
        return
      }

      if this._flow.TogglePause() {
        this._wnd.GetControl("btnPause").Text := "Συνέχεια"
        this._logger.SetHeadline("⏸️ Παύση")
        this._logger.Write("⏸️ Παύση")
      } else {
        this._wnd.GetControl("btnPause").Text := "Παύση"
        this._logger.SetHeadline("▶️ Συνέχεια")
        this._logger.Write("▶️ Συνέχεια")
      }
    } catch Error as _ePause {
    }
  }

  OnStop() {
    try {
      if (!this._flow)
        return

      if !this._flow.IsRunning() {
        this._logger.SetHeadline("ℹ️ Δεν Εκτελείται Ροή.")
        this._logger.Write("ℹ️ Αγνοήθηκε")
        return
      }

      this._flow.RequestStop()
      this._logger.SetHeadline("🛑 Τερματισμός…")
      this._logger.Write("🛑 Αίτημα Τερματισμού")
    } catch Error as _eStop {
    }
  }

  OnCopyLogs() {
    try {
      txt := this._wnd.GetControl("txtLog")
      A_Clipboard := txt.Value
      this._logger.Write("📋 Αντιγραφή Log Στο Πρόχειρο")
      this._logger.SetHeadline("📋 Αντιγράφηκε")
    } catch Error as _eCopy {
    }
  }

  OnClearLogs() {
    try {
      this._logger.Clear()
      this._logger.SetHeadline("🧼 Καθαρίστηκε")
      this._logger.Write("🧼 Καθαρισμός Log")
    } catch Error as _eClear {
    }
  }

  OnExitApp() {
    try {
      this._logger.SetHeadline("🚪 Έξοδος")
      this._logger.Write("🚪 Τερματισμός")
    } catch Error as _eExit {
    }
    ExitApp
  }

  SliderProb_Changed(ctrl, info) {
    try {
      Settings.LIST1_PROB_PCT := ctrl.Value
      this._wnd.GetControl("lblProb").Text := "list1: " Settings.LIST1_PROB_PCT "%"
      this._logger.Write("🎛️ Πιθανότητα list1 ενημερώθηκε σε " Settings.LIST1_PROB_PCT "%")
    } catch Error as _eSld {
    }
  }

  OnLoopMinutesChanged(ctrl, info := 0) {
    try {
      edtMin := this._wnd.GetControl("edtLoopMin")
      edtMax := this._wnd.GetControl("edtLoopMax")

      newMin := Floor(edtMin.Value + 0)
      newMax := Floor(edtMax.Value + 0)

      if (newMin < 1) newMin := 1
        if (newMax < 1) newMax := 1
          if (newMin > 25) newMin := 25
            if (newMax > 25) newMax := 25
              if (newMax < newMin) newMax := newMin
                edtMin.Value := newMin
      edtMax.Value := newMax

      minMs := newMin * 60000
      maxMs := newMax * 60000

      Settings.LOOP_MIN_MS := minMs
      Settings.LOOP_MAX_MS := maxMs

      this._logger.Write(Format("🛠️ Διάστημα αναμονής: {1}–{2} λεπτά ({3}–{4} ms)", newMin, newMax, minMs, maxMs))
    } catch Error as _eAll {
    }
  }
}
; ==================== End Of File ====================
