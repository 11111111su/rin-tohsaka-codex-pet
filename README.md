# 远坂凛 · Codex 本地宠物

远坂凛的 Codex v2 宠物资源，包含原始 `pet.json` 和 `spritesheet.webp`。

## Windows 安装

下载本仓库 ZIP 并解压，打开解压目录的 PowerShell，执行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\install.ps1
```

脚本将资源安装到 `$CODEX_HOME/pets/rin-tohsaka`；未设置 `CODEX_HOME` 时使用 `$HOME/.codex/pets/rin-tohsaka`。已有同名宠物时脚本会停止；确认需要覆盖后可追加 `-Force`。

安装后重启 Codex，在宠物选择界面选择“远坂凛”。需要支持本地 v2 宠物的 Codex 桌面版本。

## macOS / Linux 手动安装

在仓库目录执行：

```sh
mkdir -p "${CODEX_HOME:-$HOME/.codex}/pets/rin-tohsaka"
cp rin-tohsaka/pet.json rin-tohsaka/spritesheet.webp "${CODEX_HOME:-$HOME/.codex}/pets/rin-tohsaka/"
```

## 文件

- `rin-tohsaka/pet.json`：名称、说明和 v2 精灵图路径。
- `rin-tohsaka/spritesheet.webp`：宠物动画精灵图。
- `install.ps1`：Windows 安装脚本。

此仓库为个人角色宠物资源，与角色原作及 OpenAI 无官方关联；角色相关权利归原权利人所有。
