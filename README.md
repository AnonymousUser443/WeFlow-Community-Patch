# WeFlow Community Patch

面向 WeFlow 5.0.0 的社区热修复，解决 2026 年 7 月底后聊天记录导出失效，以及私聊页面首次点击“导出”时卡在“正在准备导出模块”的问题。

> 本仓库不是 WeFlow 官方仓库。补丁基于上游项目 [hicccc77/WeFlow](https://github.com/hicccc77/WeFlow)，仅用于非商业的社区修复与交流。

## 修复内容

- WeLive 导出引擎提示 `this build has expired` 时，自动切换到内置 WCDB 导出路径。
- WeLive 原生握手返回 `-101`、proof/finish 失败或进程异常退出时，不再重复拉起失效引擎。
- 批量导出中检测到不兼容后，后续会话直接使用 WCDB，避免每个会话都等待失败。
- 修复私聊页面冷启动后首次点击“导出”卡死：把一次性 `CustomEvent` 改为可持久消费的 Zustand 请求。
- 导出上下文显式传递账号目录，降低多账号或非默认目录下读错路径的风险。

## 直接安装（推荐）

适用环境：Windows 10/11 x64、WeFlow 5.0.0、微信 4.x。

1. 退出 WeFlow，包括系统托盘中的后台进程。
2. 从 [最新 Release](../../releases/latest) 下载 `WeFlow-5.0.0-Community-Hotfix.1-Setup.exe`。
3. 使用仓库中的校验脚本核对安装包：

   ```powershell
   .\scripts\Verify-Installer.ps1 -Installer "$env:USERPROFILE\Downloads\WeFlow-5.0.0-Community-Hotfix.1-Setup.exe"
   ```

4. 运行安装包，按提示覆盖安装。
5. 启动后直接进入任意私聊，第一次点击“导出”也应正常打开导出面板。

安装包 SHA-256：

```text
FD93BED91FC30086158ECB6CB8EC66B6CFEB9BAEFB0CF516B35B26FB9CA655E5
```

## 给开发者：应用源码补丁

补丁目标是 WeFlow 5.0.0 源码仓库，生成基线为提交 `e5b7067aa0554151d2762c6f889dd47bc1bf2f46`。请先提交或暂存自己的修改，再执行：

```powershell
git clone https://github.com/AnonymousUser443/WeFlow-Community-Patch.git
cd WeFlow-Community-Patch
.\scripts\Apply-Patch.ps1 -WeFlowRoot "D:\path\to\WeFlow"
```

也可以手动执行：

```powershell
git -C "D:\path\to\WeFlow" apply --check ".\patches\weflow-community-hotfix.patch"
git -C "D:\path\to\WeFlow" apply ".\patches\weflow-community-hotfix.patch"
```

然后在 WeFlow 源码目录中验证并构建：

```powershell
npm ci
npm run typecheck
npm run build
```

## 已完成的验证

- `npm run typecheck`
- `npm run build`
- WeLive 过期错误自动进入 WCDB 回退路径
- 模拟原生握手 `-101` 自动进入 WCDB 回退路径
- 私聊导出请求可在懒加载页面挂载前保存，并在挂载后消费
- 标准 NSIS 安装包生成成功

## Windows Defender 提示

在部分 Windows 环境中，实时防护可能会在 electron-builder 改写 EXE 资源时短暂锁定文件，表现为 `EBUSY`。如果你从源码构建且确认源码可信，可临时只排除当前源码/构建目录，构建完成后再移除排除项。不要关闭整机防护。

## 隐私与安全

补丁只调整本地导出流程，不会上传聊天记录。本仓库不包含任何聊天数据库、账号目录、解密密钥、本地配置、备份二进制或调试日志。

## 许可证与归属

补丁属于对上游 WeFlow 的改编材料，沿用上游的 [CC BY-NC-SA 4.0](LICENSE) 许可，仅限非商业用途，并应保留署名、采用相同方式共享。WeFlow、微信及相关名称和商标归各自权利人所有。
