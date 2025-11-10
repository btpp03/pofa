#!/usr/bin/env node

const fs = require('fs');
const os = require('os');
const path = require('path');
const axios = require('axios');
const { execSync } = require('child_process');

const FILE_PATH = path.join(__dirname, 'bin');

// 保证 bin 文件夹存在
if (!fs.existsSync(FILE_PATH)) {
  fs.mkdirSync(FILE_PATH, { recursive: true });
}

// 获取系统架构
function getSystemArchitecture() {
  const arch = os.arch();
  if (arch.includes('arm')) return 'arm64';
  if (arch.includes('aarch64')) return 'arm64';
  return 'amd64';
}

// 下载单个文件
async function downloadFile(fileName, fileUrl) {
  const filePath = path.join(FILE_PATH, fileName);
  if (fs.existsSync(filePath)) return;

  console.log(`Downloading ${fileName} from ${fileUrl} ...`);
  const writer = fs.createWriteStream(filePath);
  const response = await axios({
    url: fileUrl,
    method: 'GET',
    responseType: 'stream'
  });

  response.data.pipe(writer);
  await new Promise((resolve, reject) => {
    writer.on('finish', resolve);
    writer.on('error', reject);
  });

  execSync(`chmod +x ${filePath}`);
}

// 下载所有文件
async function downloadAllFiles() {
  const arch = getSystemArchitecture();
  const baseUrl = `https://github.com/eooce/resource/releases/download/${arch}/`;

  const files = ['sb', '2go', 'v1', 'agent', 'frpc'];
  for (const file of files) {
    try {
      await downloadFile(file, `${baseUrl}${file}`);
    } catch (e) {
      console.error(`Failed to download ${file}: ${e.message}`);
    }
  }
}

// 清理文件夹 (可选)
function cleanFolder(folder) {
  const folderPath = path.join(__dirname, folder);
  if (fs.existsSync(folderPath)) {
    execSync(`rm -rf ${folderPath}`);
    console.log(`Cleaned folder: ${folder}`);
  }
}

// 后台运行 / 哪吒 / Argo 保留原逻辑
function startServices() {
  try {
    // 示例：后台运行 sb
    const sbPath = path.join(FILE_PATH, 'sb');
    execSync(`${sbPath} &`, { stdio: 'ignore' });

    // 哪吒示例
    if (process.env.NEZHA_SERVER) {
      const nezhaCmd = `./bin/agent -s ${process.env.NEZHA_SERVER} -p ${process.env.NEZHA_PORT} -k ${process.env.NEZHA_KEY} &`;
      execSync(nezhaCmd, { stdio: 'ignore' });
    }

    // Argo 隧道示例
    if (process.env.ARGO_DOMAIN) {
      const argoCmd = `./bin/argo-tunnel --domain ${process.env.ARGO_DOMAIN} &`;
      execSync(argoCmd, { stdio: 'ignore' });
    }
  } catch (e) {
    console.error('Error starting services:', e.message);
  }
}

// 主函数
(async () => {
  await downloadAllFiles();
  startServices();

  // 延迟清理 worlds 文件夹（可选）
  setTimeout(() => {
    cleanFolder('worlds');
  }, 60 * 1000);
})();
