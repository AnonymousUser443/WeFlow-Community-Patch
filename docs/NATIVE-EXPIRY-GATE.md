# 原生库构建过期开关的诊断与修补

## 现象

2026-10-01 起，WeFlow 5.0.0 每次启动弹出：

```text
WeFlow 启动失败
启动失败，请反馈错误码。
错误码: -101
```

数据库完全无法初始化，聊天页为空。与微信版本无关（升级或降级微信都无效）。

## 报错链路

- 主进程 `chatService` 在 `wcdbService.open()` 失败后，若错误码属于安全类（`-101`、`-102`、`-1006`、`-2299`、`-2301`、`-2302`、`-2201..-2212`）就弹出上面的对话框。
- `wcdbService.open()` 先调用 `initialize()`；`initialize()` 里先调 `InitProtection(resourcePath)`，非 0 直接失败；为 0 才继续调 `wcdb_init()`，非 0 同样失败。

## 容易误判的方向

- **微信版本更新**：实测无关。两个过期开关只读取系统时间，不读取微信进程或版本。
- **应用构建过期**：方向正确，但过期点在随包分发的**预编译原生库**里，`npm run build` 不能修复，重装热修包也不能修复。
- **资源路径不对**：`InitProtection` 的 `resourcePath` 形参实际**从未被使用**（函数入口用 `lea rcx, "InitProtection"` 覆盖了它），因此任何候选路径都得到同一结果。
- **配置或密钥损坏**：两个错误码都发生在打开账号之前。

## 根因：`wcdb_api.dll` 内置两个硬编码过期开关

文件：`resources/resources/wcdb/win32/x64/wcdb_api.dll`（上游提交的预编译产物，x64，PE 时间戳 2026-07-07）。

### 开关 1：`InitProtection()`

```asm
call qword ptr [rip+...]      ; _time64(NULL)
cmp  rax, 0x6ABDA27F          ; 1790812799 = 2026-09-30 23:59:59 UTC
jle  ok                       ; 未过期 -> 正常初始化
mov  eax, 0xFFFFFF9B          ; return -101
ret
ok:
call ...                      ; 真正的初始化
xor  eax, eax                 ; return 0
```

### 开关 2：`wcdb_init()`

它**没有**使用单个立即数常量，而是拼出一个 `struct tm` 再交给 `_mktime64()`（本地时间），所以只扫描"时间常量"会漏掉它：

```asm
mov dword ptr [rsp+..], 0x7e  ; tm_year = 126 -> 2026
mov dword ptr [rsp+..], 8     ; tm_mon  = 8   -> 9 月（0 基）
mov dword ptr [rsp+..], 0x1e  ; tm_mday = 30
mov dword ptr [rsp+..], 0x17  ; tm_hour = 23
mov dword ptr [rsp+..], 0x3b  ; tm_min  = 59
mov dword ptr [rsp+..], 0x3b  ; tm_sec  = 59
call qword ptr [rip+...]      ; _mktime64(&tm)
cmp  rax, rbx
jle  ok                       ; now <= 过期点 -> 返回 0
...                           ; 过期路径
mov  eax, 0xFFFFFC18          ; return -1000
ok:
xor  eax, eax
```

**两个开关必须一起修。** 只修开关 1 之后 `-101` 会消失，但 `wcdb_init()` 转而返回 `-1000`，现象变成：日志里 `initialize` 每隔一段时间反复重试，始终等不到 `open ok`，界面依旧连不上数据库。

## 修复

把两个过期判断的条件分支改成"无条件跳到同一个成功出口"。执行路径与过期前**逐字节一致**，不跳过任何初始化、不引入新行为。

| # | 位置（RVA） | 原始字节 | 补丁后 | 说明 |
| --- | --- | --- | --- | --- |
| 1 | `0x819C5` | `7E` | `EB` | `jle` → `jmp` |
| 2 | `0xE91D7` | `0F 8E 30 01 00 00` | `E9 31 01 00 00 90` | `jle rel32` → `jmp rel32` + `nop` |

| | SHA-256 |
| --- | --- |
| 原始 DLL | `6397760DA70DE8062829FBE6A2EC01CF0616D6F2B334E6FE54873898F38F7AD7` |
| 修补后 DLL | `1536606B1B1B2A0DC9DE631A7F45504F5D466DE0979E50B3F94548AE124993D0` |

使用仓库中的脚本就地修补（退出 WeFlow 后执行）：

```powershell
.\scripts\Patch-WcdbApiExpiry.ps1 -DllPath "$env:ProgramFiles\WeFlow\resources\resources\wcdb\win32\x64\wcdb_api.dll"
```

也可以直接使用仓库提供的已修补二进制 `binaries/wcdb_api.dll`（SHA-256 `1536606B...93D0`），详见 [binaries/README.md](../binaries/README.md)。

脚本特性：

- 按字节签名定位，不依赖固定文件偏移；
- 校验签名在整个文件中唯一命中，否则拒绝执行；
- 首次修补自动生成 `wcdb_api.dll.bak-expiry` 备份；
- 幂等：已修补过会提示 `ALREADY PATCHED`，可反复执行。

## 验证

1. **离线 A/B**：用 `koffi` 直接加载 DLL 调用导出函数 —— 原始 `InitProtection() = -101`、`wcdb_init() = -1000`；修补后两者均为 `0`。
2. **影子副本演练**：先复制整个安装目录，只对副本打补丁并启动，确认无副作用后再处理真实安装。
3. **看日志**：修补后启动应出现

   ```text
   [bootstrap] InitProtection call path=...
   open accountDir=<accountDir> dbStorage=<accountDir>\db_storage
   open sessionDb=...\session\session.db
   open ok handle=1
   ```

   并且不再出现 `InitProtection rc=-101`、`InitProtection failed`、`WCDB 初始化失败`。

> 说明：`wcdb_init()` 在返回 0 之前还会根据另一组状态码返回 `-1005` / `-1006` / `-1007`（与微信进程状态有关），这些与构建过期无关，不要误判。

## 注意事项

- 任何**重装、修复安装或升级**都会用原始 DLL 覆盖安装目录，`-101` 会再次出现，需要重新执行脚本。
- 同目录的 `welive.exe`（导出引擎）另有**独立**的过期开关（FILETIME `2026-07-31 16:00 UTC`）。该文件带自校验，改动其 `.text` 会触发 `-101`，**不要修改**；导出请依赖热修里的 WCDB 回退路径。
- 修补后的 DLL 未做数字签名，个别安全软件可能拦截或还原；如有需要，只对 WeFlow 安装目录加临时排除，不要关闭整机防护。

## 可迁移经验

- 预编译依赖里的"构建过期"无法用重新构建解决。排查时应把**分发的二进制**当成独立于源码的发布物。
- 过期判断不一定是一个立即数常量：拆成 `struct tm` + `_mktime64`、或由多条立即数拼装时，静态扫描常量一定会漏。更可靠的做法是先枚举**所有时间 API 调用点**（`_time64` / `_mktime64` / `GetSystemTimeAsFileTime` / `QueryPerformanceCounter`），再逐个看上下文。
- 区分"过期"与"被改动"最有效的办法是对照实验：同一个未改动的文件跨过某个时间点后由成功变失败，即可排除文件损坏与路径错误。
