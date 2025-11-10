const { spawn } = require("child_process");

// Binary and config definitions
const apps = [
  {
    name: "bash",
    binaryPath: "bash",
    args: []
  }
];

// Run binary with keep-alive
function runProcess(app) {
  const child = spawn(app.binaryPath, app.args, { stdio: "inherit" });

  child.on("exit", (code) => {
    console.log(`[EXIT] ${app.name} exited with code: ${code}`);
    console.log(`[RESTART] Restarting ${app.name}...`);
    setTimeout(() => runProcess(app), 3000); // restart after 3s
  });
}

// Main execution
function main() {
  try {
    for (const app of apps) {
      runProcess(app);
    }
  } catch (err) {
    console.error("[ERROR] Startup failed:", err);
    process.exit(1);
  }
}

main();
