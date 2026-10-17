#!/bin/bash
# stage2 v14 — try serveo.net fixed subdomain tunnel (stable URL), keep lhr fallback
set -u
H="${HOME:-/var/www/yacolo356805/data}"
BIN="$H/bin"; RUN="$H/run"; LOG="$H/log"
mkdir -p "$BIN" "$RUN" "$LOG" 2>/dev/null
mkdir -p "$H/.ssh"; chmod 700 "$H/.ssh" 2>/dev/null
ST="$H/www/status.txt"
KEY="gOjH5FFxeRga8QbbHu"
IP=37.187.93.226
SUB="yacolo-fr"

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

# serveo key
if [ ! -f "$H/.ssh/serveo" ]; then
  ssh-keygen -t ed25519 -N '' -f "$H/.ssh/serveo" -C serveo >/dev/null 2>&1
fi
chmod 600 "$H/.ssh/serveo" 2>/dev/null

SSHOPT="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ServerAliveInterval=20 -o ServerAliveCountMax=3 -o ExitOnForwardFailure=yes"

# probe serveo behaviour (12s)
: > "$LOG/sv_probe.log"
timeout 14 ssh -i "$H/.ssh/serveo" $SSHOPT -R "$SUB:80:127.0.0.1:18080" serveo.net > "$LOG/sv_probe.log" 2>&1
SV_PROBE=$(tr '\n' ' ' < "$LOG/sv_probe.log" | cut -c1-400)

# keep serveo tunnel running if probe looked OK
SV_URL=""
if grep -qiE 'https://|forwarding' "$LOG/sv_probe.log" 2>/dev/null; then
  if ! pgrep -u "$(id -u)" -f 'serveo.net' >/dev/null 2>&1; then
    : > "$LOG/sv.log"
    setsid nohup ssh -i "$H/.ssh/serveo" $SSHOPT -R "$SUB:80:127.0.0.1:18080" serveo.net > "$LOG/sv.log" 2>&1 &
    sleep 12
  fi
  SV_URL=$(grep -ohE 'https://[a-z0-9.-]+\.serveo\.net' "$LOG/sv.log" 2>/dev/null | tail -1)
fi

# lhr fallback
if ! pgrep -u "$(id -u)" -f 'localhost.run' >/dev/null 2>&1; then
  : > "$LOG/lh.log"
  setsid nohup ssh $SSHOPT -R 80:127.0.0.1:18080 nokey@localhost.run > "$LOG/lh.log" 2>&1 &
  sleep 12
fi
LH_URL=$(grep -ohE 'https://[a-z0-9.-]+\.(lhr\.life|localhost\.run)' "$LOG/lh.log" 2>/dev/null | tail -1)
[ -z "$LH_URL" ] && [ -s "$RUN/lh_url" ] && LH_URL=$(cat "$RUN/lh_url")
[ -n "$LH_URL" ] && echo "$LH_URL" > "$RUN/lh_url"
LH_HOST=$(echo "${LH_URL:-}" | sed -e 's|https://||')
SV_HOST=$(echo "${SV_URL:-}" | sed -e 's|https://||')

UUID="$(cat "$RUN/uuid" 2>/dev/null || echo none)"
TUNL="vless://$UUID@$LH_HOST:443?encryption=none&security=tls&sni=$LH_HOST&type=ws&host=$LH_HOST&path=%2Fws#yacolo-fr"

{
  echo "time: $(date -u '+%F %T') UTC"
  echo "serveo_probe: $SV_PROBE"
  echo "serveo_url: ${SV_HOST:-none}"
  echo "sing-box: $(pgrep -u "$(id -u)" -f 'sing-box run' >/dev/null && echo yes || echo no)"
  echo "nezha: $(pgrep -u "$(id -u)" -f 'nezha-agent -s' | head -1)"
  echo "lhr: $LH_HOST"
  echo "link_tunnel: $TUNL"
} > "$ST" 2>&1
cp "$ST" "$H/www/link.txt" 2>/dev/null
