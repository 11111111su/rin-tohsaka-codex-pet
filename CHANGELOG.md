# 更新记录 / Changelog

## v1.1.2

- 修复宠物重新打开及启动器恢复时弹出 PowerShell 窗口的问题。
- 使用 GUI 启动程序及 CreateNoWindow 启动后台进程，保留独立任务恢复和宠物联动。
- 增加正常启动与自动恢复后的控制台窗口检查。

Use a GUI launcher and CreateNoWindow for background startup, including recovery and pet reopening.

## v1.1.1

- 修复启动器退出后无法恢复：使用 Windows 独立任务在登录时启动，并每分钟检查是否需要恢复。
- 将助手安装到用户的 Documents/Codex/RinCodexUsage，确保 Windows 任务和 Codex 都能访问安装文件。
- 手动停止同时暂停自动恢复，显式启动可重新启用联动；保留宠物关闭后停止额度助手的行为。

Fix automatic startup and recovery using a current-user scheduled task and a shared Documents installation directory.

## v1.1.0

- 宝石刻度双环显示 5 小时和每周剩余额度、重置倒计时及时间。
- 额度助手随 Codex 内置宠物自动启动和退出，支持 Windows 登录启动。
- 酒红宝石托盘图标，提供多种尺寸适配 Windows 缩放；托盘提示显示版本号。
- 当前用户安装、更新及关闭联动脚本。

The usage helper now includes jewel ring gauges, synchronization with the built-in pet, Windows sign-in startup, and a ruby tray icon with a visible version tooltip.
