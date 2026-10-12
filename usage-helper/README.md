# 远坂凛 · Codex 额度助手 / Rin Codex Usage Helper

## 中文

保留 Codex 内置宠物，在鼠标停留约 0.35 秒后显示额度卡片。卡片在拖动过程中持续跟随宠物，松开后校准到角色的实际位置；移开鼠标后自动隐藏。卡片显示当前账户的剩余百分比、重置倒计时和本地时间。

### 运行

需要 Windows 10/11、Windows PowerShell 5.1 和已登录 ChatGPT 的 Codex。无需安装 Python、.NET SDK 或第三方库。

1. 按仓库根目录 README 安装并选择远坂凛，在 Codex 中显示宠物。
2. 双击根目录 `start-usage.cmd`。
3. 将鼠标停在宠物身上查看额度。

右键 Windows 托盘中的信息图标，可以立即刷新或退出。也可双击 `stop-usage.cmd` 退出。启动脚本只启动助手，不设置开机启动，不修改 Codex 安装文件或宠物资源。

卡片刷新间隔默认 60 秒，同时监听额度更新通知。额度来自账户共享窗口，不能据此准确换算剩余对话次数。额度缺失显示“暂不可用”；刷新失败保留上次数据并显示状态，超过有效期标明数据过期。每周额度独立保留在每周栏，兼容仅有一个额度窗口的账户。

### 检查与预览

在仓库根目录的 PowerShell 中运行：

```powershell
# 读取一次真实额度，只输出窗口数据
powershell -NoProfile -ExecutionPolicy Bypass -File .\usage-helper\UsageHelper.ps1 -Once

# 检查宠物是否显示，以及新旧窗口定位方式
powershell -NoProfile -ExecutionPolicy Bypass -File .\usage-helper\UsageHelper.ps1 -Diagnose

# 独立的示例卡片预览（不会读取账户额度）
powershell -NoProfile -ExecutionPolicy Bypass -File .\usage-helper\start.ps1 -Demo
powershell -NoProfile -ExecutionPolicy Bypass -File .\usage-helper\stop.ps1 -Demo

# 逻辑验证
powershell -NoProfile -ExecutionPolicy Bypass -File .\usage-helper\tests.ps1
```

找不到 Codex 时，可传入 `-CodexPath 'C:\path\to\codex.exe'`。它必须指向真正的 CLI 可执行文件，不是 `.cmd` 启动器。脚本会依次查找 PATH、正在运行的 Codex CLI、本地更新目录和 Windows 应用包。

### 实现与数据

- 用本机 `codex app-server --listen stdio://`，调用官方 `account/rateLimits/read` 并监听 `account/rateLimits/updated`。
- 优先使用 `rateLimitsByLimitId.codex`，回退到 `rateLimits`；剩余值为 `100 - usedPercent`。
- 用 Win32 读取实际可见的 Codex 宠物窗口。旧版从 `.codex-global-state.json` 解析角色边界；新版从该窗口的系统无障碍接口读取宠物图像边界。仅读取控件位置，不执行点击或输入。
- 透明 WPF 卡片不激活窗口，鼠标可穿透。悬停通过鼠标坐标判断，原有宠物操作继续由 Codex 控制。
- 不直接读取 `auth.json`、浏览器 Cookie、聊天正文或日志；不保存登录令牌，不发起模型推理。额度请求由 Codex 自己的登录会话处理。不会上传数据到第三方。
- 默认不写诊断文件。开发时可用 `-DiagnosticPath <path>` 写入连接状态、时间和角色坐标，便于验证；其中没有账户 ID、令牌或聊天内容。

如果 Codex 更新后改变窗口结构或无障碍图像标记，定位可能需要适配。缺少可确认的角色边界时，助手保持隐藏。多显示器和 DPI 换算具备逻辑测试；不同硬件和缩放组合仍需实际验证。

参考实现：[Codex Usage Overlay](https://github.com/jiaotashidi-bi/codex-usage-overlay)、[Codexy Pet Usage Rings](https://github.com/himomohi/Codexy-pet-usages-ring)。助手源码为本仓库自行实现，没有复制上述项目的源码或美术资产。

## English

The helper keeps the built-in Codex pet and shows a small usage card after hovering for approximately 0.35 seconds. The card follows throughout a drag, aligns with the actual pet position after release, and hides when the pointer leaves. It shows remaining allowance, reset countdowns, and local reset times.

Requires Windows 10/11, Windows PowerShell 5.1, and Codex signed in with ChatGPT. No Python, .NET SDK, or external packages are needed.

Show the pet in Codex, then double-click `start-usage.cmd` in the repository root. Right-click the information icon in the Windows notification area to refresh or quit. `stop-usage.cmd` also stops the helper. Startup registration is not enabled automatically.

Usage is fetched through the official local app-server `account/rateLimits/read` RPC and its update notifications, with a 60-second polling fallback. The helper does not directly read authentication tokens, cookies, chat content, or Codex logs and does not make model requests. Missing values and stale data are identified explicitly.

The helper reads saved mascot geometry on older Codex versions and the accessible pet image bounds on newer versions, then positions a transparent, non-activating, click-through WPF card. It never patches Codex or changes the sprite sheet. Window structure changes after Codex updates may require compatibility work.

Use `UsageHelper.ps1 -Once` for real usage, `-Diagnose` for pet discovery, and `start.ps1 -Demo` for sample-data preview. Run `tests.ps1` to verify quota handling, reset times, DPI conversion, screen-edge placement, and hover boundaries. Hardware-specific multi-monitor behavior still requires manual testing.
