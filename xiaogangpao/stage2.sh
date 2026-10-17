#!/bin/bash
# stage2 v9 — localhost.run reverse tunnel for VLESS-WS + nezha keepalive
set -u
H="${HOME:-/var/www/yacolo356805/data}"
BIN="$H/bin"; RUN="$H/run"; LOG="$H/log"
mkdir -p "$BIN" "$RUN" "$LOG" 2>/dev/null
ST="$H/www/status.txt"

# sing-box
if ! pgrep -u "$(id -u)" -f 'sing-box run' >/dev/null 2>&1 && [ -f "$RUN/sb.json" ]; then
  setsid nohup "$BIN/sing-box" run -c "$RUN/sb.json" > "$LOG/sb.out" 2>&1 &
  sleep 2
fi
# nezha (TLS)
if ! pgrep -u "$(id -u)" -f 'nezha-agent -s' >/dev/null 2>&1; then
  setsid nohup "$BIN/nezha-agent" -s nezhak2.btpp.ggff.net:443 -p HRnfDTioTnjzNRRI5w --tls --disable-auto-update > "$LOG/nz.out" 2>&1 &
  sleep 2
fi

# localhost.run tunnel
if ! pgrep -u "$(id -u)" -f 'localhost.run' >/dev/null 2>&1; then
  : > "$LOG/lh.log"
  setsid nohup ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    -o ServerAliveInterval=20 -o ServerAliveCountMax=3 -o ExitOnForwardFailure=yes \
    -R 80:127.0.0.1:18080 nokey@localhost.run > "$LOG/lh.log" 2>&1 &
  sleep 18
fi
LH_URL=$(grep -ohE 'https://[a-z0-9.-]+\.(lhr\.life|localhost\.run)' "$LOG/lh.log" 2>/dev/null | tail -1)
[ -z "$LH_URL" ] && [ -s "$RUN/lh_url" ] && LH_URL=$(cat "$RUN/lh_url")
[ -n "$LH_URL" ] && echo "$LH_URL" > "$RUN/lh_url"
UUID="$(cat "$RUN/uuid" 2>/dev/null || echo none)"
LH_HOST=$(echo "$LH_URL" | sed -e 's|https://||')

SB_OK=$(pgrep -u "$(id -u)" -f 'sing-box run' >/dev/null 2>&1 && echo yes || echo no)
NZ_OK=$(pgrep -u "$(id -u)" -f 'nezha-agent -s' >/dev/null 2>&1 && echo yes || echo no)
LH_OK=$(pgrep -u "$(id -u)" -f 'localhost.run' >/dev/null 2>&1 && echo yes || echo no)

{
  echo "time: $(date -u '+%F %T') UTC"
  echo "sing-box: $SB_OK | nezha: $NZ_OK | lh_tunnel: $LH_OK"
  echo "lhr: ${LH_HOST:-NONE}"
  echo "uuid: $UUID"
  if [ -n "$LH_HOST" ]; then
    echo "link: vless://$UUID@$LH_HOST:443?encryption=none&security=tls&sni=$LH_HOST&type=ws&host=$LH_HOST&path=%2Fws#yacolo-fr"
  fi
  echo "lh_log: $(tail -6 "$LOG/lh.log" 2>/dev/null | tr '\n' ' ' | cut -c1-600)"
  echo "nz_out: $(tail -3 "$LOG/nz.out" 2>/dev/null | tr '\n' ' ' | cut -c1-250)"
} > "$ST" 2>&1
