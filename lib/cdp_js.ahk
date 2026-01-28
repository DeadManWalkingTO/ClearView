; ==================== lib/cdp_js.ahk ====================
#Requires AutoHotkey v2.0
#Include "regex.ahk"

; -----------------------------------------------------------------------------
; CDP JavaScript expressions (modularized)
; -----------------------------------------------------------------------------
; Σκοπός: Να παρέχει έτοιμα JS snippets για χρήση με Runtime.evaluate στο CDP.
; Χρησιμοποιούμε helpers από RegexLib για ασφαλή σύνθεση strings όπου χρειάζεται.
; -----------------------------------------------------------------------------

/**
 * Επιστρέφει JS expression που υπολογίζει τη διάρκεια YouTube βίντεο (σε δευτερόλεπτα).
 * Λογική:
 *  - Διαβάζει το textContent της '.ytp-time-duration'
 *  - Κάνει split με ':' και μετατρέπει σε αριθμούς
 *  - Υπολογίζει συνολικά δευτερόλεπτα (hh:mm:ss | mm:ss | ss)
 *  - Αν δεν βρεθεί έγκυρη διάρκεια, επιστρέφει -1
 * 
 * Προσοχή: Το expression είναι αυτοτελές IIFE και επιστρέφει numeric result.
 */
CDP_JS_GetYouTubeDurationExpr() {
  ; Επιστρέφουμε καθαρό expression μέσω continuation section για αναγνωσιμότητα.
  ; Δεν περιέχει ωμά backslash escaping—παραμένει απλό JS κείμενο.
  return "
  ( Join`n
  (() => {
    const el = document.querySelector('.ytp-time-duration');
    const t = el?.textContent ?? '';
    const s = (t || '').trim();
    if (!s) return -1;
    const parts = s.split(':').map(x => Number((x || '').trim()));
    if (parts.length === 0 || parts.some(n => Number.isNaN(n))) return -1;
    let total = 0;
    if (parts.length === 3) {
      total = parts[0] * 3600 + parts[1] * 60 + parts[2];
    } else if (parts.length === 2) {
      total = parts[0] * 60 + parts[1];
    } else {
      total = parts[0];
    }
    return total;
  })();
  )"
}

/**
 * (Προαιρετικό) JS expression για «κλικ» στο play button του YouTube player.
 * Χρήσιμο ως fallback όταν το keyboard 'k' δεν ανταποκρίνεται.
 * Επιστρέφει true αν εκτελέστηκε η ενέργεια, αλλιώς false.
 */
CDP_JS_ClickPlayButtonExpr() {
  return "
  ( Join`n
  (() => {
    const btn = document.querySelector('.ytp-play-button');
    if (!btn) return false;
    btn.click();
    return true;
  })();
  )"
}

/**
 * (Προαιρετικό) JS expression για unmute + μικρή αύξηση έντασης (ορατό σε μερικά περιβάλλοντα).
 * Επιστρέφει true αν έγινε προσπάθεια, αλλιώς false.
 */
CDP_JS_UnmuteRaiseVolumeExpr() {
  return "
  ( Join`n
  (() => {
    try {
      const video = document.querySelector('video');
      if (!video) return false;
      video.muted = false;
      video.volume = Math.min(1, (video.volume || 0.2) + 0.05);
      return true;
    } catch (e) {
      return false;
    }
  })();
  )"
}
; ==================== End Of File ====================
