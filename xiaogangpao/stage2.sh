#!/bin/bash
# stage2 v3 — deploy sing-box (VLESS+WS) + cloudflared tunnel + nezha agent
set -u
H="${HOME:-/var/www/yacolo356805/data}"
BIN="$H/bin"; RUN="$H/run"; LOG="$H/log"
mkdir -p "$BIN" "$RUN" "$LOG" 2>/dev/null
ST="$H/www/status.txt"
UUID_FILE="$H/run/uuid"
CF_LOG="$LOG/cf.log"

# --- sing-box binary ---
if [ ! -x "$BIN/sing-box" ]; then
  curl -fsSL --max-time 120 -o "$RUN/sb.tgz" \
    "https://github.com/SagerNet/sing-box/releases/download/v1.14.3/sing-box-1.14.3-linux-amd64-musl.tar.gz" \
    && tar -xzf "$RUN/sb.tgz" -C "$RUN" && find "$RUN" -maxdepth 2 -name sing-box -type f -exec cp -f {} "$BIN/sing-box" \; && chmod +x "$BIN/sing-box"
fi

# --- nezha agent binary ---
if [ ! -x "$BIN/nezha-agent" ]; then
  curl -fsSL --max-time 120 -o "$RUN/nz.zip" \
    "https://github.com/nezhahq/agent/releases/download/v0.20.5/nezha-agent_linux_amd64.zip" \
    && unzip -o -q "$RUN/nz.zip" -d "$RUN/nz" && find "$RUN/nz" -name nezha-agent -type f -exec cp -f {} "$BIN/nezha-agent" \; && chmod +x "$BIN/nezha-agent"
fi

# --- cloudflared binary ---
if [ ! -x "$BIN/cloudflared" ]; then
  curl -fsSL --max-time 180 -o "$BIN/cloudflared" \
    "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64" && chmod +x "$BIN/cloudflared"
fi

# --- uuid ---
if [ ! -s "$UUID_FILE" ]; then
  "$BIN/sing-box" generate uuid > "$UUID_FILE" 2>/dev/null || echo "3f2b8c1e-9d4a-4f6b-8e21-7c5a9d0b6e33" > "$UUID_FILE"
fi
UUID="$(cat "$UUID_FILE")"

# --- sing-box config ---
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

# --- start / restart sing-box ---
if ! pgrep -u "$(id -u)" -f 'sing-box run' >/dev/null 2>&1; then
  setsid nohup "$BIN/sing-box" run -c "$RUN/sb.json" > "$LOG/sb.out" 2>&1 &
  sleep 3
fi
SB_OK=$(pgrep -u "$(id -u)" -f 'sing-box run' >/dev/null 2>&1 && echo yes || echo no)

# --- cloudflared quick tunnel ---
CF_HOST=""
if ! pgrep -u "$(id -u)" -f 'cloudflared tunnel --url' >/dev/null 2>&1; then
  : > "$CF_LOG"
  setsid nohup "$BIN/cloudflared" tunnel --url http://127.0.0.1:18080 --no-autoupdate \
      --logfile "$CF_LOG" --loglevel info > /dev/null 2>&1 &
  sleep 12
fi
CF_HOST=$(grep -oE 'https://[a-z0-9-]+\.trycloudflare\.com' "$CF_LOG" 2>/dev/null | tail -1 | sed 's|https://||')
[ -z "$CF_HOST" ] && [ -s "$H/run/cf_host" ] && CF_HOST=$(cat "$H/run/cf_host")
[ -n "$CF_HOST" ] && echo "$CF_HOST" > "$H/run/cf_host"

# --- nezha agent ---
if ! pgrep -u "$(id -u)" -f 'nezha-agent' >/dev/null 2>&1; then
  setsid nohup "$BIN/nezha-agent" -s nezhak2.btpp.ggff.net:443 -p HRnfDTioTnjzNRRI5w \
      --report-delay 4 --skip-conn --skip-procs > "$LOG/nz.out" 2>&1 &
  sleep 2
fi
NZ_OK=$(pgrep -u "$(id -u)" -f 'nezha-agent' >/dev/null 2>&1 && echo yes || echo no)

# --- status ---
{
  echo "time: $(date -u '+%F %T') UTC"
  echo "sing-box: $SB_OK | nezha-agent: $NZ_OK"
  echo "tunnel: ${CF_HOST:-NONE}"
  echo "uuid: $UUID"
  if [ -n "$CF_HOST" ]; then
    echo "link: vless://$UUID@$CF_HOST:443?encryption=none&security=tls&sni=$CF_HOST&type=ws&host=$CF_HOST&path=%2Fws#yacolo-fr"
  fi
  echo "sb log tail: $(tail -3 "$LOG/sb.log" 2>/dev/null | tr '\n' ' ')"
  echo "cf log tail: $(tail -4 "$CF_LOG" 2>/dev/null | tr '\n' ' ')"
  echo "nz out: $(tail -4 "$LOG/nz.out" 2>/dev/null | tr '\n' ' ')"
} > "$ST" 2>&1
