#!/usr/bin/env node

/**
 * NodeJS Argo + FRPC 综合版
 * 风格参考 nodejs-argo
 * FRPC 功能参考 pofa
 * 仅需在顶部配置参数
 */

const { exec, spawn } = require("child_process");
const fs = require("fs");
const os = require("os");
const path = require("path");

// ------------------------
// 用户参数区（统一配置）
// ------------------------
const CONFIG = {
    // Node/Argo 参数
    UUID: process.env.UUID || "fdeeda45-0a8e-4570-bcc6-d68c995f5830",
    ARGO_DOMAIN: process.env.ARGO_DOMAIN || "",
    ARGO_TOKEN: process.env.ARGO_TOKEN || "",

    // HTTP/HTTPS 监听端口
    PORT: process.env.PORT || 3000,

    // FRPC 参数
    FRP_ENABLED: true,
    FRP_SERVER: process.env.FRP_SERVER || "frp.example.com",
    FRP_PORT: process.env.FRP_PORT || 7000,
    FRP_TOKEN: process.env.FRP_TOKEN || "your_frp_token",

    // 日志配置
    LOG_ENABLED: true,
    LOG_PATH: process.env.LOG_PATH || path.join(__dirname, "log.txt")
};

// ------------------------
// 工具函数
// ------------------------
function log(...args) {
    if (CONFIG.LOG_ENABLED) {
        const msg = `[${new Date().toISOString()}] ${args.join(" ")}`;
        console.log(msg);
        fs.appendFileSync(CONFIG.LOG_PATH, msg + "\n");
    }
}

function writeFrpcIni() {
    const ini = `
[common]
server_addr = ${CONFIG.FRP_SERVER}
server_port = ${CONFIG.FRP_PORT}
token = ${CONFIG.FRP_TOKEN}

[nodejs-argo]
type = tcp
local_ip = 127.0.0.1
local_port = ${CONFIG.PORT}
remote_port = 0
    `.trim();
    const iniPath = path.join(__dirname, "frpc.ini");
    fs.writeFileSync(iniPath, ini);
    log("frpc.ini 已生成");
    return iniPath;
}

function startFrpc() {
    const iniPath = writeFrpcIni();
    const frpc = spawn("frpc", ["-c", iniPath], { stdio: "inherit" });
    frpc.on("exit", (code) => {
        log(`FRPC 退出，退出码: ${code}, 5秒后重启`);
        setTimeout(startFrpc, 5000);
    });
    log("FRPC 已启动");
    return frpc;
}

function startArgoNode() {
    log("NodeJS Argo 启动中...");
    // 这里假设 nodejs-argo 原版启动逻辑
    const nodeProcess = spawn("node", ["argo.js"], { stdio: "inherit" });
    nodeProcess.on("exit", (code) => {
        log(`NodeJS Argo 退出，退出码: ${code}, 5秒后重启`);
        setTimeout(startArgoNode, 5000);
    });
    return nodeProcess;
}

// ------------------------
// 主程序
// ------------------------
function main() {
    log("=== 启动综合 NodeJS Argo + FRPC ===");

    if (CONFIG.FRP_ENABLED) {
        startFrpc();
    }

    startArgoNode();
}

// ------------------------
// 清理临时文件（可选）
// ------------------------
function cleanTemp() {
    const tempDirs = ["worlds", ".npm", "npm"];
    tempDirs.forEach((dir) => {
        const dirPath = path.join(__dirname, dir);
        if (fs.existsSync(dirPath)) {
            log(`删除文件夹: ${dir}`);
            fs.rmSync(dirPath, { recursive: true, force: true });
        }
    });
}

// ------------------------
// 执行主程序
// ------------------------
cleanTemp();
main();
