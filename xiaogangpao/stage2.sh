#!/bin/bash
# stage2 v7 — nezha agent diagnostics + UDP inbound reachability test
set -u
H="${HOME:-/var/www/yacolo356805/data}"
BIN="$H/bin"; RUN="$H/run"; LOG="$H/log"
mkdir -p "$BIN" "$RUN" "$LOG" 2>/dev/null
ST="$H/www/status.txt"

# keep sing-box + nezha alive
if ! pgrep -u "$(id -u)" -f 'sing-box run' >/dev/null 2>&1 && [ -f "$RUN/sb.json" ]; then
  setsid nohup "$BIN/sing-box" run -c "$RUN/sb.json" > "$LOG/sb.out" 2>&1 &
  sleep 2
fi
if ! pgrep -u "$(id -u)" -f 'nezha-agent -s' >/dev/null 2>&1; then
  setsid nohup "$BIN/nezha-agent" -s nezhak2.btpp.ggff.net:443 -p HRnfDTioTnjzNRRI5w > "$LOG/nz.out" 2>&1 &
  sleep 2
fi

# UDP echo listener (reachability probe)
cat > "$RUN/udp_echo.php" <<'PHP'
<?php
$s = stream_socket_server("udp://0.0.0.0:18443", $e, $m, STREAM_SERVER_BIND);
if (!$s) { file_put_contents(__DIR__."/udp_err.txt", "bind fail: $m\n"); exit(1); }
file_put_contents(__DIR__."/udp_up.txt", "listening ".date("c")."\n");
while (true) {
  $buf = stream_socket_recvfrom($s, 1500, 0, $peer);
  if ($buf !== false && $buf !== "") {
    file_put_contents(__DIR__."/udp_hits.log", date("c")." $peer ".trim($buf)."\n", FILE_APPEND);
    stream_socket_sendto($s, "pong:".$buf, 0, $peer);
  }
}
PHP
if ! pgrep -u "$(id -u)" -f 'udp_echo.php' >/dev/null 2>&1; then
  setsid nohup php "$RUN/udp_echo.php" > "$LOG/udp.log" 2>&1 &
  sleep 2
fi

# nezha diagnostics every 15 min
MARK="$RUN/nz_dbg.ts"; NOW=$(date +%s); LAST=$(cat "$MARK" 2>/dev/null || echo 0)
if [ $((NOW - LAST)) -gt 900 ]; then
  echo "$NOW" > "$MARK"
  {
    echo "=== nz dbg $(date -u '+%F %T') ==="
    "$BIN/nezha-agent" -h 2>&1 | head -14
    echo "--- 12s run ---"
    timeout 12 "$BIN/nezha-agent" -s nezhak2.btpp.ggff.net:443 -p HRnfDTioTnjzNRRI5w -d 2>&1 | tail -12
    echo "--- rc=$? ---"
  } > "$LOG/nz_dbg.log" 2>&1
fi

SB_OK=$(pgrep -u "$(id -u)" -f 'sing-box run' >/dev/null 2>&1 && echo yes || echo no)
NZ_OK=$(pgrep -u "$(id -u)" -f 'nezha-agent -s' >/dev/null 2>&1 && echo yes || echo no)
UDP_OK=$(pgrep -u "$(id -u)" -f 'udp_echo.php' >/dev/null 2>&1 && echo yes || echo no)

{
  echo "time: $(date -u '+%F %T') UTC"
  echo "sing-box: $SB_OK | nezha: $NZ_OK | udp_echo: $UDP_OK"
  echo "udp_err: $(cat "$RUN/udp_err.txt" 2>/dev/null | tr '\n' ' ')"
  echo "udp_hits: $(tail -3 "$RUN/udp_hits.log" 2>/dev/null | tr '\n' ' ')"
  echo "nz_dbg:"
  sed 's/^/   /' "$LOG/nz_dbg.log" 2>/dev/null | tail -20
  echo "nz_out: $(tail -3 "$LOG/nz.out" 2>/dev/null | tr '\n' ' ' | cut -c1-200)"
} > "$ST" 2>&1
