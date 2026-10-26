# 架构

```text
明确配置的授权文件（只读）
  → AccountFileStore → AccountCatalog + Credential（内存）
  → AccountPresentation 去重排序，当前账号第一，展示全部账号
  → RefreshPolicy 分账号调度
  → UsageProviding / UsageClient
  → QuotaSnapshot → PeekModel → SwiftUI / NSPanel
```

核心库不依赖 AppKit 或 SwiftUI。应用层负责文件元信息检查、主线程状态更新、系统休眠事件与界面。未来展示其他信息时新增模型和查询实现，窗口容器无需重新设计；第一版不引入插件系统。

## 身份与认证

稳定账号标识由 workspace/account ID 与 JWT subject 组成，避免同一工作区中的不同登录者混淆。JWT 本地解码只用于显示、分组和过期判断，真实性由 HTTPS 服务端验证。当前 auth 文件与 stash 合并，同身份优先使用较晚到期的凭据。

只提取查询所需访问令牌，refresh_token 不进入模型。授权文件不写回，令牌不复制到磁盘或 UserDefaults。设置保存账号标识、用户别名、透明度、路径和窗口位置（兼容保留旧版选择值，但不再用于筛选）。第一版没有独立登录流程，无需创建自己的 Keychain 项。

## 数据读取

最初评估了官方 `account/rateLimits/read`。本机 Codex 0.164.0 将外部令牌登录协议标注为内部专用，且常驻子进程不符合轻量目标。因此首版直接只读 `https://chatgpt.com/backend-api/wham/usage`；这是兼容性风险集中点，封装在 UsageClient 中。

服务返回的 `rate_limit` 是主订阅额度，其他 `additional_rate_limits`、代码审查、积分等字段不会混入主额度。根据实际窗口秒数识别 18,000 秒与 604,800 秒，不依赖 primary/secondary 顺序。服务返回 account_id 时必须匹配所请求工作区。

## 调度

单个轻量时钟每秒检查两处文件元信息及到期任务。所有展示账号参与刷新，单账号只有一个请求，总并发最多三个；优先处理更早到期的账号，避免列表前面的账号长期占用查询机会。请求 ticket 和凭据 revision 必须同时匹配才能更新状态；更换凭据、取消任务或移除账号后旧响应无效。

常规失败指数退避，普通上限 300 秒；429 遵守 Retry-After，即使超过 300 秒也等待。手动刷新不会绕过 429 冷却。休眠取消任务，唤醒重读文件并查询；额度到达重置时间仍以服务返回结果为准。

不会伪造服务端推送：当前 HTTP Provider 采用轮询，没有用量更新通知。由于每个账号授权独立，无需通过反复切换 Codex 当前账号来查询。

## 动态窗口

CapsuleLayout 统一计算视图和 NSPanel 的高度：单账号 44 pt，双账号 64 pt，后续每行增加 23 pt。窗口 resize 保持顶部位置并约束在屏幕可见区域；超过屏幕高度时用滚动展示完整列表。订阅 catalog 的去重后账号数量，数量不变时无需调整窗口。
