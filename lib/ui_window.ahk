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
    } catch Error {
      MsgBox("Αποτυχία δημιουργίας GUI.", "Σφάλμα", "Iconx")
      ExitApp
    }
    guiW := Settings.GUI_MIN_W + 0
    guiH := Settings.GUI_MIN_H + 0
    if (guiW < 200) {
      guiW := 200
    }
    if (guiH < 200) {
      guiH := 200
    }
    this._app.Opt("+MinSize" guiW "x" guiH)
    this._app.Opt("+MaxSize" guiW "x" guiH)
  }

  ; Προσθήκη controls με σταθερές συντεταγμένες
  AddControls()
  {
    try {
      c := this._controls

      ; --- Επάνω σειρά κουμπιών ---
      x := 12
      y := 12
      gap := 8
      c["btnStart"] := this._app.Add("Button", Format("x{1} y{2} w90 h28", x, y), "Έναρξη")
      c["btnPause"] := this._app.Add("Button", Format("x{1} y{2} w110 h28", x + 90 + gap, y), "Παύση")
      c["btnStop"] := this._app.Add("Button", Format("x{1} y{2} w90 h28", x + 90 + gap + 110 + gap, y), "Τερματισμός")
      c["btnCopy"] := this._app.Add("Button", Format("x{1} y{2} w110 h28", x + 90 + gap + 110 + gap + 90 + gap, y), "Αντιγραφή Log")
      c["btnClear"] := this._app.Add("Button", Format("x{1} y{2} w110 h28", x + 90 + gap + 110 + gap + 90 + gap + 110 + gap, y), "Καθαρισμός Log")
      c["btnExit"] := this._app.Add("Button", Format("x{1} y{2} w90 h28",
        x + 90 + gap + 110 + gap + 90 + gap + 110 + gap + 110 + gap, y), "Έξοδος")

      ; --- Ζώνη κάτω από τα κουμπιά ---
      secY := y + 28 + 10

      ; =========================================================
      ; Αριστερό Box: ΠΙΘΑΝΟΤΗΤΑ επιλογής list1 (%) — compact
      ; =========================================================
      probGbX := 12
      probGbY := secY - 8                   ; ελαφρύ «σήκωμα» για τον τίτλο
      probGbW := 238                        ; στενό: 10 + 150 + 8 + ~60 + 10
      probGbH := 62

      c["gbProb"] := this._app.Add(
        "GroupBox",
        Format("x{1} y{2} w{3} h{4}", probGbX, probGbY, probGbW, probGbH),
        "Πιθανότητα επιλογής list1 (%)"
      )

      ; Εσωτερικά paddings
      probPadL := 10
      probPadT := 24

      ; Slider μέσα στο box (150px πλάτος)
      c["sldProb"] := this._app.Add(
        "Slider",
        Format("x{1} y{2} w150 Range0-100 TickInterval10",
          probGbX + probPadL, probGbY + probPadT),
        Settings.LIST1_PROB_PCT
      )

      ; Ετικέτα τιμής (στην ίδια γραμμή δεξιά από τον slider)
      c["lblProb"] := this._app.Add(
        "Text",
        Format("x{1} y{2}", probGbX + probPadL + 150 + 8, probGbY + probPadT),
        "list1: " Settings.LIST1_PROB_PCT "%"
      )

      ; =========================================================
      ; Μεσαίο Box: ΔΙΑΣΤΗΜΑ (λεπτά) — ΑΚΟΜΗ πιο compact
      ; =========================================================
      colGap := 8                            ; μικρό κενό ανάμεσα στα boxes
      loopGbX := probGbX + probGbW + colGap
      loopGbY := probGbY
      loopGbW := 148                         ; χωράει τα 2 πεδία + «έως»
      loopGbH := 62

      c["gbLoop"] := this._app.Add(
        "GroupBox",
        Format("x{1} y{2} w{3} h{4}", loopGbX, loopGbY, loopGbW, loopGbH),
        "Διάστημα (λεπτά)"
      )

      ; Εσωτερικό padding
      padL := 10
      padT := 24

      ; --- Ελάχιστο (Edit + UpDown) ---
      c["edtLoopMin"] := this._app.Add(
        "Edit",
        Format("x{1} y{2} w40 Limit2", loopGbX + padL, loopGbY + padT)
      )
      c["udLoopMin"] := this._app.Add("UpDown", "Range1-25", this._getInitMinMinutes())

      ; --- "έως" (gap: 6 px) ---
      c["txtLoopTo"] := this._app.Add(
        "Text",
        Format("x{1} y{2}", loopGbX + padL + 40 + 6, loopGbY + padT + 2),
        "έως"
      )

      ; --- Μέγιστο (Edit + UpDown) ---
      c["edtLoopMax"] := this._app.Add(
        "Edit",
        Format("x{1} y{2} w40 Limit2", loopGbX + padL + 40 + 6 + 26 + 6, loopGbY + padT)
      )
      c["udLoopMax"] := this._app.Add("UpDown", "Range1-25", this._getInitMaxMinutes())

      ; =========================================================
      ; Δεξί Box: ΕΓΚΑΤΑΣΤΑΣΗ — 4 κουμπιά ("1", "2", "3", "4")
      ; =========================================================
      instGbX := loopGbX + loopGbW + colGap
      instGbY := probGbY
      ; Υπολογισμός πλάτους για 4 κουμπιά: 10 + (4*40) + (3*6) + 10 = 198
      instGbW := 198
      instGbH := 62

      c["gbInstall"] := this._app.Add(
        "GroupBox",
        Format("x{1} y{2} w{3} h{4}", instGbX, instGbY, instGbW, instGbH),
        "Εγκατάσταση"
      )

      instPadL := 10
      instPadT := 24
      btnW := 40
      btnH := 28
      btnGap := 6

      ; Κουμπί "1"
      c["btnInst1"] := this._app.Add(
        "Button",
        Format("x{1} y{2} w{3} h{4}",
          instGbX + instPadL, instGbY + instPadT, btnW, btnH),
        "1"
      )
      ; Κουμπί "2"
      c["btnInst2"] := this._app.Add(
        "Button",
        Format("x{1} y{2} w{3} h{4}",
          instGbX + instPadL + (btnW + btnGap) * 1, instGbY + instPadT, btnW, btnH),
        "2"
      )
      ; Κουμπί "3"
      c["btnInst3"] := this._app.Add(
        "Button",
        Format("x{1} y{2} w{3} h{4}",
          instGbX + instPadL + (btnW + btnGap) * 2, instGbY + instPadT, btnW, btnH),
        "3"
      )
      ; Κουμπί "4"
      c["btnInst4"] := this._app.Add(
        "Button",
        Format("x{1} y{2} w{3} h{4}",
          instGbX + instPadL + (btnW + btnGap) * 3, instGbY + instPadT, btnW, btnH),
        "4"
      )

      ; =========================================================
      ; Headline — ευθυγραμμισμένο με το κείμενο του log
      ; =========================================================
      ; Το head κάθεται κάτω από το χαμηλότερο σημείο των 3 boxes
      headY := probGbY + probGbH
      if (loopGbY + loopGbH > headY) {
        headY := loopGbY + loopGbH
      }
      if (instGbY + instGbH > headY) {
        headY := instGbY + instGbH
      }
      headY := headY + 8

      headX := 12
      headW := Settings.GUI_MIN_W - 24
      c["txtHead"] := this._app.Add(
        "Text",
        Format("x{1} y{2} w{3} h20 cBlue", headX, headY, headW),
        "Έτοιμο. " Settings.APP_VERSION
      )

      ; --- Περιοχή Log (κάτω από το head) ---
      topLog := headY + 20 + 6
      logW := Settings.GUI_MIN_W - 24
      logH := Settings.GUI_MIN_H - (topLog + 20 + 12)
      if (logW < 200) {
        logW := 200
      }
      if (logH < 0) {
        logH := 0
      }
      c["txtLog"] := this._app.Add(
        "Edit",
        Format("x{1} y{2} w{3} h{4} ReadOnly Multi -Wrap +VScroll",
          12, topLog, logW, logH),
        ""
      )

      ; Μηδενισμός αριστερού/δεξιού margin στο Edit ώστε να συμπέσει ακριβώς με το head
      try {
        hwndLog := c["txtLog"].Hwnd
      } catch {
        hwndLog := 0
      }
      if (hwndLog != 0) {
        EM_SETMARGINS := 0x00D3
        EC_LEFTMARGIN := 0x1
        EC_RIGHTMARGIN := 0x2
        DllCall("user32\SendMessage", "ptr", hwndLog, "uint", EM_SETMARGINS, "ptr", EC_LEFTMARGIN | EC_RIGHTMARGIN, "ptr", 0)
      }

      c["helpLine"] := this._app.Add(
        "Text",
        Format("x{1} y{2} w{3} h20 cGray", 12, (topLog + logH + 6), logW),
        "Η εύρεση διάρκειας έχει αφαιρεθεί πλήρως."
      )

      ; Buddy linking
      c["udLoopMin"].Buddy := c["edtLoopMin"]
      c["udLoopMax"].Buddy := c["edtLoopMax"]

    } catch Error as eControls {
      MsgBox("Αποτυχία σύνθεσης στοιχείων GUI.`n`n" eControls.Message, "Σφάλμα", "Iconx")
      ExitApp
    }
  }

  ShowWindow()
  {
    try {
      this._app.Show("w" Settings.GUI_MIN_W " h" Settings.GUI_MIN_H)
      this._positionBottomRightOnce(this._br_margin)
    } catch Error {
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
    } catch Error {
    }
  }

  _getInitMinMinutes()
  {
    try {
      init := Floor((Settings.LOOP_MIN_MS + 0) / 60000)
      if (init > 0) {
        return init
      }
    } catch {
    }
    return Settings.LOOP_MIN_MINUTES + 0
  }

  _getInitMaxMinutes()
  {
    try {
      init := Floor((Settings.LOOP_MAX_MS + 0) / 60000)
      if (init > 0) {
        return init
      }
    } catch {
    }
    return Settings.LOOP_MAX_MINUTES + 0
  }

  GetApp() => this._app
  GetControls() => this._controls
  GetControl(name)
  {
    try {
      if this._controls.Has(name) {
        return this._controls[name]
      }
    } catch {
    }
    return 0
  }
}
; ==================== End Of File ====================
