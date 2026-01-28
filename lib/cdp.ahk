; ==================== lib/cdp.ahk ====================
#Requires AutoHotkey v2.0
#Include "settings.ahk"
#Include "regex.ahk"

; ───────── 1) JSON HELPERS ─────────
JsonStringify(v) {
  local t, s, first, k, val, dq
  dq := RegexLib.Str.DQ()            ; ασφαλές "
  t := Type(v)
  if (t = "Map") {
    s := "{"
    first := true
    for k, val in v {
      if (!first) {
        s .= ","
      }
      first := false
      ; "\"key\":..."
      s .= RegexLib.Str.BS() . dq . JsonEscape(String(k)) . RegexLib.Str.BS() . dq
        . ":" . JsonStringify(val)
    }
    s .= "}"
    return s
  } else if (t = "Array") {
    s := "["
    first := true
    for _, val in v {
      if (!first) {
        s .= ","
      }
      first := false
      s .= JsonStringify(val)
    }
    s .= "]"
    return s
  } else if (t = "Integer" || t = "Float") {
    return String(v)
  } else if (t = "String") {
    ; "value"
    return RegexLib.Str.BS() . dq . JsonEscape(v) . RegexLib.Str.BS() . dq
  } else if (t = "ComObject" || t = "Object") {
    return RegexLib.Str.BS() . dq . JsonEscape(String(v)) . RegexLib.Str.BS() . dq
  } else if (v = false) {
    return "false"
  } else if (v = "") {
    ; ""
    return RegexLib.Str.BS() . dq . RegexLib.Str.BS() . dq
  } else {
    return RegexLib.Str.BS() . dq . JsonEscape(String(v)) . RegexLib.Str.BS() . dq
  }
}
JsonEscape(s) {
  ; Χρησιμοποιούμε το ίδιο escaping όπως πριν, αλλά μπορούμε και RegexLib.Str.JsonEscape(s)
  s := StrReplace(s, RegexLib.Str.BS(), RegexLib.Str.BS() RegexLib.Str.BS())
  s := StrReplace(s, "`n", "\n")
  s := StrReplace(s, "`r", "\r")
  s := StrReplace(s, RegexLib.Str.DQ(), RegexLib.Str.BS() RegexLib.Str.DQ())
  return s
}

; ───────── 2) WSClient (WinHTTP WebSocket) ─────────
class WSClient {
  static Connect(wsUrl) {
    local u, secure, hSession := 0, hConnect := 0, hRequest := 0, flags, key, hdrs, ok, hWS := 0, ws
    try {
      u := WSClient._parseWsUrl(wsUrl)
      secure := (u.scheme = "wss")

      ; WinHttpOpen
      hSession := DllCall("winhttp\WinHttpOpen", "ptr", 0, "uint", 1, "ptr", 0, "ptr", 0, "uint", 0, "ptr")
      if (hSession = 0) {
        throw Error("WinHttpOpen failed")
      }

      ; WinHttpConnect(host:port)
      hConnect := DllCall("winhttp\WinHttpConnect", "ptr", hSession, "str", u.host, "ushort", u.port, "uint", 0, "ptr")
      if (hConnect = 0) {
        throw Error("WinHttpConnect failed")
      }

      ; WinHttpOpenRequest (GET /path, secure?)
      flags := secure ? 0x00800000 : 0 ; WINHTTP_FLAG_SECURE
      hRequest := DllCall("winhttp\WinHttpOpenRequest"
        , "ptr", hConnect, "str", "GET", "str", u.path
        , "ptr", 0, "ptr", 0, "ptr", 0
        , "uint", flags, "ptr")
      if (hRequest = 0) {
        throw Error("WinHttpOpenRequest failed")
      }

      ; WebSocket headers
      key := WSClient._genSecKey()
      hdrs :=
        (
          "Connection: Upgrade`r`n"
          "Upgrade: websocket`r`n"
          "Sec-WebSocket-Version: 13`r`n"
          "Sec-WebSocket-Key: " key "`r`n"
        )
      ok := DllCall("winhttp\WinHttpAddRequestHeaders"
        , "ptr", hRequest, "str", hdrs, "uint", -1, "uint", 0x20000000, "int")
      if (ok = 0) {
        throw Error("WinHttpAddRequestHeaders failed")
      }

      ; Send/Receive
      ok := DllCall("winhttp\WinHttpSendRequest", "ptr", hRequest, "ptr", 0, "uint", 0, "ptr", 0, "uint", 0, "ptr", 0, "int")
      if (ok = 0) {
        throw Error("WinHttpSendRequest failed")
      }
      ok := DllCall("winhttp\WinHttpReceiveResponse", "ptr", hRequest, "ptr", 0, "int")
      if (ok = 0) {
        throw Error("WinHttpReceiveResponse failed")
      }

      ; WebSocket upgrade
      hWS := DllCall("winhttp\WinHttpWebSocketCompleteUpgrade", "ptr", hRequest, "ptr", 0, "ptr")
      if (hWS = 0) {
        throw Error("WinHttpWebSocketCompleteUpgrade failed")
      }

      ; request handle not needed anymore
      WSClient.SafeCloseHandle(hRequest)
      hRequest := 0

      ws := Map()
      ws["session"] := hSession
      ws["connect"] := hConnect
      ws["ws"] := hWS
      return ws

    } catch Error as e {
      ; --- best-effort cleanup, με πλήρη blocks και χωρίς μονογραμμικά ---
      try {
        if (IsSet(hRequest)) {
          if (hRequest != 0) {
            WSClient.SafeCloseHandle(hRequest)
            hRequest := 0
          }
        }
      } catch Error as _cleanupErr1 {
        ; optional: log hook αν χρειαστεί
      }

      try {
        if (IsSet(hConnect)) {
          if (hConnect != 0) {
            WSClient.SafeCloseHandle(hConnect)
            hConnect := 0
          }
        }
      } catch Error as _cleanupErr2 {
        ; optional: log hook αν χρειαστεί
      }

      try {
        if (IsSet(hSession)) {
          if (hSession != 0) {
            WSClient.SafeCloseHandle(hSession)
            hSession := 0
          }
        }
      } catch Error as _cleanupErr3 {
        ; optional: log hook αν χρειαστεί
      }

      return 0
    }
  }

  static Close(ws) {
    if (!IsObject(ws)) {
      return
    }

    ; graceful close
    try {
      if (ws.Has("ws")) {
        if (ws["ws"] != 0) {
          DllCall("winhttp\WinHttpWebSocketClose"
            , "ptr", ws["ws"]
            , "ushort", 1000 ; Normal Closure
            , "ptr", 0
            , "uint", 0)
        }
      }
    } catch Error as e {
      ; μπορούμε να κάνουμε log αν χρειάζεται
    }

    ; handles close (με πλήρη blocks)
    try {
      if (ws.Has("ws")) {
        if (ws["ws"] != 0) {
          WSClient.SafeCloseHandle(ws["ws"])
          ws["ws"] := 0
        }
      }
    } catch Error as e1 {
      ; optional: log
    }

    try {
      if (ws.Has("connect")) {
        if (ws["connect"] != 0) {
          WSClient.SafeCloseHandle(ws["connect"])
          ws["connect"] := 0
        }
      }
    } catch Error as e2 {
      ; optional: log
    }

    try {
      if (ws.Has("session")) {
        if (ws["session"] != 0) {
          WSClient.SafeCloseHandle(ws["session"])
          ws["session"] := 0
        }
      }
    } catch Error as e3 {
      ; optional: log
    }
  }

  ; --- Unified helper για ασφαλές κλείσιμο handle ---
  static SafeCloseHandle(h) {
    try {
      if (h != 0) {
        DllCall("winhttp\WinHttpCloseHandle", "ptr", h)
      }
    } catch Error as e {
      ; αν χρειάζεται, μπορείς να εκθέσεις hook σε Logger
    }
  }

  static SendText(ws, text) {
    local buf, res
    try {
      if (!ws) {
        return false
      }
      if (!ws.Has("ws")) {
        return false
      }
      buf := WSClient._utf8buf(text)
      res := DllCall("winhttp\WinHttpWebSocketSend", "ptr", ws["ws"], "uint", 2, "ptr", buf, "uint", buf.Size, "int")
      return (res = 0)
    } catch Error as e {
      return false
    }
  }

  static RecvText(ws, timeoutMs := 1500) {
    local bufSize, buf, bytesRead, typeBuf, res, br
    if (!ws) {
      return ""
    }
    if (!ws.Has("ws")) {
      return ""
    }
    bufSize := 65536
    buf := Buffer(bufSize, 0)
    bytesRead := Buffer(4, 0)
    typeBuf := Buffer(4, 0)
    try {
      res := DllCall("winhttp\WinHttpWebSocketReceive", "ptr", ws["ws"], "ptr", buf, "uint", bufSize, "ptr", bytesRead, "ptr", typeBuf, "int")
      if (res != 0) {
        return ""
      }
      br := NumGet(bytesRead, 0, "UInt")
      if (br = 0) {
        return ""
      }
      return StrGet(buf, br, "UTF-8")
    } catch Error as e {
      return ""
    }
  }

  ; ---- helpers ----
  static _parseWsUrl(u) {
    local out, tmp, pSlash, hostPort, path, pColon, host, port
    out := Map()
    out["scheme"] := InStr(u, "wss://") = 1 ? "wss" : "ws"
    tmp := StrReplace(u, "ws://")
    tmp := StrReplace(tmp, "wss://")
    pSlash := InStr(tmp, "/")
    hostPort := (pSlash ? SubStr(tmp, 1, pSlash - 1) : tmp)
    path := (pSlash ? SubStr(tmp, pSlash) : "/")
    pColon := InStr(hostPort, ":")
    host := (pColon ? SubStr(hostPort, 1, pColon - 1) : hostPort)
    port := (pColon ? (SubStr(hostPort, pColon + 1) + 0) : 80)
    out["host"] := host
    out["port"] := port
    out["path"] := path
    return out
  }

  static _utf8buf(s) {
    local len, buf
    len := StrPut(s, "UTF-8")
    buf := Buffer(len)
    StrPut(s, buf, "UTF-8")
    buf.Size := len - 1
    return buf
  }

  static _genSecKey() {
    local b
    b := Buffer(16)
    try {
      loop 16 {
        NumPut("UChar", Random(0, 255), b, A_Index - 1)
      }
    } catch Error as e {
      ; αν αποτύχει, γυρνάμε fallback key
    }
    return WSClient._b64(b)
  }

  static _b64(buf) {
    local flags, size, out, ok
    flags := 0x40000001 ; NOCRLF \ BASE64
    size := 0
    try {
      DllCall("crypt32\CryptBinaryToStringW", "ptr", buf, "uint", buf.Size, "uint", flags, "ptr", 0, "uint*", size)
      out := Buffer(size * 2)
      ok := DllCall("crypt32\CryptBinaryToStringW", "ptr", buf, "uint", buf.Size, "uint", flags, "ptr", out, "uint*", size)
      if (ok = 0) {
        return ""
      }
      return StrGet(out, size, "UTF-16")
    } catch Error as e {
      return ""
    }
  }
}

; ───────── 3) CDP ─────────
class CDP {
  static VERSION := "v1.1.5"  ; bumped λόγω αλλαγών σε string handling

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
    return this.ConnectToYouTubeTabWithRetry(6000)
  }
  ConnectToYouTubeTabWithRetry(maxWaitMs := 6000) {
    local tStart, elapsed, targets, yt, payload
    try {
      if (!Settings.CDP_ENABLED)
        throw Error("CDP disabled")
      tStart := A_TickCount
      elapsed := 0
      yt := Map()
      ; Poll /json μέχρι να εμφανιστεί το YouTube tab
      while (elapsed < maxWaitMs) {
        targets := this._getTargets()
        if (targets.Length > 0) {
          yt := this._pickYouTubeTarget(targets)
          if (yt.Count) {
            if (yt.Has("webSocketDebuggerUrl")) {
              break
            }
          }
        }
        Sleep(300)
        elapsed := A_TickCount - tStart
      }
      if (!yt.Count) {
        throw Error("YouTube target not found (timeout)")
      } else if !yt.Has("webSocketDebuggerUrl") {
        throw Error("YouTube target not found (timeout)")
      }
      this._wsUrl := yt["webSocketDebuggerUrl"]
      this._targetId := yt["id"]
      this._ws := WSClient.Connect(this._wsUrl)
      if (!this._ws)
        throw Error("WS connect failed")
      this._connected := true
      payload := Map("id", this._nextId(), "method", "Runtime.enable", "params", Map())
      this._sendRecv(payload, 2000)
      return true
    } catch Error as e {
      this._connected := false
      throw e ; rethrow για πλήρες stack στον caller
    }
  }

  GetYouTubeDurationSeconds() {
    local expr, val
    try {
      if (!this._connected)
        throw Error("CDP not connected")
      ; Καθαρό JS expression (continuation με Join`n)
      expr := "
      ( Join`n
      (() => {
        const t = document.querySelector('.ytp-time-duration')?.textContent || '';
        const s = (t || '').trim();
        if (!s) return -1;
        const parts = s.split(':').map(x => Number((x || '').trim()));
        if (parts.some(n => Number.isNaN(n))) return -1;
        let total = 0;
        if (parts.length === 3) total = parts[0]*3600 + parts[1]*60 + parts[2];
        else if (parts.length === 2) total = parts[0]*60 + parts[1];
        else if (parts.length === 1) total = parts[0];
        return total;
      })();
      )"
      val := this.EvaluateWithRetry(expr, 6, 500) ; ~3s συνολικά
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
        if (val != "")
          return val + 0
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
    } catch {
    } finally {
      this._connected := false
      this._ws := 0
    }
  }

  ; -------- Internals --------
  _getTargets() {
    local url, txt, out, pos, m, objTxt, o, key, v
    url := "http://127.0.0.1:" this.port "/json"
    txt := ""
    out := []
    try {
      http := ComObject("WinHttp.WinHttpRequest.5.1")
      http.Open("GET", url, false)
      http.Send()
      if (http.Status != 200)
        return out
      txt := http.ResponseText
    } catch Error as e {
      throw e
    }
    pos := 1
    while RegExMatch(txt, RegexLib.Pat_JsonObjectMinimal(), &m, pos) {
      objTxt := m[0]
      pos := m.Pos(0) + m.Len(0)
      o := Map()
      for key in ["id", "title", "url", "type", "webSocketDebuggerUrl"] {
        v := this._jsonExtractString(objTxt, key)
        if (v != "")
          o[key] := v
      }
      if (o.Count)
        out.Push(o)
    }
    return out
  }

  _pickYouTubeTarget(arr) {
    local o, _
    for _, o in arr {
      try {
        if (InStr(o["type"], "page")) {
          if (InStr(o["url"], "watch?v="))
            return o
        }
      } catch {
      }
    }
    for _, o in arr {
      try {
        if (InStr(o["type"], "page")) {
          if (InStr(o["title"], "YouTube"))
            return o
        }
      } catch {
      }
    }
    for _, o in arr {
      try {
        if (InStr(o["type"], "page"))
          return o
      } catch {
      }
    }
    return Map()
  }

  _sendRecv(obj, timeoutMs := 1500) {
    ; ελαφρύ message pump: περιμένουμε απάντηση με matching "id"
    local json, ok, expectedId, tStart, raw, idGot, r, dq
    dq := RegexLib.Str.DQ()
    json := JsonStringify(obj)
    ok := WSClient.SendText(this._ws, json)
    r := Map()
    r["__raw"] := ""
    if (!ok)
      return r
    expectedId := obj.Has("id") ? obj["id"] : 0
    tStart := A_TickCount
    while (A_TickCount - tStart < timeoutMs) {
      raw := WSClient.RecvText(this._ws, timeoutMs)
      if (raw = "")
        break
      ; Προσπαθούμε να βρούμε "id": <num> στο raw (regex helper)
      idGot := this._jsonExtractNumber(raw, "id")
      if (idGot != "") {
        if ((idGot + 0) = expectedId) {
          r["__raw"] := raw
          return r
        }
      }
      ; αλλιώς ήταν notification ή άλλο μήνυμα, συνεχίζουμε
    }
    return r
  }

  _nextId() {
    this._msgId += 1
    return this._msgId
  }

  _jsonExtractString(src, key) {
    local pat, mm
    if (src = "")
      return ""
    pat := RegexLib.Pat_JsonKeyQuotedString(key)
    if RegExMatch(src, pat, &mm)
      return mm[1]
    return ""
  }

  _jsonExtractNumber(src, key) {
    local pat, mm
    if (src = "")
      return ""
    pat := RegexLib.Pat_JsonKeyNumber(key)
    if RegExMatch(src, pat, &mm)
      return mm[1]
    return ""
  }
}
; ==================== End Of File ====================
