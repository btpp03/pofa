#!/bin/sh

export UUID='faacf142-dee8-48c2-8558-641123eb939c'
export NEZHA_SERVER='nezhak2.btpp.ggff.net'
export NEZHA_PORT='443'
export NEZHA_KEY=''
export HY2_PORT=''
export ARGO_DOMAIN='mlxy.btppone.hidns.vip'
export ARGO_AUTH='eyJhIjoiYmJmMDc4YjVkYjlhMzcwMmFiYTg3OGQyODYxMDUwMDciLCJ0IjoiZTdjY2JkYmEtNWQwZC00ZWQxLWEzNDUtMzI3NmE2NmI5ZmFhIiwicyI6Ik9HWmxNbUprWXpFdE1tRmhOaTAwTldNNUxUa3dOR010WkRsaE1EVXhOemN4WW1RMiJ9'
export CFIP='jd.bp.cloudns.ch'

SCRIPT_URL='https://main.ssss.nyc.mn/sb.sh'
TMP_SCRIPT='./tmp_sb.sh'
CLEANUP_DELAY=60

download_script() {
    if command -v curl >/dev/null 2>&1; then
        curl -Ls "$SCRIPT_URL" > "$TMP_SCRIPT"
    elif command -v wget >/dev/null 2>&1; then
        wget -qO- "$SCRIPT_URL" > "$TMP_SCRIPT"
    else
        exit 1
    fi
}

download_script || exit 1

sed -i '/Error: neither curl nor/d' "$TMP_SCRIPT" 2>/dev/null
sed -i 's/\$COMMAND sbx "https:\/\/\$ARCH\.ssss\.nyc\.mn\/sbsh"/curl -o sbx "https:\/\/\$ARCH.ssss.nyc.mn\/sbsh"/g' "$TMP_SCRIPT" 2>/dev/null

if [ ! -s "$TMP_SCRIPT" ]; then
    rm -f "$TMP_SCRIPT" 2>/dev/null
    exit 1
fi

sh "$TMP_SCRIPT" >/dev/null 2>&1

SETUP_EXIT_CODE=$?

rm -f "$TMP_SCRIPT" 2>/dev/null

if [ "$SETUP_EXIT_CODE" -ne 0 ]; then
    exit 1
fi

(
    sleep "$CLEANUP_DELAY"
    rm -rf './.tmp' 2>/dev/null
) &

exec tail -f /dev/null >/dev/null 2>&1
