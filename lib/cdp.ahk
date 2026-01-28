; ==================== lib/cdp.ahk ====================
#Requires AutoHotkey v2.0
#Include "settings.ahk"
#Include "regex.ahk"
#Include "json.ahk"
#Include "wsclient.ahk"
#Include "cdp_http.ahk"
#Include "cdp_js.ahk"

class CDP {
  static VERSION := "v1.2.1"

  __New(port := 9222) {
    this.port := port
    this._connected := false
    this._ws := 0
    this._msgId := 0
    this._targetId := ""
    this._wsUrl := ""
  }

  ; -------- Public API --------
  ConnectToYouTubeTab() {
    return this.ConnectToYouTubeTabWithRetry(12000)  ; αυξημένο default timeout
  }

  ConnectToYouTubeTabWithRetry(maxWaitMs := 12000) {
    local targets, yt, payload
    try {
      if (!Settings.CDP_ENABLED) {
        throw Error("CDP disabled")
      }

      ; 1) HTTP polling στο /json (με backoff + fallback μέσα στο DevTools_GetTargets)
      targets := DevTools_GetTargets(this.port, maxWaitMs, 250)
      if (targets.Length = 0) {
        throw Error("CDP /json not reachable (timeout)")
      }

      ; 2) Επιλογή YouTube target
      yt := this._pickYouTubeTarget(targets)
      if (!yt.Count) {
        throw Error("YouTube target not found (timeout)")
      }
      if !yt.Has("webSocketDebuggerUrl") {
        throw Error("YouTube target not found (no ws url)")
      }

      ; 3) WebSocket σύνδεση
      this._wsUrl := yt["webSocketDebuggerUrl"]
      this._targetId := yt["id"]
      this._ws := WSClient.Connect(this._wsUrl)
      if (!this._ws) {
        throw Error("WS connect failed")
      }

      this._connected := true

      ; 4) Runtime.enable
      payload := Map("id", this._nextId(), "method", "Runtime.enable", "params", Map())
      this._sendRecv(payload, 2000)
      return true
    } catch Error as e {
      this._connected := false
      throw e
    }
  }

  GetYouTubeDurationSeconds() {
    local expr, val
    try {
      if (!this._connected) {
        throw Error("CDP not connected")
      }
      expr := CDP_JS_GetYouTubeDurationExpr()
      val := this.EvaluateWithRetry(expr, 6, 500)
      return val
    } catch Error as e {
      throw e
    }
  }

  EvaluateWithRetry(expr, attempts := 5, delayMs := 500) {
    local i, payload, resp, raw, val
    i := 1
    while (i <= attempts) {
      payload := Map(
        "id", this._nextId(),
        "method", "Runtime.evaluate",
        "params", Map(
          "expression", expr,
          "returnByValue", true,
          "awaitPromise", true,
          "userGesture", true
        )
      )
      resp := this._sendRecv(payload, 2000)
      raw := resp.Has("__raw") ? resp["__raw"] : ""
      if (raw != "") {
        val := this._jsonExtractNumber(raw, "value")
        if (val != "") {
          return val + 0
        }
      }
      Sleep(delayMs)
      i += 1
    }
    return -1
  }

  Disconnect() {
    try {
      if (this._connected) {
        if (this._ws) {
          WSClient.Close(this._ws)
        }
      }
    } catch Error as _e {
      ; no-op
    } finally {
      this._connected := false
      this._ws := 0
    }
  }

  ; -------- Internals --------
  _nextId() {
    this._msgId += 1
    return this._msgId
  }

  _pickYouTubeTarget(arr) {
    local o, _
    for _, o in arr {
      try {
        if (InStr(o["type"], "page")) {
          if (InStr(o["url"], "watch?v=")) {
            return o
          }
        }
      } catch Error as _e1 {
        ; no-op
      }
    }
    for _, o in arr {
      try {
        if (InStr(o["type"], "page")) {
          if (InStr(o["title"], "YouTube")) {
            return o
          }
        }
      } catch Error as _e2 {
        ; no-op
      }
    }
    for _, o in arr {
      try {
        if (InStr(o["type"], "page")) {
          return o
        }
      } catch Error as _e3 {
        ; no-op
      }
    }
    return Map()
  }

  _sendRecv(obj, timeoutMs := 1500) {
    local json, ok, expectedId, tStart, raw, idGot, r
    json := JsonStringify(obj)
    ok := WSClient.SendText(this._ws, json)
    r := Map()
    r["__raw"] := ""
    if (!ok) {
      return r
    }
    expectedId := obj.Has("id") ? obj["id"] : 0
    tStart := A_TickCount
    while (A_TickCount - tStart < timeoutMs) {
      raw := WSClient.RecvText(this._ws, timeoutMs)
      if (raw = "") {
        break
      }
      idGot := this._jsonExtractNumber(raw, "id")
      if (idGot != "") {
        if ((idGot + 0) = expectedId) {
          r["__raw"] := raw
          return r
        }
      }
    }
    return r
  }

  _jsonExtractString(src, key) {
    local pat, mm
    if (src = "") {
      return ""
    }
    try {
      pat := RegexLib.Pat_JsonKeyQuotedString(key)
      if RegExMatch(src, pat, &mm) {
        return mm[1]
      }
    } catch Error as _e {
      ; no-op
    }
    return ""
  }

  _jsonExtractNumber(src, key) {
    local pat, mm
    if (src = "") {
      return ""
    }
    try {
      pat := RegexLib.Pat_JsonKeyNumber(key)
      if RegExMatch(src, pat, &mm) {
        return mm[1]
      }
    } catch Error as _e {
      ; no-op
    }
    return ""
  }
}

; --- Factory helper: καθαρή δημιουργία instance (φιλικό σε linters) ---
CDP_Create(port) {
  return CDP(port)
}
; ==================== End Of File ====================
