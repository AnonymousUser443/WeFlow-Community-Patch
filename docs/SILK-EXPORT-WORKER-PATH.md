# Electron Worker 中的 Silk WASM 路径排障

## 现象

WeLive 不可用并切换到 WCDB 兼容导出后，文本和图片可以正常导出，但语音统一显示 `Silk 解码失败`。

相关上游报告：

- [hicccc77/WeFlow#1049](https://github.com/hicccc77/WeFlow/issues/1049)
- [hicccc77/WeFlow#1060](https://github.com/hicccc77/WeFlow/issues/1060)

## 容易误判的方向

这个现象看起来像 Silk 格式变化、WASM 损坏或 Windows Defender 拦截，但样本与运行时检查排除了这些方向：

- 抽取的 20 个真实语音 BLOB 均以标准 `#!SILK_V3` 头开头。
- 同一版本的 `silk-wasm` 对 20 个样本全部解码成功。
- 源码与安装目录中的 `silk.wasm` 哈希一致。
- `silk-wasm` 在普通 Electron 上下文和真实 Worker 线程中均可加载、编码和解码。

因此，`Silk 解码失败` 只是上层统一错误提示，不能直接证明输入格式或解码器有问题。

## 根因

应用中存在三种含义不同、但容易混用的路径：

| 路径语义 | 打包后的典型值 | 用途 |
| --- | --- | --- |
| 额外业务资源目录 | `resources/resources` | WeLive 等 `extraResources` |
| `process.resourcesPath` | `resources` | Electron 打包资源根目录 |
| `app.getAppPath()` | `resources/app.asar` | 应用代码与 Node 模块解析基点 |

旧代码只向 Export Worker 传入额外业务资源目录，并用它的父目录推导 `appPath`。结果是：

```text
resourcesPath = .../resources/resources
appPath       = .../resources
```

`ChatService` 随后拼接出不存在的 WASM 路径：

```text
.../resources/resources/app.asar.unpacked/node_modules/silk-wasm/lib/silk.wasm
```

真实路径则是：

```text
.../resources/app.asar.unpacked/node_modules/silk-wasm/lib/silk.wasm
```

同时，基于错误 `appPath` 创建的 `require` 也无法从 `app.asar` 正确解析 `silk-wasm`。

## 修复原则

不要从某个 `extraResources` 子目录反推 Electron 运行时路径。主进程创建 Worker 时应显式传入：

```ts
electronResourcesPath: process.resourcesPath,
appPath: app.getAppPath()
```

Worker 将这两个值交给负责 Node 模块与 WASM 加载的服务；原来的额外业务资源路径继续专供 WeLive/WCDB 使用。这样不会把两套路径语义互相污染。

补丁也保留了向后兼容推导，以便旧调用方未传新字段时仍可运行，但显式路径始终优先。

## 验证清单

1. `npm run typecheck` 通过。
2. `npm run build` 成功生成 NSIS 安装包。
3. 打包后的 `exportWorker.js` 包含显式 Electron 路径配置。
4. `app.asar.unpacked/node_modules/silk-wasm/lib/silk.wasm` 随安装包存在。
5. 旧错误路径不存在，修复后的路径存在。
6. 用真实 `#!SILK_V3` 样本做解码抽测，而不是只根据 UI 的统一错误文案判断。

## 可迁移经验

在 Electron 多线程或子进程架构中，建议把 `process.resourcesPath`、`app.getAppPath()`、`userData`、缓存目录和业务 `extraResources` 当作不同类型的数据管理。即使它们都是字符串路径，也不要依赖 `dirname()` 或固定层级互相推导；打包、ASAR 设置或平台变化都会让这种隐含约定失效。
