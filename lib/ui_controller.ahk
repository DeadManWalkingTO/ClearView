; ==================== lib/ui_controller.ahk ====================
#Requires AutoHotkey v2.0
#Include "settings.ahk"
#Include "log.ahk"
#Include "flow.ahk"
#Include "ui_window.ahk"

class UiController
{
  __New(uiWindow)
  {
    this._wnd := uiWindow
    this._logger := 0
    this._flow := 0
    this._setup := 0    ; ⬅️ ΝΕΟ: αναφορά στον SetupController
  }

  Bind(flowCtl, logger)
  {
    try
    {
      this._flow := flowCtl
      this._logger := logger
    }
    catch Error as eBind
    {
    }
  }

  ; ΝΕΟ: δέχεται τον SetupController από το main
  BindSetup(setupCtl)
  {
    try {
      this._setup := setupCtl
    } catch {
      this._setup := 0
    }
  }

  WireEvents()
  {
    try
    {
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
    }
    catch Error as eWire
    {
    }
  }

  Show()
  {
    try
    {
      if (this._logger)
      {
        this._logger.Write("ℹ️ Έναρξη Εφαρμογής.")
        ; ⬇️ ΝΕΟ: ειδοποίηση στο flow ακριβώς μετά το μήνυμα
        try {
          if (this._flow) {
            this._flow.PerformBootInitialization()
          }
        } catch {
        }
        this._logger.Write(Format("ℹ️ Έκδοση: {1}", Settings.APP_VERSION))
        this._logger.Write(Format("ℹ️ Εκτελέσιμο Edge: {1}", Settings.EDGE_EXE))
        this._logger.Write(Format("ℹ️ Προφίλ: {1}", Settings.EDGE_PROFILE_NAME))
        this._logger.Write(Format("ℹ️ Διατήρηση Παραθύρου: {1}", Settings.KEEP_EDGE_OPEN ? "Ναι" : "Όχι"))
        this._logger.Write(Format("ℹ️ Paths: list={1} - random={2}", Settings.DATA_LIST_TXT, Settings.DATA_RANDOM_TXT))
        this._logger.Write(Format("ℹ️ Πιθανότητα list1: {1}%", Settings.LIST1_PROB_PCT))
        initMin := Floor((Settings.LOOP_MIN_MS + 0) / 60000)
        initMax := Floor((Settings.LOOP_MAX_MS + 0) / 60000)
        this._logger.Write(Format("ℹ️ Διάστημα αναμονής (λεπτά): {1}–{2}", initMin, initMax))
      }
    }
    catch Error as eShow
    {
    }

    ; ΑΠΑΙΤΗΣΗ: Τα κουμπιά "Εγκατάσταση" ενεργά ΜΟΝΟ στην εκκίνηση UI
    try {
      if (this._setup) {
        this._setup.Enable()   ; ενεργά στο boot
      }
    } catch {
    }
  }

  OnStart()
  {
    try
    {
      if (!this._flow)
      {
        return
      }
      if (this._flow.IsRunning())
      {
        this._logger.Write("ℹ️ Αγνοήθηκε")
        return
      }

      ; Με το πάτημα Έναρξη -> ανενεργά πλέον
      try {
        if (this._setup) {
          this._setup.Disable()
        }
      } catch {
      }

      try
      {
        this._flow.StartRun()
      }
      catch Error as eRun
      {
        ; logging ήδη μέσα στο FlowController
      }
      ; ΣΚΟΠΙΜΑ: δεν τα ξανα-ενεργοποιούμε μετά το τέλος
    }
    catch Error as eStart
    {
    }
  }

  OnPauseResume()
  {
    try
    {
      if (!this._flow)
      {
        return
      }
      if (!this._flow.IsRunning())
      {
        this._logger.Write("ℹ️ Αγνοήθηκε")
        return
      }
      if (this._flow.TogglePause())
      {
        this._wnd.GetControl("btnPause").Text := "Συνέχεια"
        this._logger.Write("⏸️ Παύση")
      }
      else
      {
        this._wnd.GetControl("btnPause").Text := "Παύση"
        this._logger.Write("▶️ Συνέχεια")
      }
    }
    catch Error as ePause
    {
    }
  }

  OnStop()
  {
    try
    {
      if (!this._flow)
      {
        return
      }
      if (!this._flow.IsRunning())
      {
        this._logger.Write("ℹ️ Αγνοήθηκε")
        return
      }
      this._flow.RequestStop()
      this._logger.Write("🛑 Αίτημα Τερματισμού")
      ; ΣΚΟΠΙΜΑ: καμία αλλαγή στα κουμπιά εγκατάστασης (μένουν off)
    }
    catch Error as eStop
    {
    }
  }

  OnCopyLogs()
  {
    try
    {
      txt := this._wnd.GetControl("txtLog")
      A_Clipboard := txt.Value
      this._logger.Write("📋 Αντιγραφή Log στο Πρόχειρο")
    }
    catch Error as eCopy
    {
    }
  }

  OnClearLogs()
  {
    try
    {
      this._logger.Clear()
      this._logger.Write("🧼 Καθαρισμός Log")
    }
    catch Error as eClear
    {
    }
  }

  OnExitApp()
  {
    try
    {
      this._logger.Write("🚪 Τερματισμός")
    }
    catch Error as eExit
    {
    }
    ExitApp
  }

  SliderProb_Changed(ctrl, info)
  {
    try
    {
      Settings.LIST1_PROB_PCT := ctrl.Value
      this._wnd.GetControl("lblProb").Text := "list1: " Settings.LIST1_PROB_PCT "%"
      this._logger.Write("🎛️ Πιθανότητα list1 ενημερώθηκε σε " Settings.LIST1_PROB_PCT "%")
    }
    catch Error as eSld
    {
    }
  }

  ; -- ΣΤΑΘΕΡΟ FIX: σταθερή συμπεριφορά UpDown/Edit για χρόνο αναμονής --
  OnLoopMinutesChanged(ctrl, info := 0)
  {
    try
    {
      edtMin := this._wnd.GetControl("edtLoopMin")
      edtMax := this._wnd.GetControl("edtLoopMax")

      newMin := edtMin.Value + 0
      newMax := edtMax.Value + 0

      if (newMin < 1)
      {
        newMin := 1
      }
      if (newMax < 1)
      {
        newMax := 1
      }
      if (newMin > 25)
      {
        newMin := 25
      }
      if (newMax > 25)
      {
        newMax := 25
      }
      if (newMax < newMin)
      {
        newMax := newMin
      }

      edtMin.Value := newMin
      edtMax.Value := newMax

      Settings.LOOP_MIN_MS := newMin * 60000
      Settings.LOOP_MAX_MS := newMax * 60000

      this._logger.Write(
        Format(
          "🛠️ Διάστημα αναμονής: {1}–{2} λεπτά ({3}–{4} ms)",
          newMin,
          newMax,
          Settings.LOOP_MIN_MS,
          Settings.LOOP_MAX_MS
        )
      )
    }
    catch Error as eAll
    {
    }
  }
}
; ==================== End Of File ====================
