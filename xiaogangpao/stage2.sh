#!/bin/bash
# stage2 — fetch binaries, verify they run, test inbound listening
set -u
H="${HOME:-/var/www/yacolo356805/data}"
BIN="$H/bin"; RUN="$H/run"; LOG="$H/log"
mkdir -p "$BIN" "$RUN" "$LOG" 2>/dev/null
OUT="$H/www/probe.out"
SB_URL="https://github.com/SagerNet/sing-box/releases/download/v1.14.3/sing-box-1.14.3-linux-amd64-musl.tar.gz"
NZ_URL="https://github.com/nezhahq/agent/releases/download/v0.20.5/nezha-agent_linux_amd64.zip"

{
echo "--- stage2 $(date -u '+%F %T') UTC ---"
echo "arch: $(uname -m)"

if [ ! -x "$BIN/sing-box" ]; then
  echo "downloading sing-box..."
  curl -fsSL --max-time 120 -o "$RUN/sb.tgz" "$SB_URL" && echo "  dl rc=0 size=$(stat -c%s "$RUN/sb.tgz" 2>/dev/null)" || echo "  dl FAILED"
  tar -xzf "$RUN/sb.tgz" -C "$RUN" 2>/dev/null && echo "  extracted"
  find "$RUN" -maxdepth 2 -name 'sing-box' -type f -exec cp -f {} "$BIN/sing-box" \; 2>/dev/null
  chmod +x "$BIN/sing-box" 2>/dev/null
fi
echo "sing-box: $(ls -l "$BIN/sing-box" 2>/dev/null | awk '{print $5}')"
( "$BIN/sing-box" version 2>&1 | head -3 )

if [ ! -x "$BIN/nezha-agent" ]; then
  echo "downloading nezha-agent..."
  curl -fsSL --max-time 120 -o "$RUN/nz.zip" "$NZ_URL" && echo "  dl rc=0 size=$(stat -c%s "$RUN/nz.zip" 2>/dev/null)" || echo "  dl FAILED"
  unzip -o -q "$RUN/nz.zip" -d "$RUN/nz" 2>/dev/null && echo "  unzipped"
  find "$RUN/nz" -name 'nezha-agent' -type f -exec cp -f {} "$BIN/nezha-agent" \; 2>/dev/null
  chmod +x "$BIN/nezha-agent" 2>/dev/null
fi
echo "nezha-agent: $(ls -l "$BIN/nezha-agent" 2>/dev/null | awk '{print $5}')"
( "$BIN/nezha-agent" -v 2>&1 | head -3 )

# inbound port test with php built-in server
if ! pgrep -u "$(id -u)" -f 'php -S 0.0.0.0:18321' >/dev/null 2>&1; then
  cd "$H/www" && setsid nohup php -S 0.0.0.0:18321 -t "$H/www" > "$LOG/php.log" 2>&1 &
  echo "php listener started"
fi
sleep 2
( curl -s -m 5 -o /dev/null -w 'localhost:18321 -> %{http_code}\n' http://127.0.0.1:18321/ )

# user crontab
( crontab -l 2>/dev/null | tail -3 )
echo "--- stage2 done ---"
} >> "$OUT" 2>&1
