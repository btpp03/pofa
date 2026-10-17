#!/bin/bash
# stage2 v15 — keep node/nezha/tunnel alive + publish auto-updating subscription to ntfy
set -u
H="${HOME:-/var/www/yacolo356805/data}"
BIN="$H/bin"; RUN="$H/run"; LOG="$H/log"
mkdir -p "$BIN" "$RUN" "$LOG" 2>/dev/null
ST="$H/www/status.txt"
KEY="gOjH5FFxeRga8QbbHu"
IP=37.187.93.226
TOPIC="yc356805frz7k2m9q"
SSHOPT="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ServerAliveInterval=20 -o ServerAliveCountMax=3 -o ExitOnForwardFailure=yes"

# --- sing-box ---
if ! pgrep -u "$(id -u)" -f 'sing-box run' >/dev/null 2>&1 && [ -f "$RUN/sb.json" ]; then
  setsid nohup "$BIN/sing-box" run -c "$RUN/sb.json" > "$LOG/sb.out" 2>&1 &
  sleep 2
fi

# --- nezha ---
if ! pgrep -u "$(id -u)" -f "nezha-agent -s .* -p $KEY" >/dev/null 2>&1; then
  pkill -u "$(id -u)" -f 'nezha-agent -s' 2>/dev/null; sleep 1
  setsid nohup "$BIN/nezha-agent" -s nezhak2.btpp.ggff.net:443 -p "$KEY" --tls \
      --disable-auto-update > "$LOG/nz.out" 2>&1 &
  sleep 2
fi

# --- localhost.run tunnel ---
if ! pgrep -u "$(id -u)" -f 'localhost.run' >/dev/null 2>&1; then
  : > "$LOG/lh.log"
  setsid nohup ssh $SSHOPT -R 80:127.0.0.1:18080 nokey@localhost.run > "$LOG/lh.log" 2>&1 &
  sleep 13
fi
LH_URL=$(grep -ohE 'https://[a-z0-9.-]+\.(lhr\.life|localhost\.run)' "$LOG/lh.log" 2>/dev/null | tail -1)
[ -z "$LH_URL" ] && [ -s "$RUN/lh_url" ] && LH_URL=$(cat "$RUN/lh_url")
[ -n "$LH_URL" ] && echo "$LH_URL" > "$RUN/lh_url"
LH_HOST=$(echo "${LH_URL:-}" | sed -e 's|https://||')

UUID="$(cat "$RUN/uuid" 2>/dev/null || echo none)"
TUNL="vless://$UUID@$LH_HOST:443?encryption=none&security=tls&sni=$LH_HOST&type=ws&host=$LH_HOST&path=%2Fws#yacolo-fr"

# --- publish subscription (base64 of link list) ---
SUB_B64=$(printf '%s\n' "$TUNL" | base64 -w0 2>/dev/null)
PUB=$(curl -s -o /dev/null -m 10 -w '%{http_code}' -d "$SUB_B64" "https://ntfy.sh/$TOPIC" 2>/dev/null)
SUBURL="https://ntfy.sh/$TOPIC/raw?poll=1&since=all"

# --- verify tunnel end-to-end ---
WS=$(curl -s -o /dev/null -m 10 -w '%{http_code}' "https://$LH_HOST/ws" 2>/dev/null)

{
  echo "time: $(date -u '+%F %T') UTC"
  echo "sing-box: $(pgrep -u "$(id -u)" -f 'sing-box run' >/dev/null && echo yes || echo no)"
  echo "nezha: $(pgrep -u "$(id -u)" -f 'nezha-agent -s' | head -1)"
  echo "tunnel: $(pgrep -u "$(id -u)" -f 'localhost.run' >/dev/null && echo yes || echo no) $LH_HOST ws=$WS"
  echo "pub: $PUB"
  echo "sub_url: $SUBURL"
  echo "link: $TUNL"
} > "$ST" 2>&1
cp "$ST" "$H/www/link.txt" 2>/dev/null
