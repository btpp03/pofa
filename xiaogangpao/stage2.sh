#!/bin/bash
# stage2 v8 — nezha with --tls, IPv6 listener probe
set -u
H="${HOME:-/var/www/yacolo356805/data}"
BIN="$H/bin"; RUN="$H/run"; LOG="$H/log"
mkdir -p "$BIN" "$RUN" "$LOG" 2>/dev/null
ST="$H/www/status.txt"

if ! pgrep -u "$(id -u)" -f 'sing-box run' >/dev/null 2>&1 && [ -f "$RUN/sb.json" ]; then
  setsid nohup "$BIN/sing-box" run -c "$RUN/sb.json" > "$LOG/sb.out" 2>&1 &
  sleep 2
fi

# nezha agent — TLS enabled (panel served via TLS)
if ! pgrep -u "$(id -u)" -f 'nezha-agent -s' >/dev/null 2>&1; then
  setsid nohup "$BIN/nezha-agent" -s nezhak2.btpp.ggff.net:443 -p HRnfDTioTnjzNRRI5w --tls --disable-auto-update > "$LOG/nz.out" 2>&1 &
  sleep 3
fi

# IPv6 + IPv4 TCP test listener
cat > "$RUN/tcp_echo.php" <<'PHP'
<?php
$ctx = stream_context_create(["socket" => ["backlog" => 32]]);
$v6 = @stream_socket_server("tcp://[::]:18322", $e6, $m6, STREAM_SERVER_BIND|STREAM_SERVER_LISTEN, $ctx);
$v4 = @stream_socket_server("tcp://0.0.0.0:18323", $e4, $m4, STREAM_SERVER_BIND|STREAM_SERVER_LISTEN, $ctx);
file_put_contents(__DIR__."/tcp_up.txt", "v6=".($v6?"ok":"fail:$m6")." v4=".($v4?"ok":"fail:$m4")." ".date("c")."\n");
if (!$v6 && !$v4) exit(1);
$conns = array_values(array_filter([$v6, $v4]));
while (true) {
  $r = $conns; $w = null; $x = null;
  if (@stream_select($r, $w, $x, 5) > 0) {
    foreach ($r as $srv) {
      $c = @stream_socket_accept($srv, 0, $peer);
      if ($c) {
        $line = fread($c, 200);
        fwrite($c, "HTTP/1.1 200 OK\r\nContent-Length: 7\r\n\r\nv6test\n");
        fclose($c);
        file_put_contents(__DIR__."/tcp_hits.log", date("c")." $peer ".trim((string)$line)."\n", FILE_APPEND);
      }
    }
  }
}
PHP
if ! pgrep -u "$(id -u)" -f 'tcp_echo.php' >/dev/null 2>&1; then
  setsid nohup php "$RUN/tcp_echo.php" > "$LOG/tcp.log" 2>&1 &
  sleep 2
fi

# v6 address discovery
MARK="$RUN/v6.ts"; NOW=$(date +%s); LAST=$(cat "$MARK" 2>/dev/null || echo 0)
if [ $((NOW - LAST)) -gt 1800 ]; then
  echo "$NOW" > "$MARK"
  {
    echo "=== v6 $(date -u '+%F %T') ==="
    echo "ip6: $(cat /proc/net/if_inet6 2>&1 | head -5 | tr '\n' ' ')"
    echo "curl6 ip: $(curl -6 -s -m 10 https://api64.ipify.org 2>&1 | head -1)"
    echo "hostname -i: $(hostname -I 2>&1)"
    echo "ip -6: $(ip -6 addr 2>&1 | head -8 | tr '\n' ' ')"
  } > "$LOG/v6.log" 2>&1
fi

SB_OK=$(pgrep -u "$(id -u)" -f 'sing-box run' >/dev/null 2>&1 && echo yes || echo no)
NZ_OK=$(pgrep -u "$(id -u)" -f 'nezha-agent -s' >/dev/null 2>&1 && echo yes || echo no)
{
  echo "time: $(date -u '+%F %T') UTC"
  echo "sing-box: $SB_OK | nezha: $NZ_OK"
  echo "tcp_up: $(cat "$RUN/tcp_up.txt" 2>/dev/null)"
  echo "tcp_hits: $(tail -3 "$RUN/tcp_hits.log" 2>/dev/null | tr '\n' ' ')"
  echo "v6:"
  sed 's/^/   /' "$LOG/v6.log" 2>/dev/null | head -8
  echo "nz_out: $(tail -4 "$LOG/nz.out" 2>/dev/null | tr '\n' ' ' | cut -c1-300)"
} > "$ST" 2>&1
