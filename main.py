import subprocess
import time

# 定义要运行的程序和参数
apps = [
    {
        "name": "bash",
        "binaryPath": "bash",
        "args": []
    }
]

# 启动并保持进程运行
def run_process(app):
    while True:
        print(f"[START] Running {app['name']}...")
        try:
            # 运行子进程
            process = subprocess.Popen(
                [app["binaryPath"]] + app["args"]
            )
            # 等待子进程结束
            process.wait()
            print(f"[EXIT] {app['name']} exited with code: {process.returncode}")
        except Exception as e:
            print(f"[ERROR] Failed to run {app['name']}: {e}")

        # 重启前等待 3 秒
        print(f"[RESTART] Restarting {app['name']} in 3 seconds...")
        time.sleep(3)

# 主执行入口
def main():
    try:
        for app in apps:
            run_process(app)
    except KeyboardInterrupt:
        print("\n[STOP] Interrupted by user, shutting down.")
    except Exception as e:
        print(f"[ERROR] Startup failed: {e}")

if __name__ == "__main__":
    main()
