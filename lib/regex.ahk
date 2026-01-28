; ==================== lib/regex.ahk ====================
#Requires AutoHotkey v2.0

; Βιβλιοθήκη βοηθητικών regex για όλο το project.
; Στόχος: συγκέντρωση των RegExMatch/RegExReplace ώστε οι μεταφορές κώδικα
; να μην σπάνε από διάσπαρτα regex patterns.

class RegexLib {
    ; Ασφαλές regex-escape (για δυναμικά strings όπως displayName)
    static Escape(str) {
        return RegExReplace(str, "([\.\^\$\*\+\?\(\)\\\[\]\{\}\|\-])", "\\$1")
    }

    ; Εξαγωγή φακέλου προφίλ από το "Local State" (πεδίο profile.info_cache)
    ; Επιστρέφει: dir (π.χ. "Profile 3" ή "Default") ή "" αν δεν βρεθεί.
    static FindProfileDirInLocalState(localStateText, displayName) {
        if (localStateText == "")
            return ""
        ; Εντοπισμός του block "info_cache"
        pat := '"profile"\s*:\s*\{\s*"info_cache"\s*:\s*\{([\s\S]*?)\}\s*\}'
        if !RegExMatch(localStateText, pat, &m)
            return ""
        cache := m[1], pos := 1
        escName := RegexLib.Escape(displayName)
        ; Αναζήτηση αντικειμένων: "dir": { ..."name": "nm"... }
        while RegExMatch(cache, '"([^"]+)"\s*:\s*\{[^\}]*"name"\s*:\s*"([^"]+)"', &mm, pos) {
            dir := mm[1], nm := mm[2]
            if (nm == displayName)
                return dir
            pos := mm.Pos(0) + mm.Len(0)
        }
        return ""
    }

    ; Έλεγχος αν το Preferences ενός profile περιέχει το εμφανιζόμενο όνομα displayName
    ; Επιστρέφει: true/false
    static PreferencesContainsProfileName(prefsText, displayName) {
        if (prefsText == "")
            return false
        escName := RegexLib.Escape(displayName)
        ; 1) μέσα στο αντικείμενο "profile": {... "name": "displayName" ...}
        if RegExMatch(prefsText, '"profile"\s*:\s*\{[^\}]*"name"\s*:\s*"' escName '"')
            return true
        ; 2) γενικό "name": "displayName"
        if RegExMatch(prefsText, '"name"\s*:\s*"' escName '"')
            return true
        return false
    }

    ; Έλεγχος αν ένα όνομα φακέλου είναι τύπου "Profile N"
    static IsProfileFolderName(name) {
        return RegExMatch(name, "^Profile\s+\d+$") ? true : false
    }
}
; ==================== End Of File ====================
