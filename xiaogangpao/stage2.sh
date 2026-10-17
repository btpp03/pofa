#!/bin/bash
# stage2 v13 — find the live docroot + install /ws proxy .htaccess there
set -u
H="${HOME:-/var/www/yacolo356805/data}"
BIN="$H/bin"; RUN="$H/run"; LOG="$H/log"
mkdir -p "$BIN" "$RUN" "$LOG" 2>/dev/null
ST="$H/www/status.txt"
KEY="gOjH5FFxeRga8QbbHu"
IP=37.187.93.226

if ! pgrep -u "$(id -u)" -f 'sing-box run' >/dev/null 2>&1 && [ -f "$RUN/sb.json" ]; then
  setsid nohup "$BIN/sing-box" run -c "$RUN/sb.json" > "$LOG/sb.out" 2>&1 &
  sleep 2
fi
if ! pgrep -u "$(id -u)" -f "nezha-agent -s .* -p $KEY" >/dev/null 2>&1; then
  pkill -u "$(id -u)" -f 'nezha-agent -s' 2>/dev/null; sleep 1
  setsid nohup "$BIN/nezha-agent" -s nezhak2.btpp.ggff.net:443 -p "$KEY" --tls \
      --disable-auto-update > "$LOG/nz.out" 2>&1 &
  sleep 2
fi
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
LH_HOST=$(echo "${LH_URL:-}" | sed -e 's|https://||')

# .htaccess in both candidate docroots
HT='RewriteEngine On
RewriteCond %{HTTP:Upgrade} =websocket [NC]
RewriteRule ^ws$ http://127.0.0.1:18080/ws [P,L]
RewriteRule ^ws$ http://127.0.0.1:18080/ws [P,L]'
printf '%s\n' "$HT" > "$H/www/.htaccess"
mkdir -p "$H/www/btpp-fr.xyz"
printf '%s\n' "$HT" > "$H/www/btpp-fr.xyz/.htaccess"
echo probe > "$H/www/zz_probe.txt"

D1=$(curl -s -o /dev/null -m 8 -w '%{http_code}' "http://$IP/zz_probe.txt" 2>/dev/null)
D2=$(curl -s -o /dev/null -m 8 -w '%{http_code}' -H 'Host: btpp-fr.xyz' "http://$IP/zz_probe.txt" 2>/dev/null)
D3=$(curl -s -o /dev/null -m 8 -w '%{http_code}' "http://$IP/btpp-fr.xyz/zz_probe.txt" 2>/dev/null)
D4=$(curl -s -o /dev/null -m 8 -w '%{http_code}' "http://$IP/ws" 2>/dev/null)
D5=$(curl -s -o /dev/null -m 8 -w '%{http_code}' -H 'Host: btpp-fr.xyz' "http://$IP/ws" 2>/dev/null)
D6=$(curl -s -o /dev/null -m 8 -w '%{http_code}' -H 'Host: www.btpp-fr.xyz' "http://$IP/ws" 2>/dev/null)

UUID="$(cat "$RUN/uuid" 2>/dev/null || echo none)"
DIRECT="vless://$UUID@$IP:80?encryption=none&security=none&type=ws&host=$IP&path=%2Fws#yacolo-fr-direct"
TUNL="vless://$UUID@$LH_HOST:443?encryption=none&security=tls&sni=$LH_HOST&type=ws&host=$LH_HOST&path=%2Fws#yacolo-fr"

{
  echo "time: $(date -u '+%F %T') UTC"
  echo "sandbox=$D1 hosthdr=$D2 subdir=$D3 ws_plain=$D4 ws_host=$D5 ws_www=$D6"
  echo "sing-box: $(pgrep -u "$(id -u)" -f 'sing-box run' >/dev/null && echo yes || echo no)"
  echo "nezha: $(pgrep -u "$(id -u)" -f 'nezha-agent -s' | head -1)"
  echo "tunnel: $(pgrep -u "$(id -u)" -f 'localhost.run' >/dev/null && echo yes || echo no) $LH_HOST"
  echo "link_direct: $DIRECT"
  echo "link_tunnel: $TUNL"
} > "$ST" 2>&1
cp "$ST" "$H/www/link.txt" 2>/dev/null
