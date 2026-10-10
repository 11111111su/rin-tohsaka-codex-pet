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

This repository contains a personal character pet and is not officially affiliated with the original franchise or OpenAI. Character rights belong to their respective owners.
