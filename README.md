# CodexPeek

一个轻量的 macOS 原生悬浮窗，用来快速查看 Codex 订阅账号的剩余额度。

第一版专注双账号额度展示；代码将数据来源、查询、刷新和界面分开，后续可扩展其他信息。个人项目，无商业服务；公开源码不表示授予自由使用、修改或分发的许可，项目目前未添加许可证。

## 功能

- 约 212 × 64 pt 深色半透明胶囊，最多同时展示两个账号。
- 展示 5 小时、周剩余百分比；低于 20% 橙色，低于 10% 红色。
- 当前账号标记、自定义别名、跟随当前账号或固定选择两个账号。
- 悬停查看重置时间，点击打开详情、重置倒计时及设置。
- 默认每 5 秒查询，支持 10、30 秒；失败退避，休眠暂停、唤醒刷新。
- 拖动窗口边缘空白区域移动，保存位置；支持置顶和菜单栏隐藏。
- 不依赖 Codex CLI、Electron、WebView 或常驻查询子进程，无第三方库。

## 构建与运行

需要 macOS 13+、支持 Swift 6.0+ 的 Xcode / Command Line Tools。开发工具链需支持 macOS 13 目标，实际本机验证版本见 [开发说明](docs/development.md)。

```bash
swift run CodexPeekChecks
bash scripts/build-app.sh
open dist/CodexPeek.app
```

也可以双击 `dist/CodexPeek.app`。本地构建只做 ad-hoc 签名，没有 Developer ID 签名和公证；下载到其他 Mac 后可能受到 Gatekeeper 限制。

默认分别编译 Apple Silicon 与 Intel 后合并为通用二进制；也可以只构建指定架构：

```bash
CODEXPEEK_ARCH=arm64 bash scripts/build-app.sh
CODEXPEEK_ARCH=x86_64 bash scripts/build-app.sh
```

不访问真实账号的演示：

```bash
swift run CodexPeek --demo
```

自愿执行一次真实额度查询的脱敏诊断（退出码 0 表示至少一个账号查询成功）：

```bash
swift run CodexPeek --diagnose
```

## 账号来源

默认只读两个文件，路径可以在详情设置中修改：

| 文件 | 用途 |
| --- | --- |
| `~/.cc-switch/codex-login-stash.json` | 读取 `logins` 中已有的订阅账号授权 |
| `~/.codex/auth.json` | 识别本机当前使用的订阅账号，并合并最新访问令牌 |

不需要专门的切换工具适配器。通过 cc-switch、Magpie 或其他方式切换后，只要它更新这里配置的 Codex 认证文件，就能识别。使用 Keychain 或不同 `CODEX_HOME` 的登录方式，需要提供相应的文件来源；当前不直接读取其他应用的 Keychain。

第一次运行自动选择当前账号及另一个账号。若识别不到当前账号，则展示来源中最多两个账号；后续可以自行选择。当前账号与固定账号相同时合并为一行，已移除的固定账号显示不可用，不悄悄换成其他账号。

## 重要行为

- 百分比表示**剩余量**。缺失窗口显示 `—`，不把缺数据当作额度为零。
- 5 秒是客户端查询目标周期，服务端数据不保证每 5 秒变化；两账号理论上最多每分钟各 12 次正常查询，失败时降低频率。
- 账号文件元信息每秒检查，变化后重读；不扫描其他目录。不完整文件额外重试一次。
- 过期访问令牌不会自动刷新。请在原工具重新登录或切换以更新授权；旧的后台账号可能需要重新登录后才能显示。
- 网络失败时保留旧数据并变灰；详情标记为旧数据并显示更新时间。
- 查询直接访问 Codex 使用的内部 HTTPS 用量端点；这不是承诺稳定的公开 API，格式或授权机制变化时可能需要更新应用。
- 不调用模型、不消耗对话 token；查询仍可能受到服务端限流。

更多说明：[架构](docs/architecture.md) · [开发与验证](docs/development.md) · [凭据处理](docs/security.md) · [贡献说明](CONTRIBUTING.md) · [English](README.en.md)
