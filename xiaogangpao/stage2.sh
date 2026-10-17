#!/bin/bash
# stage2 v11 — try Apache .htaccess reverse proxy for /ws (stable endpoint, no tunnel needed)
set -u
H="${HOME:-/var/www/yacolo356805/data}"
BIN="$H/bin"; RUN="$H/run"; LOG="$H/log"
mkdir -p "$BIN" "$RUN" "$LOG" 2>/dev/null
ST="$H/www/status.txt"
KEY="gOjH5FFxeRga8QbbHu"
DOC="$H/www/btpp-fr.xyz"

# --- sing-box keepalive ---
if ! pgrep -u "$(id -u)" -f 'sing-box run' >/dev/null 2>&1 && [ -f "$RUN/sb.json" ]; then
  setsid nohup "$BIN/sing-box" run -c "$RUN/sb.json" > "$LOG/sb.out" 2>&1 &
  sleep 2
fi

# --- .htaccess ws proxy ---
mkdir -p "$DOC"
cat > "$DOC/.htaccess" <<'EOF'
RewriteEngine On
RewriteCond %{HTTP:Upgrade} =websocket [NC]
RewriteRule ^ws$ http://127.0.0.1:18080/ws [P,L]
RewriteCond %{HTTP:Upgrade} !=websocket [NC]
RewriteRule ^ws$ http://127.0.0.1:18080/ws [P,L]
EOF
HT_TEST=$(curl -s -o /dev/null -w '%{http_code}' -m 8 -H 'Upgrade: websocket' -H 'Connection: Upgrade' http://127.0.0.1:80/ws 2>/dev/null)

# --- nezha keepalive ---
if ! pgrep -u "$(id -u)" -f "nezha-agent -s .* -p $KEY" >/dev/null 2>&1; then
  pkill -u "$(id -u)" -f 'nezha-agent -s' 2>/dev/null; sleep 1
  setsid nohup "$BIN/nezha-agent" -s nezhak2.btpp.ggff.net:443 -p "$KEY" --tls \
      --disable-auto-update > "$LOG/nz.out" 2>&1 &
  sleep 3
fi

# --- localhost.run tunnel keepalive (fallback) ---
if ! pgrep -u "$(id -u)" -f 'localhost.run' >/dev/null 2>&1; then
  : > "$LOG/lh.log"
  setsid nohup ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    -o ServerAliveInterval=20 -o ServerAliveCountMax=3 -o ExitOnForwardFailure=yes \
    -R 80:127.0.0.1:18080 nokey@localhost.run > "$LOG/lh.log" 2>&1 &
  sleep 12
fi
LH_URL=$(grep -ohE 'https://[a-z0-9.-]+\.(lhr\.life|localhost\.run)' "$LOG/lh.log" 2>/dev/null | tail -1)
[ -z "$LH_URL" ] && [ -s "$RUN/lh_url" ] && LH_URL=$(cat "$RUN/lh_url")
[ -n "$LH_URL" ] && echo "$LH_URL" > "$RUN/lh_url"
UUID="$(cat "$RUN/uuid" 2>/dev/null || echo none)"
LH_HOST=$(echo "${LH_URL:-}" | sed -e 's|https://||')
IP=37.187.93.226

DIRECT="vless://$UUID@$IP:80?encryption=none&security=none&type=ws&host=btpp-fr.xyz&path=%2Fws#yacolo-fr-direct"
TUNL="vless://$UUID@$LH_HOST:443?encryption=none&security=tls&sni=$LH_HOST&type=ws&host=$LH_HOST&path=%2Fws#yacolo-fr"

{
  echo "time: $(date -u '+%F %T') UTC"
  echo "sing-box: $(pgrep -u "$(id -u)" -f 'sing-box run' >/dev/null && echo yes || echo no)"
  echo "nezha: $(pgrep -u "$(id -u)" -f 'nezha-agent -s' | head -1)"
  echo "tunnel: $(pgrep -u "$(id -u)" -f 'localhost.run' >/dev/null && echo yes || echo no) $LH_HOST"
  echo "htaccess_ws_code: $HT_TEST"
  echo "link_direct: $DIRECT"
  echo "link_tunnel: $TUNL"
} > "$ST" 2>&1
cp "$ST" "$H/www/link.txt" 2>/dev/null
