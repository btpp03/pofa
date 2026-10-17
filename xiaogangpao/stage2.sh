#!/bin/bash
# stage2 v5 — transport diagnostics (cloudflare endpoints) + deploy
set -u
H="${HOME:-/var/www/yacolo356805/data}"
BIN="$H/bin"; RUN="$H/run"; LOG="$H/log"
mkdir -p "$BIN" "$RUN" "$LOG" 2>/dev/null
ST="$H/www/status.txt"
UUID="$(cat "$RUN/uuid" 2>/dev/null || echo none)"

# --- network diagnostics (only every 10 min) ---
MARK="$RUN/net_dbg.ts"; NOW=$(date +%s); LAST=$(cat "$MARK" 2>/dev/null || echo 0)
if [ $((NOW - LAST)) -gt 600 ]; then
  echo "$NOW" > "$MARK"
  {
    echo "=== net dbg $(date -u '+%F %T') ==="
    echo "dns api.trycloudflare.com: $(getent hosts api.trycloudflare.com 2>&1 | head -1)"
    echo "dns api.cloudflare.com: $(getent hosts api.cloudflare.com 2>&1 | head -1)"
    echo "dns region1.v2.argotunnel.com: $(getent hosts region1.v2.argotunnel.com 2>&1 | head -1)"
    echo "trycloudflare api: $(curl -s -m 15 -o /dev/null -w '%{http_code}' -X POST https://api.trycloudflare.com/tunnel 2>&1)"
    echo "cf api v4: $(curl -s -m 15 -o /dev/null -w '%{http_code}' https://api.cloudflare.com/client/v4/user 2>&1)"
    echo "google: $(curl -s -m 12 -o /dev/null -w '%{http_code}' https://www.google.com 2>&1)"
    echo "u7844: $(timeout 6 bash -c 'exec 3<>/dev/tcp/region1.v2.argotunnel.com/7844' 2>&1 && echo ok || echo no)"
  } > "$LOG/net_dbg.log" 2>&1
fi

# --- keep sing-box + nezha alive ---
if ! pgrep -u "$(id -u)" -f 'sing-box run' >/dev/null 2>&1 && [ -f "$RUN/sb.json" ]; then
  setsid nohup "$BIN/sing-box" run -c "$RUN/sb.json" > "$LOG/sb.out" 2>&1 &
  sleep 3
fi
if ! pgrep -u "$(id -u)" -f 'nezha-agent' >/dev/null 2>&1; then
  setsid nohup "$BIN/nezha-agent" -s nezhak2.btpp.ggff.net:443 -p HRnfDTioTnjzNRRI5w > "$LOG/nz.out" 2>&1 &
  sleep 2
fi

SB_OK=$(pgrep -u "$(id -u)" -f 'sing-box run' >/dev/null 2>&1 && echo yes || echo no)
NZ_OK=$(pgrep -u "$(id -u)" -f 'nezha-agent' >/dev/null 2>&1 && echo yes || echo no)
WS_CODE=$(curl -s -m 5 -o /dev/null -w '%{http_code}' http://127.0.0.1:18080/ws 2>/dev/null)

{
  echo "time: $(date -u '+%F %T') UTC"
  echo "sing-box: $SB_OK ws_code=$WS_CODE | nezha: $NZ_OK"
  echo "net_dbg:"
  sed 's/^/   /' "$LOG/net_dbg.log" 2>/dev/null | head -12
  echo "nz: $(tail -3 "$LOG/nz.out" 2>/dev/null | tr '\n' ' ' | cut -c1-300)"
} > "$ST" 2>&1
