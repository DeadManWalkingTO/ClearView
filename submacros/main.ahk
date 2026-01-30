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
#Include ..\lib\video.ahk  ; ⬅️ ΝΕΟ

; --- Bootstrap ---
try {
  ; 1) Window + controls
  wnd := UiWindow()
  wnd.CreateWindow()
  wnd.AddControls()
  wnd.ShowWindow()
  wnd.GuiReflow()
  wnd.WirePositioning()

  ; 2) Services (χρειάζονται τα controls για Logger)
  txtLogCtrl := wnd.GetControl("txtLog")
  txtHeadCtrl := wnd.GetControl("txtHead")
  logInst := Logger(txtLogCtrl, txtHeadCtrl)
  edgeSvc := EdgeService(Settings.EDGE_EXE, Settings.EDGE_WIN_SEL)
  videoSvc := VideoService()  ; ⬅️ ΝΕΟ
  flowCtl := FlowController(logInst, edgeSvc, videoSvc, Settings) ; ⬅️ pass video

  ; 3) Controller: bind + events + show
  ui := UiController(wnd)
  ui.Bind(flowCtl, logInst)
  ui.WireEvents()
  ui.Show()
} catch Error as _eBoot {
  MsgBox("Αποτυχία εκκίνησης.", "Σφάλμα", "Iconx")
  ExitApp
}
; ==================== End Of File ====================
