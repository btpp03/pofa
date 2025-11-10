const express = require("express");
const app = express();
const axios = require("axios");
const os = require("os");
const fs = require("fs");
const path = require("path");
const { promisify } = require("util");
const exec = promisify(require("child_process").exec);
const { execSync } = require("child_process");

// ==========================
// 参数区（只需填写这里即可）
// ==========================
const UPLOAD_URL = process.env.UPLOAD_URL || '';          // 节点上传地址
const PROJECT_URL = process.env.PROJECT_URL || '';        // 项目 URL
const AUTO_ACCESS = process.env.AUTO_ACCESS || false;    // 自动访问项目
const FILE_PATH = process.env.FILE_PATH || './tmp';      // 文件存放目录
const SUB_PATH = process.env.SUB_PATH || 'sub';          // 订阅路径
const PORT = process.env.SERVER_PORT || process.env.PORT || 3000;

const UUID = process.env.UUID || '9afd1229-b893-40c1-84dd-51e7ce204913';
const NEZHA_SERVER = process.env.NEZHA_SERVER || '';
const NEZHA_PORT = process.env.NEZHA_PORT || '';
const NEZHA_KEY = process.env.NEZHA_KEY || '';

const ARGO_DOMAIN = process.env.ARGO_DOMAIN || '';
const ARGO_AUTH = process.env.ARGO_AUTH || '';
const ARGO_PORT = process.env.ARGO_PORT || 8001;

const CFIP = process.env.CFIP || 'cdns.doon.eu.org';
const CFPORT = process.env.CFPORT || 443;
const NAME = process.env.NAME || '';

// ==========================
// FRPC 参数
// ==========================
const FRPC_SERVER = process.env.FRPC_SERVER || ''; // FRP 服务端地址
const FRPC_PORT = process.env.FRPC_PORT || '';     // FRP 服务端端口
const FRPC_TOKEN = process.env.FRPC_TOKEN || '';   // FRP token

// ==========================
// 创建运行目录
// ==========================
if (!fs.existsSync(FILE_PATH)) fs.mkdirSync(FILE_PATH);

// ==========================
// 生成随机文件名
// ==========================
function generateRandomName() {
  const chars = 'abcdefghijklmnopqrstuvwxyz';
  let name = '';
  for (let i = 0; i < 6; i++) name += chars[Math.floor(Math.random() * chars.length)];
  return name;
}

// ==========================
// 全局路径
// ==========================
const npmName = generateRandomName();
const webName = generateRandomName();
const botName = generateRandomName();
const phpName = generateRandomName();
const frpcName = generateRandomName();

let npmPath = path.join(FILE_PATH, npmName);
let phpPath = path.join(FILE_PATH, phpName);
let webPath = path.join(FILE_PATH, webName);
let botPath = path.join(FILE_PATH, botName);
let frpcPath = path.join(FILE_PATH, frpcName);

let subPath = path.join(FILE_PATH, 'sub.txt');
let listPath = path.join(FILE_PATH, 'list.txt');
let bootLogPath = path.join(FILE_PATH, 'boot.log');
let configPath = path.join(FILE_PATH, 'config.json');
let frpcConfigPath = path.join(FILE_PATH, 'frpc.ini');

// ==========================
// 清理历史文件
// ==========================
function cleanupOldFiles() {
  try {
    const files = fs.readdirSync(FILE_PATH);
    files.forEach(file => {
      const f = path.join(FILE_PATH, file);
      try { if (fs.statSync(f).isFile()) fs.unlinkSync(f); } catch { }
    });
  } catch { }
}

// ==========================
// 获取系统架构
// ==========================
function getSystemArchitecture() {
  const arch = os.arch();
  if (arch === 'arm' || arch === 'arm64' || arch === 'aarch64') return 'arm';
  return 'amd';
}

// ==========================
// 下载文件
// ==========================
function downloadFile(fileName, fileUrl) {
  return new Promise((resolve, reject) => {
    const writer = fs.createWriteStream(fileName);
    axios({ method: 'get', url: fileUrl, responseType: 'stream' })
      .then(response => {
        response.data.pipe(writer);
        writer.on('finish', () => { writer.close(); resolve(fileName); });
        writer.on('error', err => { fs.unlink(fileName, () => { }); reject(err); });
      })
      .catch(err => reject(err));
  });
}

// ==========================
// 根据架构获取需要下载的文件
// ==========================
function getFilesForArchitecture(arch) {
  const files = [];
  if (arch === 'arm') {
    files.push({ fileName: webPath, fileUrl: "https://arm64.ssss.nyc.mn/web" });
    files.push({ fileName: botPath, fileUrl: "https://arm64.ssss.nyc.mn/bot" });
  } else {
    files.push({ fileName: webPath, fileUrl: "https://amd64.ssss.nyc.mn/web" });
    files.push({ fileName: botPath, fileUrl: "https://amd64.ssss.nyc.mn/bot" });
  }

  if (NEZHA_SERVER && NEZHA_KEY) {
    if (NEZHA_PORT) {
      files.push({ fileName: npmPath, fileUrl: arch === 'arm' ? "https://arm64.ssss.nyc.mn/agent" : "https://amd64.ssss.nyc.mn/agent" });
    } else {
      files.push({ fileName: phpPath, fileUrl: arch === 'arm' ? "https://arm64.ssss.nyc.mn/v1" : "https://amd64.ssss.nyc.mn/v1" });
    }
  }

  // FRPC 下载
  if (FRPC_SERVER && FRPC_PORT && FRPC_TOKEN) {
    files.push({ fileName: frpcPath, fileUrl: arch === 'arm' ? "https://arm64.ssss.nyc.mn/frpc" : "https://amd64.ssss.nyc.mn/frpc" });
  }

  return files;
}

// ==========================
// 运行 FRPC
// ==========================
async function runFRPC() {
  if (!(FRPC_SERVER && FRPC_PORT && FRPC_TOKEN)) return;

  const frpcConfig = `
[common]
server_addr = ${FRPC_SERVER}
server_port = ${FRPC_PORT}
token = ${FRPC_TOKEN}

[web]
type = tcp
local_ip = 127.0.0.1
local_port = ${ARGO_PORT}
remote_port = ${FRPC_PORT}
`;
  fs.writeFileSync(frpcConfigPath, frpcConfig);

  await exec(`nohup ${frpcPath} -c ${frpcConfigPath} >/dev/null 2>&1 &`);
  console.log('FRPC started');
}

// ==========================
// 运行 Argo、Nezha、XR-AY
// ==========================
async function runServices() {
  const arch = getSystemArchitecture();
  const files = getFilesForArchitecture(arch);

  // 下载所有文件
  for (const f of files) {
    try { await downloadFile(f.fileName, f.fileUrl); console.log(`${f.fileName} downloaded`); } 
    catch (e) { console.error(`${f.fileName} download failed`, e); }
    try { fs.chmodSync(f.fileName, 0o775); } catch { }
  }

  // 运行 Nezha
  if (NEZHA_SERVER && NEZHA_KEY) {
    if (NEZHA_PORT) {
      const tlsPorts = ['443','8443','2096','2087','2083','2053'];
      const tls = tlsPorts.includes(NEZHA_PORT) ? '--tls' : '';
      exec(`${npmPath} -s ${NEZHA_SERVER}:${NEZHA_PORT} -p ${NEZHA_KEY} ${tls} --disable-auto-update >/dev/null 2>&1 &`);
      console.log('Nezha started');
    } else {
      const command = `${phpPath} -c "${FILE_PATH}/config.yaml" >/dev/null 2>&1 &`;
      exec(command);
      console.log('Nezha PHP started');
    }
  }

  // 运行 XR-AY
  const cmdWeb = `nohup ${webPath} -c ${configPath} >/dev/null 2>&1 &`;
  exec(cmdWeb);
  console.log('XR-AY started');

  // 运行 Argo
  const cmdBot = `nohup ${botPath} tunnel --edge-ip-version auto --no-autoupdate --protocol http2 --url http://localhost:${ARGO_PORT} >/dev/null 2>&1 &`;
  exec(cmdBot);
  console.log('Argo started');

  // 运行 FRPC
  await runFRPC();
}

// ==========================
// HTTP 订阅服务
// ==========================
app.get(`/${SUB_PATH}`, (req,res)=>{
  if (!fs.existsSync(subPath)) return res.send('');
  const content = fs.readFileSync(subPath,'utf-8');
  res.set('Content-Type','text/plain; charset=utf-8');
  res.send(content);
});

// ==========================
// 主函数
// ==========================
async function startServer() {
  cleanupOldFiles();
  await runServices();
}

startServer().catch(console.error);

app.listen(PORT, () => console.log(`HTTP server running on port ${PORT}`));
