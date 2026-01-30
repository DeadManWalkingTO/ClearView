; ==================== lib/flow.ahk ====================
#Requires AutoHotkey v2.0
#Include "settings.ahk"
#Include "regex.ahk"
#Include "edge.ahk"
#Include "video.ahk"
#Include "moves.ahk" ; για χρήση MoveMouseRandom4

class FlowController {
    __New(log, edge, video, settings) {
        this.log := log
        this.edge := edge
        this.video := video
        this.settings := settings
        this._running := false
        this._paused := false
        this._stopRequested := false
        this._cycleCount := 0
        this.list1 := []
        this.list2 := []

        ; ορθογώνιο GUI για αποκλεισμό sampling
        this.guiX := 0
        this.guiY := 0
        this.guiW := 0
        this.guiH := 0
    }

    IsRunning() => this._running

    ; Setter για GUI rect (screen coords)
    SetGuiRect(x, y, w, h) {
        try {
            this.guiX := x + 0
        } catch Error as _e1 {
            this.guiX := 0
        }
        try {
            this.guiY := y + 0
        } catch Error as _e2 {
            this.guiY := 0
        }
        try {
            this.guiW := w + 0
        } catch Error as _e3 {
            this.guiW := 0
        }
        try {
            this.guiH := h + 0
        } catch Error as _e4 {
            this.guiH := 0
        }
        try {
            if (this.log) {
                this.log.Write(Format("🧭 GUI rect set: x={1} y={2} w={3} h={4}", this.guiX, this.guiY, this.guiW, this.guiH))
            }
        } catch Error as _e5 {
        }
    }

    LoadIdLists() {
        this.list1 := this._readIdsFromFile(Settings.DATA_LIST_TXT)
        this.list2 := this._readIdsFromFile(Settings.DATA_RANDOM_TXT)
        try {
            this.log.Write(Format("📥 Φόρτωση λιστών: list1={1}", this.list1.Length))
            this.log.Write(Format("📥 Φόρτωση λιστών: list2={1}", this.list2.Length))
        } catch Error as _e {
        }
        if (this.list1.Length = 0) {
            if (this.list2.Length = 0) {
                try {
                    ; Παλαιό: SetHeadline("❌ Σφάλμα: Άδειες λίστες") → αφαιρείται
                    this.log.Write("❌ Και οι 2 λίστες είναι άδειες – η ροή σταματάει.")
                } catch Error as _e2 {
                }
                throw Error("Empty lists – abort")
            }
        }
    }

    StartRun() {
        if this._running {
            try {
                ; Παλαιό: SetHeadline("ℹ️ Ήδη Εκτελείται.") → αφαιρείται
                this.log.Write("ℹ️ Αγνοήθηκε")
            } catch Error as _eStartAlready {
            }
            return
        }

        this._running := true
        this._paused := false
        this._stopRequested := false
        this._cycleCount := 0

        ; Φόρτωση λιστών πριν τη ροή
        this.LoadIdLists()

        try {
            this.log.ShowTimed(
                "Έναρξη",
                Format("Ξεκινάει η ροή αυτοματισμού — έκδοση: {1}", Settings.APP_VERSION),
                "BH Automation — Έναρξη",
                "Iconi"
            )
            ; Παλαιό: SetHeadline("▶️ Εκκίνηση Ροής…") → αφαιρείται
            this.log.Write(Format("▶️ Έναρξη Πατήθηκε — {1}", Settings.APP_VERSION))
        } catch Error as _eShow {
        }

        try {
            this._run()
        } catch Error as eRun {
            try {
                this.log.Write(Format("❌ Σφάλμα Ροής: {1} — What={2}, File={3}, Line={4}", eRun.Message, eRun.What, eRun.File, eRun.Line))
                ; Παλαιό: SetHeadline(Format("❌ Σφάλμα: {1}", eRun.Message)) → αφαιρείται
            } catch Error as _eLog {
            }
        }

        this._running := false
        this._paused := false
        this._stopRequested := false

        try {
            ; Παλαιό: SetHeadline("✅ Έτοιμο.") → αφαιρείται
            this.log.Write("✨ Ροή Ολοκληρώθηκε / Διακόπηκε")
        } catch Error as _eEnd {
        }
    }

    TogglePause() {
        if !this._running
            return false
        this._paused := !this._paused
        return this._paused
    }

    RequestStop() {
        this._stopRequested := true
    }

    _run() {
        local profDir := "", profArg := "", hNew := 0

        this._checkAbortOrPause()

        ; Εύρεση φακέλου προφίλ
        try {
            ; Παλαιό: SetHeadline("🔎 Εύρεση Φακέλου Προφίλ…") → αντικατάσταση με Write
            this.log.Write(Format("🔎 Εύρεση Φακέλου Προφίλ Με Βάση Το Όνομα: {1}", Settings.EDGE_PROFILE_NAME))
        } catch Error as _eL1 {
        }

        profDir := this.edge.ResolveProfileDirByName(Settings.EDGE_PROFILE_NAME)

        if (profDir = "") {
            try {
                ; Παλαιό: SetHeadline("⚠️ Δεν Βρέθηκε Φάκελος Για: {name}") → αφαιρείται
                this.log.Write("⚠️ Ο Φάκελος Προφίλ Δεν Βρέθηκε — Θα Δοκιμάσω Με Χρήση Του Εμφανιζόμενου Ονόματος Ως Φάκελο")
            } catch Error as _eWarn1 {
            }
            profArg := "--profile-directory=" RegexLib.Str.Quote(Settings.EDGE_PROFILE_NAME)
            quotedName := RegexLib.Str.Quote(Settings.EDGE_PROFILE_NAME)
            warnMsg := Format("Δεν βρέθηκε φάκελος προφίλ για {1}. Θα δοκιμάσω με: {2}", quotedName, profArg)
            try {
                this.log.ShowTimed("Προειδοποίηση Προφίλ", warnMsg, "BH Automation — Προειδοποίηση", "Iconi")
            } catch Error as _eWarnPopup {
            }
        } else {
            try {
                ; Παλαιό: SetHeadline("📁 Βρέθηκε Φάκελος: {profDir}") → αφαιρείται
                this.log.Write(Format("📁 Φάκελος Προφίλ: {1}", profDir))
            } catch Error as _eL2 {
            }
            profArg := "--profile-directory=" RegexLib.Str.Quote(profDir)
        }

        profArg .= " --new-window"
        this.edge.StepDelay()
        this.edge.StepDelay()
        this._checkAbortOrPause()

        try {
            ; Παλαιό: SetHeadline("⏩ Άνοιγμα Νέου Παραθύρου Edge…") → αφαιρείται
            this.log.Write(Format("⏩ Edge New Window: {1}", profArg))
        } catch Error as _eL3 {
        }

        ; Άνοιγμα νέου παραθύρου
        hNew := this.edge.OpenNewWindow(profArg)
        if (!hNew) {
            try {
                ; Παλαιό: SetHeadline("❌ Αποτυχία Ανοίγματος Edge.") → αφαιρείται
                this.log.Write("❌ Αποτυχία Ανοίγματος Νέου Παραθύρου Edge")
            } catch Error as _eL4 {
            }
            return
        }

        ; Καθυστέρηση MID_DELAY_MS μετά το Edge New Window
        try {
            this.log.SleepWithLog(Settings.MID_DELAY_MS, "μετά το Edge New Window")
        } catch Error as _eAfterOpen {
        }

        ; Προετοιμασία παραθύρου
        WinActivate("ahk_id " hNew)
        WinWaitActive("ahk_id " hNew, , 5)
        WinMaximize("ahk_id " hNew)
        Sleep(200)
        this.edge.StepDelay()

        try {
            quotedName := RegexLib.Str.Quote(Settings.EDGE_PROFILE_NAME)
            readyMsg := Format("Edge έτοιμο για χρήση ({1}).", quotedName)
            ; Παλαιό: SetHeadline(Format("✅ Edge Έτοιμο ({1})", name)) → αφαιρείται
            this.log.Write("✅ Edge Ready")
            this.log.ShowTimed("EdgeReady", readyMsg, "BH Automation — Edge", "Iconi")
        } catch Error as _eL5 {
        }

        this.edge.StepDelay()
        this.edge.NewTab(hNew)
        try {
            ; Παλαιό: SetHeadline("➡️ Νέα Καρτέλα Ανοιχτή") → αφαιρείται
            this.log.Write("➡️ Νέα Καρτέλα (Κενή)")
        } catch Error as _eL6 {
        }

        this.edge.CloseOtherTabsInNewWindow(hNew)
        try {
            this.log.Write("🧹 Καθαρισμός tabs: έκλεισα την άλλη καρτέλα στο νέο παράθυρο (παραμένει η τρέχουσα).")
        } catch Error as _eL7 {
        }

        ; Καθυστέρηση MID_DELAY_MS μετά τον καθαρισμό tabs
        try {
            this.log.SleepWithLog(Settings.MID_DELAY_MS, "μετά τον καθαρισμό tabs")
        } catch Error as _eAfterClean {
        }

        if (Settings.CLOSE_ALL_OTHER_WINDOWS) {
            this.edge.CloseAllOtherWindows(hNew)
            try {
                this.log.Write("🛠️ Κλείσιμο άλλων παραθύρων: ολοκληρώθηκε (CLOSE_ALL_OTHER_WINDOWS=true).")
            } catch Error as _eL8 {
            }
        }

        ; ενημερωτικό log για αποκλεισμό GUI κατά το sampling
        try {
            if (this.guiW > 0) {
                if (this.guiH > 0) {
                    this.log.Write(Format("🧭 Ενεργός αποκλεισμός GUI στο sampling: x={1} y={2} w={3} h={4}", this.guiX, this.guiY, this.guiW, this.guiH))
                }
            }
        } catch Error as _eLogGui {
        }

        ; =========================
        ; 🔁 Continuous loop
        ; =========================
        try {
            loop {
                this._checkAbortOrPause()
                this._cycleCount += 1
                cycleNo := this._cycleCount
                startTs := FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss")

                ; Παλαιό: μόνο SetHeadline("🔄 Κύκλος #...") → γίνεται Write
                try {
                    this.log.Write(Format("🔄 Κύκλος #{1} σε εξέλιξη…", cycleNo))
                } catch Error as _eHead {
                }

                info := this._pickRandomVideo(hNew)
                try {
                    lst := "list?"
                    try {
                        if (info.useList1) {
                            lst := "list1"
                        } else {
                            lst := "list2"
                        }
                    } catch Error as _eLs {
                        lst := "list?"
                    }
                    this.log.Write(Format("📑 Κύκλος #{1} — {2}", cycleNo, lst))
                    this.log.Write(Format("🔢 rand={1} prob={2}%", info.r, info.prob))
                    this.log.Write(Format("🔖 ID: {1} 🕒 start={2}", info.id, startTs))
                    this.log.Write(Format("🌐 Πλοήγηση σε: {1}", info.url))
                } catch Error as _eInfo {
                }

                this.edge.NavigateToUrl(hNew, info.url)
                try {
                    this.log.SleepWithLog(Settings.STEP_DELAY_MS, "μετά την πλοήγηση")
                } catch Error as _eSleep1 {
                }

                ; One-shot δράση μόνο στην 1η επανάληψη
                if (cycleNo = 1) {
                    local cX := 0, cY := 0, cW := 0, cH := 0
                    try {
                        WinGetClientPos(&cX, &cY, &cW, &cH, "ahk_id " hNew)
                    } catch Error as _eCli {
                        cX := 0, cY := 0, cW := 0, cH := 0
                    }
                    if (cW > 0) {
                        local cx := 0, cy := 0
                        try {
                            cx := cX + Floor(cW * 0.50)
                            cy := cY + Floor(cH * 0.50)
                        } catch Error as _eC {
                            cx := cX
                            cy := cY
                        }
                        try {
                            MoveMouseRandom4(cx, cy)
                        } catch Error as _eMv {
                        }
                        Sleep(80)
                        try {
                            Click(cx, cy)
                        } catch Error as _eClk {
                        }
                        try {
                            this.log.Write("🖱️ First-run: MoveMouseRandom4 + Click στο κέντρο (μετά την πλοήγηση).")
                        } catch Error as _eLogFR {
                        }
                    }
                }

                ok := false
                ; περνάμε το GUI rect στο EnsurePlaying
                try {
                    ok := this.video.EnsurePlaying(hNew, this.log, this.guiX, this.guiY, this.guiW, this.guiH)
                } catch Error as _eEns {
                    ok := false
                }

                if ok {
                    try {
                        this.log.Write("🎵 Το βίντεο παίζει.")
                    } catch Error as _eOk {
                    }
                } else {
                    try {
                        this.log.Write("⛔ Το βίντεο ΔΕΝ παίζει.")
                    } catch Error as _eNo {
                    }
                }

                ; Αναμονή μετά το detection
                try {
                    this.log.SleepWithLog(Settings.STEP_DELAY_MS, "μετά το detection")
                } catch Error as _eSleep2 {
                }

                ; Δεύτερος έλεγχος για false positive
                ok2 := false
                try {
                    ok2 := this.video.IsPlaying(hNew, this.log, this.guiX, this.guiY, this.guiW, this.guiH)
                } catch Error as _eRecheck {
                    ok2 := false
                }

                if (!ok2) {
                    try {
                        this.log.Write("⚠️ Μετά την αναμονή: δεν ανιχνεύεται κίνηση — πιθανό false positive. Προσπάθεια ανάκτησης…")
                    } catch Error as _eWarnFP {
                    }
                    recOk := false
                    try {
                        recOk := this.video.EnsurePlaying(hNew, this.log, this.guiX, this.guiY, this.guiW, this.guiH)
                    } catch Error as _eRec {
                        recOk := false
                    }
                    if (recOk) {
                        try {
                            this.log.Write("✅ Ανάκτηση επιτυχής μετά το false positive.")
                        } catch Error as _eRecOk {
                        }
                    } else {
                        try {
                            this.log.Write("❌ Αποτυχία ανάκτησης μετά το false positive.")
                        } catch Error as _eRecFail {
                        }
                    }
                } else {
                    try {
                        this.log.Write("✅ Επιβεβαίωση: το βίντεο συνεχίζει να παίζει μετά την αναμονή.")
                    } catch Error as _eOk2 {
                    }
                }

                ; Συνέχεια ροής
                waitMs := this._computeRandomWaitMs()
                try {
                    this.log.Write(Format("⏳ Αναμονή ακριβώς {1} ms ({2}) — κύκλος #{3}", waitMs, this._fmtDurationMs(waitMs), cycleNo))
                    ; Παλαιό: SetHeadline("⏳ Αναμονή ...") → αφαιρείται
                } catch Error as _eHead2 {
                }

                this._sleepRespectingPauseStop(waitMs, "αναμονή μεταξύ βίντεο")

                try {
                    this.log.Write(Format("🟢 Τέλος Κύκλου #{1}", cycleNo))
                    ; Παλαιό: SetHeadline("🟢 Τέλος Κύκλου ...") → αφαιρείται
                } catch Error as _eEndCyc {
                }
            }
        } catch Error as _eLoopBreak {
        }

        if (!Settings.KEEP_EDGE_OPEN) {
            WinClose("ahk_id " hNew)
            WinWaitClose("ahk_id " hNew, , 5)
            this.edge.StepDelay()
            try {
                ; Παλαιό: SetHeadline("✨ Κύκλος Ολοκληρώθηκε.") → αφαιρείται
                this.log.Write("✨ Ολοκλήρωση Κύκλου")
            } catch Error as _eLogEnd1 {
            }
        } else {
            try {
                ; Παλαιό: SetHeadline("✨ Κύκλος Ολοκληρώθηκε (Edge Παραμένει Ανοιχτός).") → αφαιρείται
                this.log.Write("✨ Ολοκλήρωση Κύκλου (Παραμονή Παραθύρου)")
            } catch Error as _eLogEnd2 {
            }
        }
    }

    ; =====================================================
    ; Helpers (όπως στο αρχικό)
    ; =====================================================

    _readIdsFromFile(path) {
        arr := []
        txt := ""
        try {
            txt := FileRead(path, "UTF-8")
        } catch Error as _eR {
            txt := ""
        }
        if (txt != "") {
            txt := StrReplace(txt, "`r")
            for line in StrSplit(txt, "`n") {
                id := Trim(line)
                if (id != "") {
                    arr.Push(id)
                }
            }
        }
        return arr
    }

    _pickRandomVideo(hWnd) {
        prob := Settings.LIST1_PROB_PCT
        r := Random(0, 100)
        useList1 := (r < prob)
        sel := (useList1 ? this.list1 : this.list2)
        if (sel.Length = 0) {
            sel := (useList1 ? this.list2 : this.list1)
        }
        if (sel.Length = 0) {
            try {
                this.log.Write("⚠️ Καμία λίστα διαθέσιμη (list1/list2 κενές) — παραμένω στην κενή καρτέλα.")
            } catch Error as _eEmpty {
            }
            return { useList1: false, id: "", url: "about:blank", r: r, prob: prob }
        }
        idx := Random(1, sel.Length)
        pick := sel[idx]
        url := "https://www.youtube.com/watch?v=" pick
        return { useList1: useList1, id: pick, url: url, r: r, prob: prob }
    }

    _computeRandomWaitMs() {
        minMs := Settings.LOOP_MIN_MS + 0
        maxMs := Settings.LOOP_MAX_MS + 0
        if (maxMs < minMs) {
            tmp := minMs
            minMs := maxMs
            maxMs := tmp
        }
        try {
            return Round(Random(minMs, maxMs))
        } catch Error as _e {
        }
    }

    _fmtDurationMs(ms) {
        total := ms + 0
        if (total < 0) {
            total := 0
        }
        m := Floor(total / 60000)
        rem := Mod(total, 60000)
        s := Floor(rem / 1000)
        msRem := Mod(rem, 1000)
        sTxt := (s < 10 ? "0" s : "" s)
        msTxt := (msRem < 10 ? "00" msRem : (msRem < 100 ? "0" msRem : "" msRem))
        return m "m " sTxt "s " msTxt "ms"
    }

    _sleepRespectingPauseStop(ms, label := "") {
        chunk := 500
        elapsed := 0
        try {
            if (label != "") {
                this.log.Write(Format("⏳ Αναμονή σε εξέλιξη ({1} ms — {2})", ms, label))
            } else {
                this.log.Write(Format("⏳ Αναμονή σε εξέλιξη ({1} ms)", ms))
            }
        } catch Error as _eLog {
        }
        while (elapsed < ms) {
            while this._paused
                Sleep(150)
            if this._stopRequested
                throw Error("Stopped by user")
            Sleep(chunk)
            elapsed += chunk
        }
    }

    _checkAbortOrPause() {
        while this._paused
            Sleep(150)
        if this._stopRequested
            throw Error("Stopped by user")
    }
}
; ==================== End Of File ====================
