#!/bin/bash
# stage2 v19 — dual ws inbounds (18080 for bore/lhr, 51231 for cloudflared) + keepalives
set -u
H="${HOME:-/var/www/yacolo356805/data}"
BIN="$H/bin"; RUN="$H/run"; LOG="$H/log"
mkdir -p "$BIN" "$RUN" "$LOG" 2>/dev/null
ST="$H/www/status.txt"
KEY="gOjH5FFxeRga8QbbHu"
SSHOPT="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ServerAliveInterval=20 -o ServerAliveCountMax=3 -o ExitOnForwardFailure=yes"
UUID="$(cat "$RUN/uuid" 2>/dev/null || echo b73e3e07-2b61-4eee-ae01-aff37757959b)"

# --- write dual-inbound config ---
cat > "$RUN/sb.new" <<EOF
{
  "log": { "level": "warn", "output": "$LOG/sb.log", "timestamp": true },
  "inbounds": [
    { "type": "vless", "tag": "ws-18080", "listen": "127.0.0.1", "listen_port": 18080,
      "users": [{ "uuid": "$UUID" }], "transport": { "type": "ws", "path": "/ws" } },
    { "type": "vless", "tag": "ws-51231", "listen": "127.0.0.1", "listen_port": 51231,
      "users": [{ "uuid": "$UUID" }], "transport": { "type": "ws", "path": "/ws" } }
  ],
  "outbounds": [{ "type": "direct", "tag": "direct" }]
}
EOF
CFG_CHANGED=0
if ! cmp -s "$RUN/sb.new" "$RUN/sb.json" 2>/dev/null; then
  mv "$RUN/sb.new" "$RUN/sb.json"; CFG_CHANGED=1
  pkill -u "$(id -u)" -f 'sing-box run' 2>/dev/null; sleep 1
fi
rm -f "$RUN/sb.new"

# --- sing-box ---
if ! pgrep -u "$(id -u)" -f 'sing-box run' >/dev/null 2>&1; then
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

# --- cloudflared ---
CFST="nofile"
if [ -s "$RUN/cf_token" ]; then
  if [ ! -x "$BIN/cloudflared" ]; then
    curl -sL -m 240 -o "$BIN/cloudflared" \
      https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 >/dev/null 2>&1
    chmod +x "$BIN/cloudflared" 2>/dev/null
  fi
  if [ -x "$BIN/cloudflared" ]; then
    if ! pgrep -u "$(id -u)" -f 'cloudflared tunnel' >/dev/null 2>&1; then
      : > "$LOG/cf.log"
      setsid nohup "$BIN/cloudflared" tunnel --no-autoupdate run --token "$(cat "$RUN/cf_token")" \
        > "$LOG/cf.log" 2>&1 &
      sleep 15
    fi
    CFST="$(pgrep -u "$(id -u)" -f 'cloudflared tunnel' | head -1)"
  else
    CFST="binfail"
  fi
fi
CFHOST=$(grep -ohE '"hostname\\":\\"[^\\"]+' "$LOG/cf.log" 2>/dev/null | tail -1 | sed -e 's/.*hostname....//' -e 's/\\//g' -e 's/"//g')
CFREG=$(grep -c 'Registered tunnel connection' "$LOG/cf.log" 2>/dev/null)
L51231=$(curl -s -o /dev/null -m 6 -w '%{http_code}' http://127.0.0.1:51231/ws 2>/dev/null)

# --- bore ---
if [ ! -x "$BIN/bore" ]; then
  curl -sL -m 120 -o "$BIN/bore.tgz" \
    https://github.com/ekzhang/bore/releases/download/v0.5.3/bore-v0.5.3-x86_64-unknown-linux-musl.tar.gz >/dev/null 2>&1
  tar xzf "$BIN/bore.tgz" -C "$BIN" bore >/dev/null 2>&1; chmod +x "$BIN/bore" 2>/dev/null; rm -f "$BIN/bore.tgz"
fi
BPORT="$(cat "$RUN/bore_port" 2>/dev/null || echo 40007)"
if ! pgrep -u "$(id -u)" -f 'bore local' >/dev/null 2>&1; then
  : > "$LOG/bore.log"
  setsid nohup "$BIN/bore" local 18080 --to bore.pub --port "$BPORT" > "$LOG/bore.log" 2>&1 &
  sleep 6
fi

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

CF_LINK="vless://$UUID@${CFHOST:-pending}:443?encryption=none&security=tls&sni=${CFHOST:-pending}&type=ws&host=${CFHOST:-pending}&path=%2Fws#yacolo-fr"
BORE_LINK="vless://$UUID@bore.pub:$BPORT?encryption=none&security=none&type=ws&host=bore.pub&path=%2Fws#yacolo-fr-bore"
if [ -n "${CFHOST:-}" ] && [ "$CFHOST" != "pending" ]; then
  curl -s -o /dev/null -m 10 --data-binary "$CF_LINK" "https://ntfy.sh/yc356805frz7k2m9q" 2>/dev/null
fi

{
  echo "time: $(date -u '+%F %T') UTC"
  echo "cfg_changed: $CFG_CHANGED"
  echo "sing-box: $(pgrep -u "$(id -u)" -f 'sing-box run' >/dev/null && echo yes || echo no) p51231=$L51231"
  echo "nezha: $(pgrep -u "$(id -u)" -f 'nezha-agent -s' | head -1)"
  echo "cloudflared: $CFST reg=$CFREG host=$CFHOST"
  echo "bore: $(pgrep -u "$(id -u)" -f 'bore local' >/dev/null && echo yes || echo no) port=$BPORT"
  echo "lhr: $LH_HOST"
  echo "link_cf: $CF_LINK"
  echo "link_bore: $BORE_LINK"
} > "$ST" 2>&1
cp "$ST" "$H/www/link.txt" 2>/dev/null
