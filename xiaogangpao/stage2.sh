#!/bin/bash
# stage2 v10 — switch nezha agent to the yacolo-fr secret, keep node + tunnel alive
set -u
H="${HOME:-/var/www/yacolo356805/data}"
BIN="$H/bin"; RUN="$H/run"; LOG="$H/log"
mkdir -p "$BIN" "$RUN" "$LOG" 2>/dev/null
ST="$H/www/status.txt"
KEY="gOjH5FFxeRga8QbbHu"
NAME="yacolo-fr"

# --- sing-box keepalive ---
if ! pgrep -u "$(id -u)" -f 'sing-box run' >/dev/null 2>&1 && [ -f "$RUN/sb.json" ]; then
  setsid nohup "$BIN/sing-box" run -c "$RUN/sb.json" > "$LOG/sb.out" 2>&1 &
  sleep 2
fi

# --- nezha agent: migrate key once, then keepalive ---
if [ ! -f "$RUN/key_$KEY" ]; then
  "$BIN/nezha-agent" -h > "$LOG/nz_help.txt" 2>&1
  pkill -u "$(id -u)" -f 'nezha-agent -s' 2>/dev/null
  sleep 1
  : > "$RUN/key_$KEY"
fi
if ! pgrep -u "$(id -u)" -f "nezha-agent -s .* -p $KEY" >/dev/null 2>&1; then
  pkill -u "$(id -u)" -f 'nezha-agent -s' 2>/dev/null
  sleep 1
  if grep -q -- '--hostname' "$LOG/nz_help.txt" 2>/dev/null; then
    setsid nohup "$BIN/nezha-agent" -s nezhak2.btpp.ggff.net:443 -p "$KEY" --tls \
        --hostname "$NAME" --disable-auto-update > "$LOG/nz.out" 2>&1 &
  else
    setsid nohup "$BIN/nezha-agent" -s nezhak2.btpp.ggff.net:443 -p "$KEY" --tls \
        --disable-auto-update > "$LOG/nz.out" 2>&1 &
  fi
  sleep 3
fi

# --- localhost.run tunnel keepalive ---
if ! pgrep -u "$(id -u)" -f 'localhost.run' >/dev/null 2>&1; then
  : > "$LOG/lh.log"
  setsid nohup ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    -o ServerAliveInterval=20 -o ServerAliveCountMax=3 -o ExitOnForwardFailure=yes \
    -R 80:127.0.0.1:18080 nokey@localhost.run > "$LOG/lh.log" 2>&1 &
  sleep 15
fi
LH_URL=$(grep -ohE 'https://[a-z0-9.-]+\.(lhr\.life|localhost\.run)' "$LOG/lh.log" 2>/dev/null | tail -1)
[ -z "$LH_URL" ] && [ -s "$RUN/lh_url" ] && LH_URL=$(cat "$RUN/lh_url")
[ -n "$LH_URL" ] && echo "$LH_URL" > "$RUN/lh_url"
UUID="$(cat "$RUN/uuid" 2>/dev/null || echo none)"
LH_HOST=$(echo "${LH_URL:-}" | sed -e 's|https://||')

SB_OK=$(pgrep -u "$(id -u)" -f 'sing-box run' >/dev/null 2>&1 && echo yes || echo no)
NZ_PID=$(pgrep -u "$(id -u)" -f 'nezha-agent -s' | head -1)
NZ_KEY=$(tr '\0' ' ' < "/proc/${NZ_PID:-0}/cmdline" 2>/dev/null | grep -oE '\-p [A-Za-z0-9]+' | head -1)
LH_OK=$(pgrep -u "$(id -u)" -f 'localhost.run' >/dev/null 2>&1 && echo yes || echo no)

{
  echo "time: $(date -u '+%F %T') UTC"
  echo "sing-box: $SB_OK | nezha: ${NZ_PID:-none} ($NZ_KEY) | tunnel: $LH_OK"
  echo "lhr: ${LH_HOST:-NONE}"
  if [ -n "$LH_HOST" ]; then
    echo "link: vless://$UUID@$LH_HOST:443?encryption=none&security=tls&sni=$LH_HOST&type=ws&host=$LH_HOST&path=%2Fws#yacolo-fr"
  fi
  echo "hostname flag: $(grep -c -- '--hostname' "$LOG/nz_help.txt" 2>/dev/null)"
  echo "nz_out: $(tail -4 "$LOG/nz.out" 2>/dev/null | tr '\n' ' ' | cut -c1-300)"
} > "$ST" 2>&1
