; ==================== lib/edge_profile.ahk ====================
#Requires AutoHotkey v2.0
#Include "settings.ahk"
#Include "regex.ahk"
#Include "edge.ahk"

; Δημόσια βοηθητική συνάρτηση:
; - Ανοίγει τον Microsoft Edge στο δοθέν URL
; - Με το ΙΔΙΟ προφίλ που χρησιμοποιεί η εφαρμογή (Settings.EDGE_PROFILE_NAME)
; - newWindow=true -> --new-window (προεπιλογή)
; - Εσωτερικά: προσπαθεί να επιλύσει τον φάκελο προφίλ (ResolveProfileDirByName)
;   και, αν αποτύχει, κάνει fallback στο εμφανιζόμενο όνομα.
StartEdgeWithAppProfile(url, newWindow := true)
{
  edgeExe := ""
  try {
    edgeExe := Settings.EDGE_EXE
  } catch {
    edgeExe := ""
  }

  if (edgeExe = "")
  {
    ; Fallback: άνοιγμα στο προεπιλεγμένο browser
    try {
      Run(url)
    } catch {
    }
    return
  }

  displayName := ""
  try {
    displayName := Settings.EDGE_PROFILE_NAME
  } catch {
    displayName := ""
  }

  profDir := ""
  try {
    edgeSvc := EdgeService(edgeExe, Settings.EDGE_WIN_SEL)
    profDir := edgeSvc.ResolveProfileDirByName(displayName)
  } catch {
    profDir := ""
  }

  profArg := ""
  if (profDir != "")
  {
    ; Χρήση φακέλου προφίλ
    try {
      profArg := "--profile-directory=" RegexLib.Str.Quote(profDir)
    } catch {
      profArg := "--profile-directory=" profDir
    }
  }
  else
  {
    ; Fallback: χρήση εμφανιζόμενου ονόματος ως profile-directory
    try {
      profArg := "--profile-directory=" RegexLib.Str.Quote(displayName)
    } catch {
      profArg := "--profile-directory=" displayName
    }
  }

  winArg := ""
  if (newWindow)
  {
    winArg := "--new-window"
  }

  cmd := ""
  try {
    if (winArg != "")
    {
      cmd := '"' edgeExe '" ' profArg ' ' winArg ' ' url
    }
    else
    {
      cmd := '"' edgeExe '" ' profArg ' ' url
    }
  } catch {
    cmd := '"' edgeExe '" ' url
  }

  try {
    Run(cmd)
  } catch {
  }
}
; ==================== End Of File ====================
