#!/bin/bash
# stage2 v16 — stable endpoint via bore.pub fixed port + nezha + lhr fallback + plain-text sub
set -u
H="${HOME:-/var/www/yacolo356805/data}"
BIN="$H/bin"; RUN="$H/run"; LOG="$H/log"
mkdir -p "$BIN" "$RUN" "$LOG" 2>/dev/null
ST="$H/www/status.txt"
KEY="gOjH5FFxeRga8QbbHu"
TOPIC="yc356805frz7k2m9q"
SSHOPT="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ServerAliveInterval=20 -o ServerAliveCountMax=3 -o ExitOnForwardFailure=yes"

# --- sing-box ---
if ! pgrep -u "$(id -u)" -f 'sing-box run' >/dev/null 2>&1 && [ -f "$RUN/sb.json" ]; then
  setsid nohup "$BIN/sing-box" run -c "$RUN/sb.json" > "$LOG/sb.out" 2>&1 &
  sleep 2
fi

# --- nezha ---
if ! pgrep -u "$(id -u)" -f "nezha-agent -s .* -p $KEY" >/dev/null 2>&1; then
  pkill -u "$(id -u)" -f 'nezha-agent -s' 2>/dev/null; sleep 1
  setsid nohup "$BIN/nezha-agent" -s nezhak2.btpp.ggff.net:443 -p "$KEY" --tls \
      --disable-auto-update > "$LOG/nz.out" 2>&1 &
  sleep 2
fi

# --- bore binary ---
if [ ! -x "$BIN/bore" ]; then
  curl -sL -m 120 -o "$BIN/bore.tgz" \
    https://github.com/ekzhang/bore/releases/download/v0.5.3/bore-v0.5.3-x86_64-unknown-linux-musl.tar.gz \
    >/dev/null 2>&1
  tar xzf "$BIN/bore.tgz" -C "$BIN" bore >/dev/null 2>&1
  chmod +x "$BIN/bore" 2>/dev/null
  rm -f "$BIN/bore.tgz"
fi

# --- bore tunnel on a fixed port ---
BPORT="$(cat "$RUN/bore_port" 2>/dev/null || echo 40007)"
if ! pgrep -u "$(id -u)" -f 'bore local' >/dev/null 2>&1; then
  : > "$LOG/bore.log"
  setsid nohup "$BIN/bore" local 18080 --to bore.pub --port "$BPORT" > "$LOG/bore.log" 2>&1 &
  sleep 6
  if ! pgrep -u "$(id -u)" -f 'bore local' >/dev/null 2>&1; then
    for p in 40007 40008 40009 40010 40011 40012; do
      : > "$LOG/bore.log"
      setsid nohup "$BIN/bore" local 18080 --to bore.pub --port "$p" > "$LOG/bore.log" 2>&1 &
      sleep 5
      if pgrep -u "$(id -u)" -f 'bore local' >/dev/null 2>&1; then
        BPORT="$p"; echo "$p" > "$RUN/bore_port"; break
      fi
    done
  fi
fi
BORE_LOG=$(tr '\n' ' ' < "$LOG/bore.log" 2>/dev/null | cut -c1-160)

# --- lhr fallback ---
if ! pgrep -u "$(id -u)" -f 'localhost.run' >/dev/null 2>&1; then
  : > "$LOG/lh.log"
  setsid nohup ssh $SSHOPT -R 80:127.0.0.1:18080 nokey@localhost.run > "$LOG/lh.log" 2>&1 &
  sleep 12
fi
LH_URL=$(grep -ohE 'https://[a-z0-9.-]+\.(lhr\.life|localhost\.run)' "$LOG/lh.log" 2>/dev/null | tail -1)
[ -z "$LH_URL" ] && [ -s "$RUN/lh_url" ] && LH_URL=$(cat "$RUN/lh_url")
[ -n "$LH_URL" ] && echo "$LH_URL" > "$RUN/lh_url"
LH_HOST=$(echo "${LH_URL:-}" | sed -e 's|https://||')

UUID="$(cat "$RUN/uuid" 2>/dev/null || echo none)"
BORE_LINK="vless://$UUID@bore.pub:$BPORT?encryption=none&security=none&type=ws&host=bore.pub&path=%2Fws#yacolo-fr-bore"
TUNL="vless://$UUID@$LH_HOST:443?encryption=none&security=tls&sni=$LH_HOST&type=ws&host=$LH_HOST&path=%2Fws#yacolo-fr"

# --- publish plain-text subscription (newest link first) ---
PUB=$(curl -s -o /dev/null -m 10 -w '%{http_code}' \
  --data-binary "$BORE_LINK" "https://ntfy.sh/$TOPIC" 2>/dev/null)

{
  echo "time: $(date -u '+%F %T') UTC"
  echo "sing-box: $(pgrep -u "$(id -u)" -f 'sing-box run' >/dev/null && echo yes || echo no)"
  echo "nezha: $(pgrep -u "$(id -u)" -f 'nezha-agent -s' | head -1)"
  echo "bore: $(pgrep -u "$(id -u)" -f 'bore local' >/dev/null && echo yes || echo no) port=$BPORT | $BORE_LOG"
  echo "lhr: $(pgrep -u "$(id -u)" -f 'localhost.run' >/dev/null && echo yes || echo no) $LH_HOST"
  echo "pub: $PUB"
  echo "link_bore: $BORE_LINK"
  echo "link_tunnel: $TUNL"
} > "$ST" 2>&1
cp "$ST" "$H/www/link.txt" 2>/dev/null
