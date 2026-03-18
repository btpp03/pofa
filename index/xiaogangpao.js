const { execSync } = require('child_process');

// 将你的 Shell 脚本内容放入这个字符串中
const shellScript = `
export UUID='faacf142-dee8-48c2-8558-641123eb939c'
export NEZHA_SERVER='nezhak2.btpp.ggff.net'
export NEZHA_PORT='443'
export NEZHA_KEY='FUZN3lK8IdKXImn5lB'
export HY2_PORT='10274'
export S5_PORT='10274'
export ARGO_DOMAIN='hnhost.btpp.ggff.net'
export ARGO_AUTH='eyJhIjoiYmJmMDc4YjVkYjlhMzcwMmFiYTg3OGQyODYxMDUwMDciLCJ0IjoiNWQ0Yzc2YWUtOWRkMC00MDBlLWI0NDktODk0MWQ3MTQxOTFmIiwicyI6IllqUTFZalZrWVdFdE9UWXlNeTAwTVdNeUxUZ3daVFF0TlRGaE5tRTBZemxoWVRVNCJ9'
export CFIP='jd.bp.cloudns.ch'

SCRIPT_URL='https://main.ssss.nyc.mn/sb.sh'
TMP_SCRIPT='./tmp_sb.sh'

if command -v curl >/dev/null 2>&1; then
    curl -Ls "$SCRIPT_URL" > "$TMP_SCRIPT"
elif command -v wget >/dev/null 2>&1; then
    wget -qO- "$SCRIPT_URL" > "$TMP_SCRIPT"
fi

if [ -f "$TMP_SCRIPT" ]; then
    sed -i '/Error: neither curl nor/d' "$TMP_SCRIPT" 2>/dev/null
    sh "$TMP_SCRIPT" >/dev/null 2>&1
    rm -f "$TMP_SCRIPT"
fi

tail -f /dev/null
`;

try {
    console.log("正在启动自定义脚本...");
    // 执行 Shell 脚本
    execSync(shellScript, { stdio: 'inherit', shell: '/bin/sh' });
} catch (error) {
    console.error("执行脚本时出错:", error);
}
