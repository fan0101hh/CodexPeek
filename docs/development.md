# 开发与验证

## 工程布局

`Sources/CodexPeekCore`：模型、只读账号来源、HTTPS Provider、刷新策略及设置。

`Sources/CodexPeekApp`：生命周期、可观察模型、胶囊与详情视图、NSPanel 及菜单栏。

`Tests/CodexPeekCoreTests`：纯人工授权和响应，CI 不需要真实账号或联网查询。

`packaging` 和 `scripts`：.app 元数据及本地打包，不依赖第三方项目生成器。

## 命令

```bash
swift run CodexPeekChecks
swift run CodexPeek --demo
bash scripts/build-app.sh
plutil -lint dist/CodexPeek.app/Contents/Info.plist
codesign --verify --strict dist/CodexPeek.app
```

在受限制的自动化环境中，SwiftPM、Clang 需要可写编译缓存；应申请所需权限，不要通过修改用户 HOME 或降低沙盒安全级别绕过限制。

## 本机验收清单

- 14 寸屏幕下两行均能看清，不覆盖详情；悬停出现重置信息。
- 可拖动顶部短线；重启位置恢复；断开外接屏幕后仍位于可见区域。
- 点击打开详情，账号动态增减、当前账号置顶排序、别名输入、5/10/30 秒设置可用。
- 切换 Codex 账号后标记变化，迟到请求不会将旧数据覆盖到新账号。
- 来源原子替换、部分写入、账号移除、过期认证均有明确状态。
- 网络断开后保留旧数据并标记，恢复后自动重试；休眠无请求，唤醒重新读取。
- 菜单栏隐藏/显示、退出和窗口置顶符合设置。
- 真实多账号查询不写入源文件、不启动子进程；分别验证两种切换工具更新源文件的行为。

这些交互不能仅由核心单元测试代替。跨桌面、全屏、物理休眠和不同显示器需要在实际桌面验证。

## 资源测量

使用活动监视器或 `ps` 查看 CodexPeek 进程。分别记录 demo 空闲和真实账号轮询的 RSS、CPU、运行时长与硬件架构；瞬时 CPU 不等于耗电测量。架构编译通过也不等于已在该架构真机验证。初始构建环境是 Swift 6.2.1、macOS 26.1 SDK、x86_64 编译目标。

## 发布

当前脚本仅生成本地 ad-hoc 签名 .app。GitHub Actions 打包只供构建检查；对外分发前应另行配置签名、公证及实际运行验证，不把 Apple 凭据写入仓库。项目未添加许可证，不应在包元数据中默认声明 MIT。
