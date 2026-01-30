; ==================== lib/ui_window.ahk ====================
#Requires AutoHotkey v2.0
#Include "settings.ahk"

class UiWindow
{
  __New()
  {
    this._app := 0
    this._controls := Map()
    this._br_margin := 10
  }

  ; Δημιουργία παραθύρου με σταθερό μέγεθος (fixed) & AlwaysOnTop
  CreateWindow()
  {
    AppTitle := Settings.APP_TITLE " — " Settings.APP_VERSION

    try {
      this._app := Gui("+AlwaysOnTop -Resize -MaximizeBox", AppTitle)
      this._app.SetFont("s10", "Segoe UI")
    }
    catch Error {
      MsgBox("Αποτυχία δημιουργίας GUI.", "Σφάλμα", "Iconx")
      ExitApp
    }

    guiW := Settings.GUI_MIN_W + 0
    guiH := Settings.GUI_MIN_H + 0

    if (guiW < 200)
      guiW := 200
    if (guiH < 200)
      guiH := 200

    this._app.Opt("+MinSize" guiW "x" guiH)
    this._app.Opt("+MaxSize" guiW "x" guiH)
  }

  ; Προσθήκη controls με σταθερές συντεταγμένες
  AddControls()
  {
    try
    {
      c := this._controls

      ; --- Επάνω σειρά κουμπιών ---
      x := 12
      y := 12
      gap := 8

      c["btnStart"] := this._app.Add("Button", Format("x{} y{} w90 h28", x, y), "Έναρξη")
      c["btnPause"] := this._app.Add("Button", Format("x{} y{} w110 h28", x + 90 + gap, y), "Παύση")
      c["btnStop"] := this._app.Add("Button", Format("x{} y{} w90 h28", x + 90 + gap + 110 + gap, y), "Τερματισμός")
      c["btnCopy"] := this._app.Add("Button", Format("x{} y{} w110 h28", x + 90 + gap + 110 + gap + 90 + gap, y), "Αντιγραφή Log")
      c["btnClear"] := this._app.Add("Button", Format("x{} y{} w110 h28", x + 90 + gap + 110 + gap + 90 + gap + 110 + gap, y), "Καθαρισμός Log")
      c["btnExit"] := this._app.Add("Button", Format("x{} y{} w90 h28",
        x + 90 + gap + 110 + gap + 90 + gap + 110 + gap + 110 + gap, y), "Έξοδος")

      ; --- Ενότητα Prob & Loop ---
      secY := y + 28 + 10

      c["txtProbTitle"] := this._app.Add("Text",
        Format("x{} y{} w300", 12, secY),
        "Πιθανότητα επιλογής list1 (%)")

      c["sldProb"] := this._app.Add("Slider",
        Format("x{} y{} w150 Range0-100 TickInterval10", 12, secY + 28),
        Settings.LIST1_PROB_PCT)

      c["lblProb"] := this._app.Add("Text",
        Format("x{} y{}", 12 + 150 + 8, secY + 28),
        "list1: " Settings.LIST1_PROB_PCT "%")

      loopBaseX := 12 + 150 + 8 + 70 + 14
      loopBaseY := secY + 28

      c["txtLoopTitle"] := this._app.Add("Text",
        Format("x{} y{}", loopBaseX, loopBaseY),
        "Διάστημα (λεπτά):")

      c["edtLoopMin"] := this._app.Add("Edit",
        Format("x{} y{} w40 Limit2", loopBaseX + 120 + 6, loopBaseY))

      c["udLoopMin"] := this._app.Add("UpDown", "Range1-25", this._getInitMinMinutes())

      c["txtLoopTo"] := this._app.Add("Text",
        Format("x{} y{}", loopBaseX + 120 + 6 + 40 + 6 + 16, loopBaseY),
        "έως")

      c["edtLoopMax"] := this._app.Add("Edit",
        Format("x{} y{} w40 Limit2",
          loopBaseX + 120 + 6 + 40 + 6 + 16 + 26 + 6, loopBaseY))

      c["udLoopMax"] := this._app.Add("UpDown", "Range1-25", this._getInitMaxMinutes())

      ; --- Επικεφαλίδα ---
      headY := loopBaseY + 24 + 10
      c["txtHead"] := this._app.Add(
        "Text",
        Format("x{} y{} w640 h24", 12, headY),
        "Έτοιμο. " Settings.APP_VERSION
      )

      ; --- Περιοχή Log ---
      topLog := headY + 24 + 6
      logW := Settings.GUI_MIN_W - 24
      logH := Settings.GUI_MIN_H - (topLog + 20 + 12)

      if (logW < 200)
        logW := 200
      if (logH < 0)
        logH := 0

      c["txtLog"] := this._app.Add(
        "Edit",
        Format("x{} y{} w{} h{} ReadOnly Multi -Wrap +VScroll",
          12, topLog, logW, logH),
        ""
      )

      c["helpLine"] := this._app.Add(
        "Text",
        Format("x{} y{} w{} h20 cGray",
          12, (topLog + logH + 6), logW),
        "Η εύρεση διάρκειας έχει αφαιρεθεί πλήρως."
      )

      ; UpDown buddy-linking (ΣΩΣΤΟ)
      c["udLoopMin"].Buddy := c["edtLoopMin"]
      c["udLoopMax"].Buddy := c["edtLoopMax"]

      ; ❌ Καμία SetRange εδώ (AHK v2 δεν υποστηρίζει SetRange)
    }
    catch Error as eControls
    {
      MsgBox("Αποτυχία σύνθεσης στοιχείων GUI.`n`n" eControls.Message, "Σφάλμα", "Iconx")
      ExitApp
    }
  }

  ShowWindow()
  {
    try {
      this._app.Show("w" Settings.GUI_MIN_W " h" Settings.GUI_MIN_H)
      this._positionBottomRightOnce(this._br_margin)
    }
    catch Error {
    }
  }

  _positionBottomRightOnce(margin := 10)
  {
    try {
      monIdx := MonitorGetPrimary()
      MonitorGetWorkArea(monIdx, &waL, &waT, &waR, &waB)
      this._app.GetPos(, , &W, &H)
      x := waR - W - margin
      y := waB - H - margin
      this._app.Move(x, y)
    }
    catch Error {
    }
  }

  _getInitMinMinutes()
  {
    try {
      init := Floor((Settings.LOOP_MIN_MS + 0) / 60000)
      if (init > 0)
        return init
    }
    catch {

    }
    return Settings.LOOP_MIN_MINUTES + 0
  }

  _getInitMaxMinutes()
  {
    try {
      init := Floor((Settings.LOOP_MAX_MS + 0) / 60000)
      if (init > 0)
        return init
    }
    catch {

    }
    return Settings.LOOP_MAX_MINUTES + 0
  }

  GetApp() => this._app
  GetControls() => this._controls

  GetControl(name)
  {
    try {
      if this._controls.Has(name)
        return this._controls[name]
    }
    catch {

    }
    return 0
  }
}
; ==================== End Of File ====================
