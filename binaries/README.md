# 预编译二进制

## wcdb_api.dll（已禁用构建过期开关）

- 文件：`binaries/wcdb_api.dll`
- 对应上游：WeFlow 5.0.0 win32-x64 随包分发的 `resources/resources/wcdb/win32/x64/wcdb_api.dll`
- 原始 SHA-256：`6397760DA70DE8062829FBE6A2EC01CF0616D6F2B334E6FE54873898F38F7AD7`
- 本文件 SHA-256：`1536606B1B1B2A0DC9DE631A7F45504F5D466DE0979E50B3F94548AE124993D0`
- 改动：**仅 6 个字节**，禁用两个硬编码的构建过期开关（`InitProtection()` 返回 `-101`、`wcdb_init()` 返回 `-1000`）。两处都只是把"条件跳到成功出口"改成"无条件跳到同一出口"，执行路径与过期前逐字节一致。

原理、反汇编与验证方法见 [原生库构建过期开关的诊断与修补](../docs/NATIVE-EXPIRY-GATE.md)。

## 使用

1. 完全退出 WeFlow，包括系统托盘中的后台进程。
2. 备份原文件，然后用本文件覆盖：

   ```powershell
   $dll = "$env:ProgramFiles\WeFlow\resources\resources\wcdb\win32\x64\wcdb_api.dll"
   Copy-Item -LiteralPath $dll -Destination "$dll.bak-expiry" -Force
   Copy-Item -LiteralPath .\binaries\wcdb_api.dll -Destination $dll -Force
   ```

3. 启动 WeFlow，确认日志（`%APPDATA%\weflow\logs\wcdb.log`）出现 `open ok handle=1`。

也可以不下载二进制，改用脚本对你自己机器上的 DLL 就地修补：`scripts/Patch-WcdbApiExpiry.ps1`。

## 校验

```powershell
Get-FileHash -Algorithm SHA256 .\binaries\wcdb_api.dll
```

应得到 `1536606B1B1B2A0DC9DE631A7F45504F5D466DE0979E50B3F94548AE124993D0`。

## 回滚

把 `wcdb_api.dll.bak-expiry` 覆盖回去即可，或删除安装目录后重装热修包。

> **重装、修复安装或升级 WeFlow 都会覆盖该文件**，过期错误会再次出现，需要重新替换或重跑脚本。

## 说明

本文件是对上游预编译组件的修补版，仅为让已安装的 WeFlow 在本机继续可用，**不是**上游官方产物。许可证沿用上游 CC BY-NC-SA 4.0，仅限非商业使用。
