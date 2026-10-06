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

# WeFlow 5.0.0 Community Hotfix 3（脚本补丁，无新安装包）

## 修复

- 修复原生库 `wcdb_api.dll` 的构建过期开关：2026-10-01 起 WeFlow 每次启动弹出「WeFlow 启动失败 / 错误码: -101」、数据库无法初始化。仓库新增 `scripts/Patch-WcdbApiExpiry.ps1`，用于就地修补该 DLL 的两个过期开关（`InitProtection()` → `-101`、`wcdb_init()` → `-1000`）。

## 使用

退出 WeFlow（包括托盘进程）后执行：

```powershell
.\scripts\Patch-WcdbApiExpiry.ps1 -DllPath "$env:ProgramFiles\WeFlow\resources\resources\wcdb\win32\x64\wcdb_api.dll"
```

本版**不提供新的安装包**：Hotfix 2 的安装包依然有效，安装完成后再执行上面的脚本即可。

原理与验证方法见 `docs/NATIVE-EXPIRY-GATE.md`。

本补丁基于 WeFlow，按 CC BY-NC-SA 4.0 许可作非商业分享。
