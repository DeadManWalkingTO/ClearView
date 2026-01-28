#Requires AutoHotkey v2.0
#Include "settings.ahk"

; ==================== lib/cdp.ahk ====================
#Requires AutoHotkey v2.0
#Include "settings.ahk"

; ───────── 1) JSON HELPERS ─────────
JsonStringify(v) {
  local t, s, first, k, val, _
  t := Type(v)
  if (t = "Map") {
    s := "{"
    first := true
    for k, val in v {
      if (!first) {
        s .= ","
      }
      first := false
      s .= "\"" JsonEscape(String(k)) "\":" JsonStringify(val)
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
    return "\"" JsonEscape(v) "\""
  } else if (t = "ComObject" || t = "Object") {
    return "\"" JsonEscape(String(v)) "\""
  } else if (v = false) {
    return "false"
  } else if (v = "") {
    return "\"\""
  } else {
    return "\"" JsonEscape(String(v)) "\""
  }
}
JsonEscape(s) {
  s := StrReplace(s, "\\", "\\")
  s := StrReplace(s, "`n", "\n")
  s := StrReplace(s, "`r", "\r")
  s := StrReplace(s, '"', '\\"')
  return s
}

; ───────── 2) WSClient (WinHTTP WebSocket) ─────────
class WSClient {
  static Connect(wsUrl) {
    local u, secure, hSession, hConnect, flags, hRequest, key, hdrs, ok, hWS, ws
    try {
      u := WSClient._parseWsUrl(wsUrl)
      secure := (u.scheme = "wss")

      ; WinHttpOpen
      hSession := DllCall("winhttp\\WinHttpOpen", "ptr", 0, "uint", 1, "ptr", 0, "ptr", 0, "uint", 0, "ptr")
      if (!hSession) {
        throw Error("WinHttpOpen failed")
      }

      ; WinHttpConnect(host:port)
      hConnect := DllCall("winhttp\\WinHttpConnect", "ptr", hSession, "str", u.host, "ushort", u.port, "uint", 0, "ptr")
      if (!hConnect) {
        throw Error("WinHttpConnect failed")
      }

      ; WinHttpOpenRequest (GET /path, secure?)
      flags := secure ? 0x00800000 : 0  ; WINHTTP_FLAG_SECURE
      hRequest := DllCall("winhttp\\WinHttpOpenRequest"
        , "ptr", hConnect, "str", "GET", "str", u.path
        , "ptr", 0, "ptr", 0, "ptr", 0
        , "uint", flags, "ptr")
      if (!hRequest) {
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
      ok := DllCall("winhttp\\WinHttpAddRequestHeaders"
        , "ptr", hRequest, "str", hdrs, "uint", -1, "uint", 0x20000000, "int")
      if (!ok) {
        throw Error("WinHttpAddRequestHeaders failed")
      }

      ; Send/Receive
      ok := DllCall("winhttp\\WinHttpSendRequest", "ptr", hRequest, "ptr", 0, "uint", 0, "ptr", 0, "uint", 0, "ptr", 0, "int")
      if (!ok) {
        throw Error("WinHttpSendRequest failed")
      }
      ok := DllCall("winhttp\\WinHttpReceiveResponse", "ptr", hRequest, "ptr", 0, "int")
      if (!ok) {
        throw Error("WinHttpReceiveResponse failed")
      }

      ; WebSocket upgrade
      hWS := DllCall("winhttp\\WinHttpWebSocketCompleteUpgrade", "ptr", hRequest, "ptr", 0, "ptr")
      if (!hWS) {
        throw Error("WinHttpWebSocketCompleteUpgrade failed")
      }

      ; request handle not needed anymore
      DllCall("winhttp\\WinHttpCloseHandle", "ptr", hRequest)

      ws := Map()
      ws["session"] := hSession
      ws["connect"] := hConnect
      ws["ws"] := hWS
      return ws

    } catch Error as e {
      ; best-effort cleanup
      try {
        if (IsSet(hRequest) && hRequest)
          DllCall("winhttp\\WinHttpCloseHandle", "ptr", hRequest)
      } catch {}
      try {
        if (IsSet(hConnect) && hConnect)
          DllCall("winhttp\\WinHttpCloseHandle", "ptr", hConnect)
      } catch {}
      try {
        if (IsSet(hSession) && hSession)
          DllCall("winhttp\\WinHttpCloseHandle", "ptr", hSession)
      } catch {}
      return 0
    }
  }

  static Close(ws) {
    if (!IsObject(ws)) {
      return
    }
    ; graceful close
    try {
      if (ws.Has("ws") && ws["ws"]) {
        DllCall("winhttp\\WinHttpWebSocketClose"
          , "ptr", ws["ws"]
          , "ushort", 1000  ; Normal Closure
          , "ptr", 0
          , "uint", 0)
      }
    } catch Error as e {
    }
    ; handles close
    try {
      if (ws.Has("ws") && ws["ws"]) {
        DllCall("winhttp\\WinHttpCloseHandle", "ptr", ws["ws"])
        ws["ws"] := 0
      }
    } catch {}
    try {
      if (ws.Has("connect") && ws["connect"]) {
        DllCall("winhttp\\WinHttpCloseHandle", "ptr", ws["connect"])
        ws["connect"] := 0
      }
    } catch {}
    try {
      if (ws.Has("session") && ws["session"]) {
        DllCall("winhttp\\WinHttpCloseHandle", "ptr", ws["session"])
        ws["session"] := 0
      }
    } catch {}
  }

  static SendText(ws, text) {
    local buf, res
    try {
      if (!ws || !ws.Has("ws"))
        return false
      buf := WSClient._utf8buf(text)
      res := DllCall("winhttp\\WinHttpWebSocketSend", "ptr", ws["ws"], "uint", 2, "ptr", buf, "uint", buf.Size, "int")
      return (res = 0)
    } catch Error as e {
      return false
    }
  }

  static RecvText(ws, timeoutMs := 1500) {
    local bufSize, buf, bytesRead, typeBuf, res, br
    if (!ws || !ws.Has("ws"))
      return ""
    bufSize := 65536
    buf := Buffer(bufSize, 0)
    bytesRead := Buffer(4, 0)
    typeBuf := Buffer(4, 0)
    res := DllCall("winhttp\\WinHttpWebSocketReceive", "ptr", ws["ws"], "ptr", buf, "uint", bufSize, "ptr", bytesRead, "ptr", typeBuf, "int")
    if (res != 0)
      return ""
    br := NumGet(bytesRead, 0, "UInt")
    if (br = 0)
      return ""
    return StrGet(buf, br, "UTF-8")
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
    loop 16 {
      NumPut("UChar", Random(0,255), b, A_Index - 1)
    }
    return WSClient._b64(b)
  }

  static _b64(buf) {
    local flags, size, out, ok
    flags := 0x40000001 ; NOCRLF | BASE64
    size := 0
    DllCall("crypt32\\CryptBinaryToStringW", "ptr", buf, "uint", buf.Size, "uint", flags, "ptr", 0, "uint*", size)
    out := Buffer(size * 2)
    ok := DllCall("crypt32\\CryptBinaryToStringW", "ptr", buf, "uint", buf.Size, "uint", flags, "ptr", out, "uint*", size)
    if (!ok)
      return ""
    return StrGet(out, size, "UTF-16")
  }
}

; ───────── 3) CDP ─────────
class CDP {
  static VERSION := "v1.1.3"

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
          if (yt.Count && yt.Has("webSocketDebuggerUrl")) {
            break
          }
        }
        Sleep(300)
        elapsed := A_TickCount - tStart
      }
      if (!yt.Count || !yt.Has("webSocketDebuggerUrl"))
        throw Error("YouTube target not found (timeout)")

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
      throw e  ; rethrow για πλήρες stack
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
      if (this._connected && this._ws) {
        WSClient.Close(this._ws)
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
    while RegExMatch(txt, "\{[\s\S]*?\}", &m, pos) {
      objTxt := m[0]
      pos := m.Pos(0) + m.Len(0)
      o := Map()
      for key in ["id","title","url","type","webSocketDebuggerUrl"] {
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
        if (InStr(o["type"], "page") && InStr(o["url"], "watch?v="))
          return o
      } catch {}
    }
    for _, o in arr {
      try {
        if (InStr(o["type"], "page") && InStr(o["title"], "YouTube"))
          return o
      } catch {}
    }
    for _, o in arr {
      try {
        if (InStr(o["type"], "page"))
          return o
      } catch {}
    }
    return Map()
  }

  _sendRecv(obj, timeoutMs := 1500) {
    local json, ok, expectedId, tStart, raw, idGot, r
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
      idGot := this._jsonExtractNumber(raw, "id")
      if (idGot != "" && (idGot + 0) = expectedId) {
        r["__raw"] := raw
        return r
      }
      ; otherwise: notification, continue looping
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
    pat := "\"" key "\"\s*:\s*\"([^\"]*)\""
    if RegExMatch(src, pat, &mm)
      return mm[1]
    return ""
  }

  _jsonExtractNumber(src, key) {
    local pat, mm
    if (src = "")
      return ""
    pat := "\"" key "\"\s*:\s*(-?\d+(?:\.\d+)?)"
    if RegExMatch(src, pat, &mm)
      return mm[1]
    return ""
  }
}
; ==================== End Of File ====================
