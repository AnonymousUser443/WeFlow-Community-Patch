# WeFlow 5.0.0 Community Hotfix 1

这是一个面向 Windows x64 的社区热修复安装包。

## 修复

- WeLive 引擎过期后自动回退到 WCDB 导出，避免错误码 `-101` 和过期提示导致导出失败。
- 批量导出不再为每个会话重复拉起已确认不兼容的 WeLive 引擎。
- 修复私聊页面首次点击“导出”永久停在“正在准备导出模块”。
- 显式传递账号目录，改善多账号/自定义数据目录兼容性。

## 安装

退出 WeFlow（包括托盘进程），下载并运行：

`WeFlow-5.0.0-Community-Hotfix.1-Setup.exe`

SHA-256：

`FD93BED91FC30086158ECB6CB8EC66B6CFEB9BAEFB0CF516B35B26FB9CA655E5`

源码用户可下载仓库中的 `patches/weflow-community-hotfix.patch`。

本补丁基于 WeFlow，按 CC BY-NC-SA 4.0 许可作非商业分享。
