# CodexPeek 第一版实现计划

> 在当前会话逐项实施并验证，不派生子代理。所列 using/executing-plans 扩展技能当前不可用，直接按本计划执行。

**目标：** 构建个人使用的原生 macOS 双账号额度胶囊悬浮窗。

**架构：** SwiftPM 核心库管理账号来源、额度解析、调度与设置，应用层用 SwiftUI + AppKit 展示。仅从既有文件读取授权，不覆盖 Codex 登录状态，不轮换共享令牌。预先验证的只读 HTTPS 查询封装在可替换 Provider 内；不使用本机协议标记为内部专用的登录模式。

**技术栈：** Swift 6.2 工具链、Swift 5 语言模式、macOS 13+、Foundation URLSession、SwiftUI、AppKit、零依赖可执行核心检查；无第三方依赖。

## 全局约束

- 项目名称 CodexPeek，不添加 LICENSE，不称为开源项目。
- 展示最多两个账号，默认跟随当前账号并固定另一账号；支持两个固定账号。
- 默认每 5 秒刷新，支持 5、10、30 秒；只有可见账号查询。
- 缺失额度显示不可用，缓存显示更新时间，失败退避；休眠暂停、唤醒刷新。
- 源文件只读；认证信息不写入日志、测试、设置或 Git；不主动使用 refresh_token。
- 紧凑胶囊约 200 × 64 pt；详情在独立弹层，菜单栏负责隐藏、置顶和退出。

## 文件与接口

```text
Sources/CodexPeekCore/
  Models/Account.swift                 Account、Credential、AccountCatalog
  Models/Quota.swift                   QuotaWindow、QuotaSnapshot、QuotaError
  Accounts/AccountFileStore.swift      AccountFileStore.load() throws -> AccountCatalog
  Providers/UsageClient.swift          UsageProviding.fetch(Credential) async throws -> QuotaSnapshot
  Monitoring/RefreshPolicy.swift       每账号请求状态、退避、凭据版本检查
  Persistence/PeekSettings.swift       Codable 设置；不保存认证
Sources/CodexPeekApp/
  App/Entry.swift                      NSApplication 启动及 --diagnose 只读诊断
  App/PeekModel.swift                 主线程模型，调度、文件变化、休眠恢复
  Views/CapsuleView.swift              两行额度和错误状态
  Views/DetailView.swift               账号选择、别名、倒计时、设置
  Window/WindowController.swift       NSPanel、菜单栏、拖动和位置保存
Tests/CodexPeekCoreTests/              纯模拟数据测试
scripts/build-app.sh                 release .app 打包，可指定目标架构
packaging/Info.plist                 LSUIElement 菜单栏应用
.github/workflows/ci.yml             macOS 编译与测试
README.md、README.en.md、docs/、SECURITY.md、CONTRIBUTING.md
```

## 任务 1：验证查询，建立账号及额度核心

- [x] 检查两个账号的凭据结构及有效期，不输出实际账号标识和令牌。
- [x] 对未过期账号执行只读查询，只输出状态码及额度字段结构；不得降低 TLS 校验。
- [x] 创建 Package.swift，定义 CodexPeekCore 库和 CodexPeek 可执行程序，macOS 下限 13。
- [x] Account 使用账号 ID 加 subject 的稳定标识，Credential 只保留访问令牌、有效期和版本指纹。JWT 仅提取展示信息，不作为真实性校验。
- [x] AccountFileStore 支持 stash 及当前 auth 文件：合并去重、优先当前凭据、处理缺失与格式错误、可配置路径。解析时按记录隔离错误，不能因单条错误丢失整个列表。
- [x] QuotaWindow 按 300 和 10080 分钟识别窗口；HTTP 原始秒数换算；优先 codex 桶，忽略其他桶，缺字段不补零；剩余百分比限定在 0…100。
- [x] UsageClient 使用 ephemeral URLSession，固定 HTTPS 主机和用量路径，禁止跨站重定向，不缓存授权请求，不输出响应内容；401/403 映射授权错误，429 解析 Retry-After，超时与网络失败使用无敏感信息错误。
- [x] 编写核心检查：反向窗口、缺字段、额外额度桶、无效数值、账号去重、过期认证、原子替换重读、401/429、拒绝重定向；URLProtocol 返回人工响应。
- [x] 运行 `swift run CodexPeekChecks`，预期测试通过；提交本阶段代码和设计。

## 任务 2：刷新与账号变化状态机

- [x] RefreshPolicy 为每账号保存 nextDue、失败次数、inFlight、credentialRevision；开始请求返回 UUID ticket，结果必须同时匹配 ticket 和凭据版本。
- [x] 失败按刷新间隔指数退避，上限 300 秒；服务器 Retry-After 优先于普通退避。手动刷新不得绕过限流等待。
- [x] PeekSettings 保存固定账号、跟随开关、别名、间隔、置顶和来源路径，默认 5 秒；选择结果去重且不超过两个，失效固定位置明确报错而不自动替换。
- [x] 主线程 PeekModel 使用一条合并轮询循环，比较两个明确文件的元信息，变化时读取；下一秒额外重试一次不完整的原子替换，不扫描其他目录。每 1 秒调度到期任务，不每秒刷新整棵视图。
- [x] 账号与令牌变化先失效旧请求、清除旧快照；请求完成仅接受仍可见且 ticket 有效的结果。隐藏主窗口时仍查询可见选择；系统休眠取消循环及进行中的请求，唤醒立即重新读取。
- [x] 测试同账号不并发、退避、Retry-After、凭据变化丢弃旧结果、移除账号、相同 ticket 重复返回、选择去重。
- [x] 运行 `swift run CodexPeekChecks`，提交本阶段变更。

## 任务 3：原生胶囊与详情

- [x] NSPanel 无标题透明圆角背景，默认 floating，允许跨桌面及全屏辅助显示，不抢占当前输入焦点。内容两行，缺账号时显示配置入口。
- [x] 每行显示当前标记、短别名、5h 和周剩余百分比。低于 20% 橙色、低于 10% 红色；无数据显示 —，错误显示简短状态，保留旧快照时标记过期。悬停 tooltip 包含重置时间和最后更新。
- [x] 拖动窗口背景保存位置；恢复时约束在连接屏幕可见区域，避免换显示器后消失。点击行打开独立 NSPopover，不改变胶囊尺寸。
- [x] 详情包含账号选择、跟随当前账号、别名编辑、当前额度与倒计时、最近更新时间、错误说明、5/10/30 秒刷新、源路径、置顶设置和手动刷新。刷新可改变的数据每秒时间线仅在弹层显示时使用。
- [x] 菜单栏可显示/隐藏窗口、打开详情、置顶和退出。用系统 SF Symbol，避免引入生成图片资源。
- [x] 加入 --demo 使用人工数据预览，以及 --diagnose 进行不显示账号或令牌的本机读取/查询检查。
- [ ] 运行 `swift build` 和 `swift run CodexPeekChecks`；本机打开 demo 检查布局、拖动、详情和菜单栏，再验证真实数据。

## 任务 4：打包、文档与交付

- [x] build-app.sh 严格模式执行 `swift build -c release`，创建 dist/CodexPeek.app 及 Info.plist；本地 ad-hoc 签名，不声称 Developer ID 签名或公证。支持通过 SwiftPM --arch 参数选择 arm64 或 x86_64，默认分别构建两种架构并合并为通用二进制。
- [x] .gitignore 排除 .build、dist、.DS_Store、真实认证文件及本地诊断产物；不误排除人工测试 fixture。
- [x] 文档解释默认只读路径、过期账号处理、5 秒轮询语义、内部接口兼容性、无 CLI 依赖、凭据不写入磁盘、不自动续期、构建和运行方式及手工 QA 清单。
- [x] CI 使用 macOS runner 执行 `swift run CodexPeekChecks`、打包及 plutil 校验，不访问真实认证或网络额度接口。
- [x] 最终运行 `swift run CodexPeekChecks`、`scripts/build-app.sh`、`plutil -lint`；检查 git diff、敏感文件路径及无许可证要求。
- [ ] 运行真实只读诊断，显示成功/过期/网络故障的脱敏摘要；测量应用进程的 RSS 和 CPU，标明测量场景及架构。
- [x] 提交已验证代码，将 .app 路径和测试结果交付用户；没有授权前不创建远程仓库或上传代码。

## 计划自检

界面、双账号、自动切换、刷新、错误、休眠、打包、文档与凭据边界均由上述任务覆盖。不同信息展示通过新增 Models 和 Provider 扩展，不预先设计插件系统。第一版不实现新登录授权、历史趋势、额度提醒、自动更新或商业发布流程。

## 实施调整

本机 CLT 未附带 XCTest，测试改为同一包内的 CodexPeekChecks 可执行程序，保留独立测试文件和断言失败退出码。只读查询验证成功；本地 stash 中存在过期令牌，因此过期账号提示重新登录，不自动轮换共享令牌。

## 本机验证状态

- 核心检查：17 项通过，包含人工 HTTP 请求与失败响应。
- 应用编译及本地打包：arm64 与 x86_64 均编译通过，通用 .app 打包及签名校验通过。
- 原生只读诊断：最终打包应用对两个选中账号查询均成功；另有过期账号由本地拒发请求。
- 电脑使用权限未授予，未进行窗口拖动、菜单点击、跨桌面、真实休眠与切换工具交互验收；不声称已完成 GUI QA。
- 未测量真实 UI 常驻资源占用，不承诺内存或功耗数值。
