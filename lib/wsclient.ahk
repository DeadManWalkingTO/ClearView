; ==================== lib/wsclient.ahk ====================
#Requires AutoHotkey v2.0
#Include "regex.ahk"

; -----------------------------------------------------------------------------
; WSClient: WinHTTP WebSocket client (CDP-compatible)
; -----------------------------------------------------------------------------
; Κανόνες που τηρούνται:
; - AHK v2: ΠΑΝΤΑ try { … } catch Error as e { … } με πολυγραμμικά blocks.
; - Καμία χρήση των τελεστών && / || (διαδοχικά if).
; - Χρήση ενιαίου helper SafeCloseHandleRef(&h): ασφαλές κλείσιμο + μηδενισμός.
; - DllCall paths με ΜΟΝΟ backslash: "winhttp\..." / "crypt32\...".
; - Χωρίς IsSet(...) σε ιδιότητες ή μεταβλητές: όλα τα handles αρχικοποιούνται σε 0.
; -----------------------------------------------------------------------------

class WSClient {
  /**
   * Συνδέεται σε WebSocket URL (ws:// ή wss://) μέσω WinHTTP.
   * Επιστρέφει Map με handles: "session", "connect", "ws" ή 0 σε αποτυχία.
   */
  static Connect(wsUrl) {
    local u, secure, hSession := 0, hConnect := 0, hRequest := 0
    local flags, key, hdrs, ok, hWS := 0, ws

    try {
      ; Ανάλυση URL
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

      ; WinHttpOpenRequest (GET path, secure?)
      flags := 0
      if (secure) {
        flags := 0x00800000  ; WINHTTP_FLAG_SECURE
      }
      hRequest := DllCall("winhttp\WinHttpOpenRequest"
        , "ptr", hConnect, "str", "GET", "str", u.path
        , "ptr", 0, "ptr", 0, "ptr", 0
        , "uint", flags, "ptr")
      if (hRequest = 0) {
        throw Error("WinHttpOpenRequest failed")
      }

      ; WebSocket headers
      key := WSClient._genSecKey()
      hdrs := "Connection: Upgrade`r`n"
        . "Upgrade: websocket`r`n"
        . "Sec-WebSocket-Version: 13`r`n"
        . "Sec-WebSocket-Key: " key "`r`n"

      ok := DllCall("winhttp\WinHttpAddRequestHeaders", "ptr", hRequest, "str", hdrs, "uint", -1, "uint", 0x20000000, "int")
      if (ok = 0) {
        throw Error("WinHttpAddRequestHeaders failed")
      }

      ; Send/Receive (HTTP handshake)
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

      ; Το hRequest δεν χρειάζεται πλέον μετά το upgrade
      WSClient.SafeCloseHandleRef(&hRequest)

      ; Επιστροφή handles
      ws := Map()
      ws["session"] := hSession
      ws["connect"] := hConnect
      ws["ws"] := hWS
      return ws

    } catch Error as e {
      ; Best-effort cleanup (χωρίς IsSet, με by-ref μηδενισμό)
      try {
        WSClient.SafeCloseHandleRef(&hRequest)
      } catch Error as _cleanupErr1 {
        ; no-op
      }
      try {
        WSClient.SafeCloseHandleRef(&hConnect)
      } catch Error as _cleanupErr2 {
        ; no-op
      }
      try {
        WSClient.SafeCloseHandleRef(&hSession)
      } catch Error as _cleanupErr3 {
        ; no-op
      }
      return 0
    }
  }

  /**
   * Κλείνει ευγενικά το WebSocket (close frame 1000) και έπειτα όλα τα handles.
   */
  static Close(ws) {
    if (!IsObject(ws)) {
      return
    }

    ; Graceful close (WebSocket)
    try {
      if (ws.Has("ws")) {
        if (ws["ws"] != 0) {
          DllCall("winhttp\WinHttpWebSocketClose"
            , "ptr", ws["ws"]
            , "ushort", 1000  ; Normal Closure
            , "ptr", 0
            , "uint", 0)
        }
      }
    } catch Error as _eGrace {
      ; no-op
    }

    ; Κλείσιμο και μηδενισμός handles με τον ενιαίο helper
    try {
      if (ws.Has("ws")) {
        h := ws["ws"]
        WSClient.SafeCloseHandleRef(&h)
        ws["ws"] := h
      }
    } catch Error as _eWs {
      ; no-op
    }

    try {
      if (ws.Has("connect")) {
        h := ws["connect"]
        WSClient.SafeCloseHandleRef(&h)
        ws["connect"] := h
      }
    } catch Error as _eConn {
      ; no-op
    }

    try {
      if (ws.Has("session")) {
        h := ws["session"]
        WSClient.SafeCloseHandleRef(&h)
        ws["session"] := h
      }
    } catch Error as _eSess {
      ; no-op
    }
  }

  /**
   * Ενιαίος helper: κλείνει το handle (αν != 0) και ΠΑΝΤΑ το μηδενίζει στο finally.
   */
  static SafeCloseHandleRef(&h) {
    try {
      if (h != 0) {
        DllCall("winhttp\WinHttpCloseHandle", "ptr", h)
      }
    } catch Error as _eClose {
      ; no-op
    } finally {
      h := 0
    }
  }

  /**
   * Αποστέλλει UTF-8 text frame. Επιστρέφει true σε επιτυχία, αλλιώς false.
   */
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
      if (res = 0) {
        return true
      }
      return false
    } catch Error as _eSend {
      return false
    }
  }

  /**
   * Λαμβάνει text frame (UTF-8). Επιστρέφει string ή "".
   * Σημείωση: timeoutMs χρησιμοποιείται στο εσωτερικό polling του WinHTTP.
   */
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
    } catch Error as _eRecv {
      return ""
    }
  }

  ; ---------------- Internals ----------------

  /**
   * Παίρνει "ws://host:port/path" ή "wss://..." και επιστρέφει Map:
   * { scheme, host, port, path } με απλές string πράξεις (χωρίς regex).
   */
  static _parseWsUrl(u) {
    local out, tmp, pSlash, hostPort, path, pColon, host, port
    out := Map()
    if (InStr(u, "wss://") = 1) {
      out["scheme"] := "wss"
      tmp := SubStr(u, 7)  ; κόβουμε "wss://"
    } else {
      out["scheme"] := "ws"
      if (InStr(u, "ws://") = 1) {
        tmp := SubStr(u, 6) ; κόβουμε "ws://"
      } else {
        tmp := u
      }
    }

    pSlash := InStr(tmp, "/")
    if (pSlash) {
      hostPort := SubStr(tmp, 1, pSlash - 1)
      path := SubStr(tmp, pSlash)
    } else {
      hostPort := tmp
      path := "/"
    }

    pColon := InStr(hostPort, ":")
    if (pColon) {
      host := SubStr(hostPort, 1, pColon - 1)
      port := SubStr(hostPort, pColon + 1) + 0
    } else {
      host := hostPort
      port := 80
    }

    out["host"] := host
    out["port"] := port
    out["path"] := path
    return out
  }

  /**
   * Μετατρέπει string σε Buffer UTF-8 και επιστρέφει (χωρίς τελικό NUL).
   */
  static _utf8buf(s) {
    local len, buf
    len := StrPut(s, "UTF-8")
    buf := Buffer(len)
    StrPut(s, buf, "UTF-8")
    buf.Size := len - 1
    return buf
  }

  /**
   * Γεννά τυχαίο Sec-WebSocket-Key (16 bytes) και το κωδικοποιεί Base64.
   */
  static _genSecKey() {
    local b
    b := Buffer(16)
    try {
      loop 16 {
        NumPut("UChar", Random(0, 255), b, A_Index - 1)
      }
    } catch Error as _eRand {
      ; no-op (σε σπάνια σφάλματα Random, το buffer παραμένει με μηδενισμένα bytes)
    }
    return WSClient._b64(b)
  }

  /**
   * Base64 (UNICODE wide) μέσω CryptBinaryToStringW (NOCRLF).
   */
  static _b64(buf) {
    local flags, size, out, ok
    flags := 0x40000001  ; CRYPT_STRING_BASE64 | CRYPT_STRING_NOCRLF
    size := 0

    try {
      ; Πρώτη κλήση για μέγεθος
      DllCall("crypt32\CryptBinaryToStringW", "ptr", buf, "uint", buf.Size, "uint", flags, "ptr", 0, "uint*", size)
      ; Δεύτερη κλήση με buffer εξόδου (UTF-16)
      out := Buffer(size * 2)
      ok := DllCall("crypt32\CryptBinaryToStringW", "ptr", buf, "uint", buf.Size, "uint", flags, "ptr", out, "uint*", size)
      if (ok = 0) {
        return ""
      }
      return StrGet(out, size, "UTF-16")
    } catch Error as _eB64 {
      return ""
    }
  }
}
; ==================== End Of File ====================
