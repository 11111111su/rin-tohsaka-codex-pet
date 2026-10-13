# 远坂凛 · Codex 本地宠物

[中文](#中文) | [English](#english)

## 中文

远坂凛的 Codex v2 宠物资源，包含原始 `pet.json` 和 `spritesheet.webp`。

### Windows 安装

下载本仓库 ZIP 并解压，打开解压目录的 PowerShell，执行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\install.ps1
```

脚本将资源安装到 `$CODEX_HOME/pets/rin-tohsaka`；未设置 `CODEX_HOME` 时使用 `$HOME/.codex/pets/rin-tohsaka`。已有同名宠物时脚本会停止；确认需要覆盖后可追加 `-Force`。

安装后重启 Codex，在宠物选择界面选择“远坂凛”。需要支持本地 v2 宠物的 Codex 桌面版本。

### macOS / Linux 手动安装

在仓库目录执行：

```sh
mkdir -p "${CODEX_HOME:-$HOME/.codex}/pets/rin-tohsaka"
cp rin-tohsaka/pet.json rin-tohsaka/spritesheet.webp "${CODEX_HOME:-$HOME/.codex}/pets/rin-tohsaka/"
```

### 文件

- `rin-tohsaka/pet.json`：名称、说明和 v2 精灵图路径。
- `rin-tohsaka/spritesheet.webp`：宠物动画精灵图。
- `install.ps1`：Windows 安装脚本。

### 悬停查看 Codex 额度（Windows）

安装远坂凛后，双击 `enable-auto-usage.cmd` 启用宠物联动。显示宠物时额度助手自动启动；关闭宠物或退出 Codex 后，助手和额度连接自动退出，再次显示宠物会恢复。鼠标停留约 0.35 秒后，会在内置宠物旁显示宝石刻度双环、剩余额度和重置时间。卡片随拖动移动，移开鼠标自动隐藏。

联动安装器会安装当前用户的 Windows 登录启动项；后台启动器仅在宠物显示时运行额度助手。`disable-auto-usage.cmd` 可关闭联动，`stop-usage.cmd` 暂停当前登录期间的联动，`start-usage.cmd` 恢复联动或手动启动。助手通过 Codex 官方本机接口读取额度，保留原宠物的动画、点击和拖动操作。无需额外安装运行库。详见 [额度助手说明](usage-helper/README.md)。

此仓库为个人角色宠物资源，与角色原作及 OpenAI 无官方关联；角色相关权利归原权利人所有。

## English

# Rin Tohsaka · Local Codex Pet

A v2 Codex pet featuring Rin Tohsaka, including the original `pet.json` and `spritesheet.webp` assets.

### Windows installation

Download this repository as a ZIP file and extract it. Open PowerShell in the extracted directory and run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\install.ps1
```

The script installs the assets to `$CODEX_HOME/pets/rin-tohsaka`, or `$HOME/.codex/pets/rin-tohsaka` when `CODEX_HOME` is not set. If a pet with the same ID already exists, the script stops. Add `-Force` to overwrite it intentionally.

After installation, restart Codex and select “远坂凛” in the pet picker. A Codex desktop version that supports local v2 pets is required.

### Manual installation on macOS / Linux

Run these commands from the repository directory:

```sh
mkdir -p "${CODEX_HOME:-$HOME/.codex}/pets/rin-tohsaka"
cp rin-tohsaka/pet.json rin-tohsaka/spritesheet.webp "${CODEX_HOME:-$HOME/.codex}/pets/rin-tohsaka/"
```

### Files

- `rin-tohsaka/pet.json`: Pet name, description, and v2 sprite sheet path.
- `rin-tohsaka/spritesheet.webp`: Animated pet sprite sheet.
- `install.ps1`: Windows installation script.

### Hover to view Codex usage (Windows)

Double-click `enable-auto-usage.cmd` to synchronize the helper with the built-in pet. Showing Rin starts the helper; closing the pet or exiting Codex stops it and its quota connection. Reopening the pet restores the helper. After hovering for about 0.35 seconds, jewel gauges show remaining usage and reset times. The card follows while dragging and hides when the pointer leaves.

The synchronization installer adds a current-user Windows sign-in shortcut and keeps an idle launcher available while the pet is closed. Use `disable-auto-usage.cmd` to disable synchronization, `stop-usage.cmd` to pause it for the current sign-in, and `start-usage.cmd` to resume it or launch manually. The helper uses the official local Codex interface and preserves the pet's animations, clicks, and dragging. No additional runtime is required. See the [usage helper guide](usage-helper/README.md).

This repository contains a personal character pet and is not officially affiliated with the original franchise or OpenAI. Character rights belong to their respective owners.
