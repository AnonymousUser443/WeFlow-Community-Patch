# WeFlow 5.0.0 Community Hotfix 2

这是一个面向 Windows x64 的社区热修复安装包。

## 修复

- WeLive 引擎过期后自动回退到 WCDB 导出，避免错误码 `-101` 和过期提示导致导出失败。
- 批量导出不再为每个会话重复拉起已确认不兼容的 WeLive 引擎。
- 修复私聊页面首次点击“导出”永久停在“正在准备导出模块”。
- 显式传递账号目录，改善多账号/自定义数据目录兼容性。
- 修复 WCDB 兼容导出中语音统一显示 `Silk 解码失败`：Export Worker 现在使用真实的 Electron resources/app 路径加载 `silk-wasm` 与 WASM。

## 安装

退出 WeFlow（包括托盘进程），下载并运行：

`WeFlow-5.0.0-Community-Hotfix.2-Setup.exe`

SHA-256：

`CD334F4DF75B8EB2D8473B77198E1992A90D5D01508327EC7B8B38A5B629A7C6`

源码用户可下载仓库中的 `patches/weflow-community-hotfix.patch`。

本补丁基于 WeFlow，按 CC BY-NC-SA 4.0 许可作非商业分享。

---

# WeFlow 5.0.0 Community Hotfix 3

这是一个面向 Windows x64 的社区热修复安装包，在 Hotfix 2 的基础上修复**原生库构建过期**问题。

## 修复

- **修复启动即报 `-101`**：WeFlow 随包分发的原生库 `wcdb_api.dll` 内置两个硬编码的构建过期开关（都指向 2026-09-30 23:59:59）。到期后 `InitProtection()` 返回 `-101`、`wcdb_init()` 返回 `-1000`，应用表现为弹窗「WeFlow 启动失败 / 错误码: -101」，数据库完全无法初始化。本安装包内置的 `wcdb_api.dll` 已禁用这两个开关（仅 6 个字节，执行路径与过期前一致）。
- 包含 Hotfix 2 的全部修复：WeLive 引擎过期后自动回退 WCDB 导出、批量导出不再重复拉起失效引擎、修复私聊首次点击「导出」卡在「正在准备导出模块」、修复兼容导出中语音显示 `Silk 解码失败`。

## 安装

退出 WeFlow（包括托盘进程），下载并运行：

`WeFlow-5.0.0-Community-Hotfix.3-Setup.exe`

SHA-256：

`FBE8D7A2367299145C838215C4733CBCC8D7E4DA8F403D731A9AB5B917520625`

## 不想重装？

现有安装可以只替换一个文件：用 `binaries/wcdb_api.dll`（已修补）覆盖

`%ProgramFiles%\WeFlow\resources\resources\wcdb\win32\x64\wcdb_api.dll`

或运行 `scripts/Patch-WcdbApiExpiry.ps1` 就地修补。

原理、反汇编与验证方法见 `docs/NATIVE-EXPIRY-GATE.md`。

本补丁基于 WeFlow，按 CC BY-NC-SA 4.0 许可作非商业分享。
