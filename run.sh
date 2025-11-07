#!/bin/bash

export UUID=${UUID:-''} # 如开启哪吒v1,不同的平台需要改一下，否则会覆盖
export NEZHA_SERVER=${NEZHA_SERVER:-''}       # v1哪吒填写形式：nezha.abc.com:8008,v0哪吒填写形式：nezha.abc.com
export NEZHA_PORT=${NEZHA_PORT:-''}           # v1哪吒不要填写这个,v0哪吒agent端口为{443,8443,2053,2083,2087,2096}其中之一时自动开启tls
export NEZHA_KEY=${NEZHA_KEY:-''}             # 哪吒v0-agent密钥或v1的NZ_CLIENT_SECRET
export ARGO_DOMAIN=${ARGO_DOMAIN:-''}         # 固定隧道域名,留空即启用临时隧道
export ARGO_AUTH=${ARGO_AUTH:-''}             # 固定隧道token或json,留空即启用临时隧道
export CFIP=${CFIP:-'cf.877774.xyz'}          # argo节点优选域名或优选ip
export CFPORT=${CFPORT:-'443'}                # argo节点端口 
export NAME=${NAME:-''}                       # 节点名称  
export FILE_PATH=${FILE_PATH:-'./'}           # 节点sub.txt保存路径
export ARGO_PORT=${ARGO_PORT:-''}         # argo端口 使用固定隧道token,cloudflare后台设置的端口需和这里对应
export CHAT_ID=${CHAT_ID:-''}                 # TG chat_id，可在https://t.me/laowang_serv00_bot 获取
export BOT_TOKEN=${BOT_TOKEN:-''}             # TG bot_token, 使用自己的bot需要填写,使用上方的bot不用填写,不会给别人发送
export UPLOAD_URL=${UPLOAD_URL:-''}  # 订阅自动上传地址,没有可不填,需要填部署Merge-sub项目后的首页地址,例如：https://merge.zabc.net
export DISABLE_ARGO=${DISABLE_ARGO:-'false'}  # 是否禁用argo, true为禁用,false为不禁用

delete_old_nodes() {
  [[ -z $UPLOAD_URL || ! -f "${FILE_PATH}/sub.txt" ]] && return
  old_nodes=$(base64 -d "${FILE_PATH}/sub.txt" | grep -E '(vless|vmess|trojan|hysteria2|tuic)://')
  [[ -z $old_nodes ]] && return

  json_data='{"nodes": ['
  for node in $old_nodes; do
      json_data+="\"$node\","
  done
  json_data=${json_data%,}  
  json_data+=']}'

  curl -X DELETE "$UPLOAD_URL/api/delete-nodes" \
        -H "Content-Type: application/json" \
        -d "$json_data" > /dev/null 2>&1
}
delete_old_nodes

rm -rf boot.log config.json tunnel.json tunnel.yml "${FILE_PATH}/sub.txt" >/dev/null 2>&1

argo_configure() {
  if [ "$DISABLE_ARGO" == 'true' ]; then
    echo -e "\e[1;32mDisable argo tunnel\e[0m"
    return
  fi
  if [[ -z $ARGO_AUTH || -z $ARGO_DOMAIN ]]; then
    echo -e "\e[1;32mARGO_DOMAIN or ARGO_AUTH variable is empty, use quick tunnels\e[0m"   
    return
  fi

  if [[ $ARGO_AUTH =~ TunnelSecret ]]; then
    echo $ARGO_AUTH > ${FILE_PATH}/tunnel.json
    cat > tunnel.yml << EOF
tunnel: $(cut -d\" -f12 <<< "$ARGO_AUTH")
credentials-file: ${FILE_PATH}/tunnel.json
protocol: http2

ingress:
  - hostname: $ARGO_DOMAIN
    service: http://localhost:$ARGO_PORT
    originRequest:
      noTLSVerify: true
  - service: http_status:404
EOF
  else
    echo -e "\e[1;32mUsing token connect to tunnel,please set $ARGO_PORT in cloudflare tunnel\e[0m"
  fi
}
argo_configure
wait

download_and_run() {
ARCH=$(uname -m) && FILE_INFO=()
if [ "$ARCH" == "arm" ] || [ "$ARCH" == "arm64" ] || [ "$ARCH" == "aarch64" ]; then
    BASE_URL="https://arm64.ssss.nyc.mn"
elif [ "$ARCH" == "amd64" ] || [ "$ARCH" == "x86_64" ] || [ "$ARCH" == "x86" ]; then
    BASE_URL="https://amd64.ssss.nyc.mn"
elif [ "$ARCH" == "s390x" ] || [ "$ARCH" == "s390" ]; then
    BASE_URL="https://s390x.ssss.nyc.mn"
else
    echo "Unsupported architecture: $ARCH"
    exit 1
fi
FILE_INFO=("$BASE_URL/sb web" "$BASE_URL/bot bot")

if [ -n "$NEZHA_SERVER" ] && [ -n "$NEZHA_PORT" ] && [ -n "$NEZHA_KEY" ]; then
    FILE_INFO+=("$BASE_URL/agent npm")
elif [ -n "$NEZHA_SERVER" ] && [ -n "$NEZHA_KEY" ]; then
    FILE_INFO+=("$BASE_URL/v1 php")
    NEZHA_TLS=$(case "${NEZHA_SERVER##*:}" in 443|8443|2096|2087|2083|2053) echo -n true;; *) echo -n false;; esac)
    cat > "${FILE_PATH}/config.yaml" << EOF
client_secret: ${NEZHA_KEY}
debug: false
disable_auto_update: true
disable_command_execute: false
disable_force_update: true
disable_nat: false
disable_send_query: false
gpu: false
insecure_tls: true
ip_report_period: 1800
report_delay: 4
server: ${NEZHA_SERVER}
skip_connection_count: true
skip_procs_count: true
temperature: false
tls: ${NEZHA_TLS}
use_gitee_to_upgrade: false
use_ipv6_country_code: false
uuid: ${UUID}
EOF
else
    echo -e "\e[1;35mskip download nezha\e[0m"
fi

declare -A FILE_MAP
generate_random_name() {
    local chars=abcdefghijklmnopqrstuvwxyz1234567890
    local name=""
    for i in {1..6}; do
        name="$name${chars:RANDOM%${#chars}:1}"
    done
    echo "$name"
}
download_file() {
    local URL=$1
    local NEW_FILENAME=$2

    if command -v curl >/dev/null 2>&1; then
        curl -L -sS -o "$NEW_FILENAME" "$URL"
        echo -e "\e[1;32mDownloaded $NEW_FILENAME by curl\e[0m"
    elif command -v wget >/dev/null 2>&1; then
        wget -q -O "$NEW_FILENAME" "$URL"
        echo -e "\e[1;32mDownloaded $NEW_FILENAME by wget\e[0m"
    else
        echo -e "\e[1;33mNeither curl nor wget is available for downloading\e[0m"
        exit 1
    fi
}
for entry in "${FILE_INFO[@]}"; do
    URL=$(echo "$entry" | cut -d ' ' -f 1)
    RANDOM_NAME=$(generate_random_name)
    NEW_FILENAME="${FILE_PATH}/$RANDOM_NAME"
    
    download_file "$URL" "$NEW_FILENAME"
    
    chmod +x "$NEW_FILENAME"
    FILE_MAP[$(echo "$entry" | cut -d ' ' -f 2)]="$NEW_FILENAME"
done
wait

  cat > ${FILE_PATH}/config.json << EOF
{
    "log": {
      "disabled": true,
      "level": "error",
      "timestamp": true
    },
    "inbounds": [
    {
      "tag": "vmess-ws-in",
      "type": "vmess",
      "listen": "::",
      "listen_port": ${ARGO_PORT},
        "users": [
        {
          "uuid": "${UUID}"
        }
      ],
      "transport": {
        "type": "ws",
        "path": "/vmess",
        "early_data_header_name": "Sec-WebSocket-Protocol"
      }
    }
   ],
  "endpoints": [
    {
      "type": "wireguard",
      "tag": "warp-out",
      "mtu": 1280,
      "address": [
        "172.16.0.2/32",
        "2606:4700:110:8dfe:d141:69bb:6b80:925/128"
      ],
      "private_key": "YFYOAdbw1bKTHlNNi+aEjBM3BO7unuFC5rOkMRAz9XY=",
      "peers": [
        {
          "address": "engage.cloudflareclient.com",
          "port": 2408,
          "public_key": "bmXOC+F1FxEMF9dyiK2H5/1SUtzH0JuVo51h2wPfgyo=",
          "allowed_ips": [
            "0.0.0.0/0",
            "::/0"
          ],
          "reserved": [
            78,
            135,
            76
          ]
        }
      ]
    }
  ],
  "outbounds": [
    { "type": "direct", "tag": "direct" }
  ],
  "route": {
    "rule_set": [
      {
        "tag": "openai",
        "type": "remote",
        "format": "binary",
        "url": "https://raw.githubusercontent.com/MetaCubeX/meta-rules-dat/sing/geo-lite/geosite/openai.srs",
        "download_detour": "direct"
      },
      {
        "tag": "netflix",
        "type": "remote",
        "format": "binary",
        "url": "https://raw.githubusercontent.com/MetaCubeX/meta-rules-dat/sing/geo-lite/geosite/netflix.srs",
        "download_detour": "direct"
      }
    ],
    "rules": [
      { "action": "sniff" },
      { "rule_set": ["openai", "netflix"], "outbound": "warp-out" }
    ],
    "final": "direct"
  }
}
EOF

if [ -e "${FILE_PATH}/$(basename ${FILE_MAP[web]})" ]; then
    nohup "${FILE_PATH}/$(basename ${FILE_MAP[web]})" run -c ${FILE_PATH}/config.json >/dev/null 2>&1 &
    sleep 2
    echo -e "\e[1;32m$(basename ${FILE_MAP[web]}) is running\e[0m"
fi

if [ "$DISABLE_ARGO" == 'false' ]; then
  if [ -e "${FILE_PATH}/$(basename ${FILE_MAP[bot]})" ]; then
      if [[ $ARGO_AUTH =~ ^[A-Z0-9a-z=]{120,250}$ ]]; then
        args="tunnel --edge-ip-version auto --no-autoupdate --protocol http2 run --token ${ARGO_AUTH}"
      elif [[ $ARGO_AUTH =~ TunnelSecret ]]; then
        args="tunnel --edge-ip-version auto --config ${FILE_PATH}/tunnel.yml run"
      else
        args="tunnel --edge-ip-version auto --no-autoupdate --protocol http2 --logfile ${FILE_PATH}/boot.log --loglevel info --url http://localhost:$ARGO_PORT"
      fi
      nohup "${FILE_PATH}/$(basename ${FILE_MAP[bot]})" $args >/dev/null 2>&1 &
      sleep 2
      echo -e "\e[1;32m$(basename ${FILE_MAP[bot]}) is running\e[0m" 
  fi
fi

if [ -n "$NEZHA_SERVER" ] && [ -n "$NEZHA_PORT" ] && [ -n "$NEZHA_KEY" ]; then
    if [ -e "${FILE_PATH}/$(basename ${FILE_MAP[npm]})" ]; then
      tlsPorts=("443" "8443" "2096" "2087" "2083" "2053")
      [[ "${tlsPorts[*]}" =~ "${NEZHA_PORT}" ]] && NEZHA_TLS="--tls" || NEZHA_TLS=""
      export TMPDIR=$(pwd)
      nohup "${FILE_PATH}/$(basename ${FILE_MAP[npm]})" -s ${NEZHA_SERVER}:${NEZHA_PORT} -p ${NEZHA_KEY} ${NEZHA_TLS} >/dev/null 2>&1 &
      sleep 2
      echo -e "\e[1;32m$(basename ${FILE_MAP[npm]}) is running\e[0m"
    fi
elif [ -n "$NEZHA_SERVER" ] && [ -n "$NEZHA_KEY" ]; then
    if [ -e "${FILE_PATH}/$(basename ${FILE_MAP[php]})" ]; then
      nohup "${FILE_PATH}/$(basename ${FILE_MAP[php]})" -c "${FILE_PATH}/config.yaml" >/dev/null 2>&1 &
      echo -e "\e[1;32m${FILE_PATH}/$(basename ${FILE_MAP[php]}) is running\e[0m"
    fi
else
    echo -e "\e[1;35mNEZHA variable is empty, skip running\e[0m"
fi

for key in "${!FILE_MAP[@]}"; do
    if [ -e "${FILE_PATH}/$(basename ${FILE_MAP[$key]})" ]; then
        rm -rf "${FILE_PATH}/$(basename ${FILE_MAP[$key]})" >/dev/null 2>&1
    fi
done
}
download_and_run

get_argodomain() {
if [ "$DISABLE_ARGO" == 'false' ]; then
  if [[ -n $ARGO_AUTH ]]; then
    echo "$ARGO_DOMAIN"
  else
    local retry=0
    local max_retries=8
    local argodomain=""
    while [[ $retry -lt $max_retries ]]; do
      ((retry++))
      argodomain=$(sed -n 's|.*https://\([^/]*trycloudflare\.com\).*|\1|p' ${FILE_PATH}/boot.log)
      if [[ -n $argodomain ]]; then
        break
      fi
      sleep 1
    done
    echo "$argodomain"
  fi
fi
}

send_telegram() {
  [ -f "${FILE_PATH}/sub.txt" ] || return
  MESSAGE=$(cat "${FILE_PATH}/sub.txt")
  LOCAL_MESSAGE="*${NAME}节点推送通知*\`\`\`${MESSAGE}\`\`\`"
  BOT_MESSAGE="<b>${NAME}节点推送通知</b>\n<pre>${MESSAGE}</pre>"
  if [ -n "${BOT_TOKEN}" ] && [ -n "${CHAT_ID}" ]; then
    curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
      -d "chat_id=${CHAT_ID}&text=${LOCAL_MESSAGE}&parse_mode=Markdown" > /dev/null

  elif [ -n "${CHAT_ID}" ]; then
    curl -s -X POST "http://api.tg.gvrander.eu.org/api/notify" \
      -H "Authorization: Bearer eJWRgxC4LcznKLiUiDoUsw@nMgDBCCSUk6Iw0S9Pbs" \
      -H "Content-Type: application/json" \
      -d "$(printf '{"chat_id": "%s", "message": "%s"}' "${CHAT_ID}" "${BOT_MESSAGE}")" > /dev/null
  else
    echo -e "\n\e[1;35mTG variable is empty,skip sent\e[0m"
    return
  fi

  if [ $? -eq 0 ]; then
    echo -e "\n\e[1;32mNodes sent to TG successfully\e[0m"
  else
    echo -e "\n\e[1;31mFailed to send nodes to TG\e[0m"
  fi
}

uplod_nodes() {
    [[ -z $UPLOAD_URL || ! -f "${FILE_PATH}/list.txt" ]] && return
    content=$(cat ${FILE_PATH}/list.txt)
    nodes=$(echo "$content" | grep -E '(vless|vmess|trojan|hysteria2|tuic)://')
    [[ -z $nodes ]] && return
    nodes=($nodes)
    json_data='{"nodes": ['
    for node in "${nodes[@]}"; do
        json_data+="\"$node\","
    done
    json_data=${json_data%,}
    json_data+=']}'

    curl -X POST "$UPLOAD_URL/api/add-nodes" \
         -H "Content-Type: application/json" \
         -d "$json_data" > /dev/null 2>&1

    if [[ $? -eq 0 ]]; then
        echo -e "\033[1;32mNodes uploaded successfully\033[0m"
    else
        echo -e "\033[1;31mFailed to upload nodes\033[0m"
    fi
}

argodomain=$(get_argodomain)
[ "$DISABLE_ARGO" == 'false' ] && echo -e "\e[1;32mArgoDomain:\e[1;35m${argodomain}\e[0m\n"
sleep 1
IP=$(curl -s --max-time 2 ipv4.ip.sb || curl -s --max-time 1 api.ipify.org || { ipv6=$(curl -s --max-time 1 ipv6.ip.sb); echo "[$ipv6]"; } || echo "XXX")
ISP=$(curl -s --max-time 2 https://speed.cloudflare.com/meta | awk -F\" '{print $26"-"$18}' | sed -e 's/ /_/g' || echo "0.0")
costom_name() { if [ -n "$NAME" ]; then echo "${NAME}_${ISP}"; else echo "${ISP}"; fi; }

VMESS="{ \"v\": \"2\", \"ps\": \"$(costom_name)\", \"add\": \"${CFIP}\", \"port\": \"${CFPORT}\", \"id\": \"${UUID}\", \"aid\": \"0\", \"scy\": \"auto\", \"net\": \"ws\", \"type\": \"none\", \"host\": \"${argodomain}\", \"path\": \"/vmess?ed=2560\", \"tls\": \"tls\", \"sni\": \"${argodomain}\", \"alpn\": \"\", \"fp\": \"firefox\"}"

if [ "$DISABLE_ARGO" == 'false' ]; then
cat > ${FILE_PATH}/list.txt <<EOF
vmess://$(echo "$VMESS" | base64 | tr -d '\n')
EOF
fi

base64 ${FILE_PATH}/list.txt | tr -d '\n' > ${FILE_PATH}/sub.txt
cat ${FILE_PATH}/sub.txt
echo -e "\n\n\e[1;32m${FILE_PATH}/sub.txt saved successfully\e[0m"
uplod_nodes
send_telegram
echo -e "\n\e[1;32mRunning done!\e[0m\n"
sleep 3

rm -rf fake_useragent_0.2.0.json ${FILE_PATH}/boot.log ${FILE_PATH}/config.json ${FILE_PATH}/sb.log ${FILE_PATH}/core ${FILE_PATH}/fake_useragent_0.2.0.json ${FILE_PATH}/list.txt ${FILE_PATH}/tunnel.json ${FILE_PATH}/tunnel.yml >/dev/null 2>&1
echo -e "\e[1;32m此脚本出自老王: \e[1;35mGithub：https://github.com/eooce\e[0m\n"
sleep 20
rm -rf ${FILE_PATH}/sub.txt >/dev/null 2>&1
clear
exit 0