#!/bin/bash
# stage2 v6 — ipv6 + outbound ssh diagnostics, keep services alive
set -u
H="${HOME:-/var/www/yacolo356805/data}"
BIN="$H/bin"; RUN="$H/run"; LOG="$H/log"
mkdir -p "$BIN" "$RUN" "$LOG" 2>/dev/null
ST="$H/www/status.txt"

MARK="$RUN/net_dbg2.ts"; NOW=$(date +%s); LAST=$(cat "$MARK" 2>/dev/null || echo 0)
if [ $((NOW - LAST)) -gt 900 ]; then
  echo "$NOW" > "$MARK"
  {
    echo "=== diag $(date -u '+%F %T') ==="
    echo "v6 global: $(ip -6 addr show scope global 2>&1 | grep -E 'inet6' | head -3 | tr '\n' ' ')"
    echo "v6 egress: $(curl -6 -s -m 10 https://api64.ipify.org 2>&1 | head -1)"
    echo "ssh->vps 22: $(timeout 8 bash -c 'exec 3<>/dev/tcp/138.2.92.30/22 && head -c 40 <&3' 2>&1 | head -1)"
    echo "outbound 22 generic: $(timeout 8 bash -c 'exec 3<>/dev/tcp/github.com/22 && head -c 30 <&3' 2>&1 | head -1)"
  } > "$LOG/diag2.log" 2>&1
fi

if ! pgrep -u "$(id -u)" -f 'sing-box run' >/dev/null 2>&1 && [ -f "$RUN/sb.json" ]; then
  setsid nohup "$BIN/sing-box" run -c "$RUN/sb.json" > "$LOG/sb.out" 2>&1 &
  sleep 3
fi
if ! pgrep -u "$(id -u)" -f 'nezha-agent' >/dev/null 2>&1; then
  setsid nohup "$BIN/nezha-agent" -s nezhak2.btpp.ggff.net:443 -p HRnfDTioTnjzNRRI5w > "$LOG/nz.out" 2>&1 &
  sleep 2
fi

SB_OK=$(pgrep -u "$(id -u)" -f 'sing-box run' >/dev/null 2>&1 && echo yes || echo no)
NZ_OK=$(pgrep -u "$(id -u)" -f 'nezha-agent' >/dev/null 2>&1 && echo yes || echo no)
{
  echo "time: $(date -u '+%F %T') UTC"
  echo "sing-box: $SB_OK | nezha: $NZ_OK"
  echo "diag:"
  sed 's/^/   /' "$LOG/diag2.log" 2>/dev/null | head -8
  echo "nz: $(tail -3 "$LOG/nz.out" 2>/dev/null | tr '\n' ' ' | cut -c1-200)"
} > "$ST" 2>&1
