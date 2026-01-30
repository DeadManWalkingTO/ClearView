; ==================== submacros/main.ahk ====================
#Requires AutoHotkey v2.0
#SingleInstance Force
SetTitleMatchMode(2)
SetWorkingDir(A_ScriptDir)
; --- Includes ---
#Include ..\lib\settings.ahk
#Include ..\lib\regex.ahk
#Include ..\lib\edge.ahk
#Include ..\lib\flow.ahk
#Include ..\lib\log.ahk
#Include ..\lib\ui_window.ahk
#Include ..\lib\ui_controller.ahk
#Include ..\lib\video.ahk

; --- Bootstrap ---
try
{
  ; 1) Window + controls
  wnd := UiWindow()
  wnd.CreateWindow()
  wnd.AddControls()
  wnd.ShowWindow() ; ⬅️ Θέση/μέγεθος σταθεροποιούνται εδώ (bottom-right)

  ; 2) Services (controls -> Logger)
  txtLogCtrl := wnd.GetControl("txtLog")
  txtHeadCtrl := wnd.GetControl("txtHead")
  logInst := Logger(txtLogCtrl, txtHeadCtrl)
  edgeSvc := EdgeService(Settings.EDGE_EXE, Settings.EDGE_WIN_SEL)
  videoSvc := VideoService()
  flowCtl := FlowController(logInst, edgeSvc, videoSvc, Settings)

  ; 3) Controller: bind + events + show (boot logs)
  ui := UiController(wnd)
  ui.Bind(flowCtl, logInst)
  ui.WireEvents()
  ui.Show()

  ; 4) Υπολογισμός ορθογωνίου GUI (screen coords) και πέρασμα στον FlowController
  guiX := 0
  guiY := 0
  guiW := 0
  guiH := 0
  try
  {
    appGui := wnd.GetApp()
    appGui.GetPos(&guiX, &guiY, &guiW, &guiH)
  }
  catch Error as ePos
  {
    guiX := 0
    guiY := 0
    guiW := 0
    guiH := 0
  }
  try
  {
    flowCtl.SetGuiRect(guiX, guiY, guiW, guiH)
  }
  catch Error as eSet
  {
  }
}
catch Error as eBoot
{
  msg := "Σφάλμα εκκίνησης:" . "`n`n"
  try
  {
    msg .= "Message: " . eBoot.Message . "`n"
  }
  catch
  {
  }
  try
  {
    msg .= "What: " . eBoot.What . "`n"
  }
  catch
  {
  }
  try
  {
    msg .= "File: " . eBoot.File . "`n"
  }
  catch
  {
  }
  try
  {
    msg .= "Line: " . eBoot.Line . "`n"
  }
  catch
  {
  }
  MsgBox(msg, "Σφάλμα", "Iconx")
  ExitApp
}
; ==================== End Of File ====================
