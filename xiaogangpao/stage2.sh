#!/bin/bash
# stage2 v4 — same deploy + diagnostics for cloudflared
set -u
H="${HOME:-/var/www/yacolo356805/data}"
BIN="$H/bin"; RUN="$H/run"; LOG="$H/log"
mkdir -p "$BIN" "$RUN" "$LOG" 2>/dev/null
ST="$H/www/status.txt"
UUID_FILE="$H/run/uuid"
CF_LOG="$LOG/cf.log"

if [ ! -x "$BIN/sing-box" ]; then
  curl -fsSL --max-time 120 -o "$RUN/sb.tgz" \
    "https://github.com/SagerNet/sing-box/releases/download/v1.14.3/sing-box-1.14.3-linux-amd64-musl.tar.gz" \
    && tar -xzf "$RUN/sb.tgz" -C "$RUN" && find "$RUN" -maxdepth 2 -name sing-box -type f -exec cp -f {} "$BIN/sing-box" \; && chmod +x "$BIN/sing-box"
fi
if [ ! -x "$BIN/nezha-agent" ]; then
  curl -fsSL --max-time 120 -o "$RUN/nz.zip" \
    "https://github.com/nezhahq/agent/releases/download/v0.20.5/nezha-agent_linux_amd64.zip" \
    && unzip -o -q "$RUN/nz.zip" -d "$RUN/nz" && find "$RUN/nz" -name nezha-agent -type f -exec cp -f {} "$BIN/nezha-agent" \; && chmod +x "$BIN/nezha-agent"
fi
if [ ! -x "$BIN/cloudflared" ]; then
  curl -fsSL --max-time 180 -o "$BIN/cloudflared" \
    "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64" && chmod +x "$BIN/cloudflared"
fi

if [ ! -s "$UUID_FILE" ]; then
  "$BIN/sing-box" generate uuid > "$UUID_FILE" 2>/dev/null || echo "3f2b8c1e-9d4a-4f6b-8e21-7c5a9d0b6e33" > "$UUID_FILE"
fi
UUID="$(cat "$UUID_FILE")"

cat > "$RUN/sb.json" <<JSON
{
  "log": { "level": "warn", "output": "$LOG/sb.log", "timestamp": true },
  "inbounds": [{
    "type": "vless",
    "tag": "vless-ws",
    "listen": "127.0.0.1",
    "listen_port": 18080,
    "users": [{ "uuid": "$UUID" }],
    "transport": { "type": "ws", "path": "/ws" }
  }],
  "outbounds": [{ "type": "direct", "tag": "direct" }]
}
JSON

if ! pgrep -u "$(id -u)" -f 'sing-box run' >/dev/null 2>&1; then
  setsid nohup "$BIN/sing-box" run -c "$RUN/sb.json" > "$LOG/sb.out" 2>&1 &
  sleep 3
fi
SB_OK=$(pgrep -u "$(id -u)" -f 'sing-box run' >/dev/null 2>&1 && echo yes || echo no)
WS_CODE=$(curl -s -m 5 -o /dev/null -w '%{http_code}' http://127.0.0.1:18080/ws 2>/dev/null)

if ! pgrep -u "$(id -u)" -f 'nezha-agent' >/dev/null 2>&1; then
  setsid nohup "$BIN/nezha-agent" -s nezhak2.btpp.ggff.net:443 -p HRnfDTioTnjzNRRI5w > "$LOG/nz.out" 2>&1 &
  sleep 2
fi
NZ_OK=$(pgrep -u "$(id -u)" -f 'nezha-agent' >/dev/null 2>&1 && echo yes || echo no)

CF_PID=$(pgrep -u "$(id -u)" -f 'cloudflared tunnel' | head -1)
CF_HOST=$(grep -ohE '[a-z0-9-]+\.trycloudflare\.com' "$CF_LOG" 2>/dev/null | tail -1)

# diagnostics: only run the foreground probe once every 10 minutes
MARK="$RUN/cf_dbg.ts"
NOW=$(date +%s)
LAST=$(cat "$MARK" 2>/dev/null || echo 0)
CF_DBG=""
if [ $((NOW - LAST)) -gt 600 ]; then
  echo "$NOW" > "$MARK"
  echo "cf version: $("$BIN/cloudflared" --version 2>&1 | head -1)" > "$LOG/cf_dbg.log"
  timeout 30 "$BIN/cloudflared" tunnel --url http://127.0.0.1:18080 --no-autoupdate --protocol http2 \
      >> "$LOG/cf_dbg.log" 2>&1
  echo "fg rc=$?" >> "$LOG/cf_dbg.log"
  CF_HOST=$(grep -ohE '[a-z0-9-]+\.trycloudflare\.com' "$LOG/cf_dbg.log" 2>/dev/null | tail -1)
fi

if [ -z "${CF_PID:-}" ] && [ -z "$CF_HOST" ]; then
  : > "$CF_LOG"
  setsid nohup "$BIN/cloudflared" tunnel --url http://127.0.0.1:18080 --no-autoupdate --protocol http2 \
      --logfile "$CF_LOG" --loglevel info > /dev/null 2>&1 &
fi

{
  echo "time: $(date -u '+%F %T') UTC"
  echo "sing-box: $SB_OK ws_code=$WS_CODE | nezha: $NZ_OK | cf_pid=${CF_PID:-none}"
  echo "tunnel: ${CF_HOST:-NONE}"
  echo "uuid: $UUID"
  [ -n "$CF_HOST" ] && echo "link: vless://$UUID@$CF_HOST:443?encryption=none&security=tls&sni=$CF_HOST&type=ws&host=$CF_HOST&path=%2Fws#yacolo-fr"
  echo "cf_dbg: $(tail -6 "$LOG/cf_dbg.log" 2>/dev/null | tr '\n' ' ' | cut -c1-700)"
  echo "nz: $(tail -3 "$LOG/nz.out" 2>/dev/null | tr '\n' ' ' | cut -c1-300)"
} > "$ST" 2>&1
