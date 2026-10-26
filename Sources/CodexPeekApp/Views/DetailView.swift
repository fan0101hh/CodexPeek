import CodexPeekCore
import SwiftUI

struct DetailView: View {
    @ObservedObject var model: PeekModel
    let windowSettingsChanged: () -> Void
    @State private var stashPath = ""
    @State private var authPath = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("CodexPeek").font(.system(size: 18, weight: .semibold))
                        Text(model.demo ? "演示数据 · 不访问账号文件" : "所有账号，一眼查看剩余额度")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button { model.refresh() } label: { Image(systemName: "arrow.clockwise") }
                        .help("立即刷新；限流期间仍需等待")
                }
                if let notice = model.sourceNotice {
                    Text(notice).font(.caption).foregroundStyle(.orange).textSelection(.enabled)
                }
                ForEach(model.displayedIDs, id: \.self) { id in accountDetail(id) }
                Divider()
                Text("已登录 \(model.displayedIDs.count) 个账号，当前使用的账号始终排在最前。")
                    .font(.caption).foregroundStyle(.secondary)
                if model.displayedIDs.isEmpty {
                    Text("请在原工具登录账号，授权文件更新后会自动显示。")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if model.catalog.currentID == nil {
                    Text("尚未识别到当前订阅账号，请检查 Codex 认证路径。")
                        .font(.caption).foregroundStyle(.orange)
                }
                Picker("刷新间隔", selection: $model.settings.interval) {
                    Text("5 秒").tag(5.0)
                    Text("10 秒").tag(10.0)
                    Text("30 秒").tag(30.0)
                }.onChange(of: model.settings.interval) { _ in model.saveSettings() }
                Toggle("窗口置顶", isOn: $model.settings.alwaysOnTop)
                    .onChange(of: model.settings.alwaysOnTop) { _ in model.saveSettings(); windowSettingsChanged() }
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("背景透明度")
                        Spacer()
                        Text("\(Int(((1 - model.settings.effectiveBackgroundOpacity) * 100).rounded()))%")
                            .monospacedDigit().foregroundStyle(.secondary)
                    }
                    Slider(value: Binding(get: {
                        1 - model.settings.effectiveBackgroundOpacity
                    }, set: { model.settings.backgroundOpacity = 1 - $0 }), in: 0.2...1, step: 0.05,
                           onEditingChanged: { editing in
                        if !editing && !model.demo { model.settings.save() }
                    })
                    .accessibilityLabel("背景透明度")
                    Text("100% 为完全透明，文字保持清晰可见。")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                DisclosureGroup("账号来源路径") {
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("多账号授权 JSON", text: $stashPath)
                        TextField("当前 Codex auth.json", text: $authPath)
                        Button("应用路径") {
                            model.settings.stashPath = stashPath
                            model.settings.authPath = authPath
                            model.saveSettings()
                        }.disabled(model.demo || stashPath.isEmpty || authPath.isEmpty)
                        Text("只读文件；不修改登录状态，不自动续期共享令牌。")
                            .font(.caption2).foregroundStyle(.secondary)
                    }.padding(.top, 8)
                }
                Text("百分比表示剩余额度。客户端定时查询，服务端数据可能延迟更新。")
                    .font(.caption2).foregroundStyle(.secondary)
            }.padding(18)
        }
        .frame(width: 340, height: 540)
        .onAppear { stashPath = model.settings.stashPath; authPath = model.settings.authPath }
    }

    private func accountDetail(_ id: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                TextField("账号别名", text: Binding(get: { model.label(id) }, set: { value in
                    model.settings.aliases[id] = String(value.prefix(24))
                    if !model.demo { model.settings.save() }
                })).textFieldStyle(.roundedBorder).font(.headline)
                    .help("编辑账号显示名称，自动保存")
                if model.catalog.currentID == id { Text("当前").font(.caption2).foregroundStyle(.mint) }
                if let plan = model.snapshots[id]?.plan ?? model.account(id)?.plan {
                    Text(plan.uppercased()).font(.caption2).foregroundStyle(.secondary)
                }
            }
            if model.account(id) == nil { Text("账号已移除，等待更新列表").font(.caption).foregroundStyle(.orange) }
            if let error = model.errors[id] {
                Text(error.localizedDescription).font(.caption).foregroundStyle(.orange)
            }
            if let snapshot = model.snapshots[id] {
                if model.detailsVisible {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        VStack(alignment: .leading, spacing: 7) {
                            windowDetail("5 小时", window: snapshot.fiveHour, now: context.date)
                            windowDetail("周额度", window: snapshot.weekly, now: context.date)
                            Text("\(model.errors[id] == nil ? "更新" : "旧数据")于 \(snapshot.fetchedAt.formatted(date: .omitted, time: .standard))")
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
            } else if model.errors[id] == nil {
                Text("正在读取额度…").font(.caption).foregroundStyle(.secondary)
            }
        }.padding(12).background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 12))
    }

    private func windowDetail(_ title: String, window: QuotaWindow?, now: Date) -> some View {
        HStack {
            Text(title).font(.caption)
            Spacer()
            Text(window.map { "剩余 \($0.remainingPercent)%" } ?? "不可用").font(.caption.monospacedDigit())
            if let reset = window?.resetsAt {
                Text(countdown(reset, now: now)).font(.caption2).foregroundStyle(.secondary)
                    .help(reset.formatted(date: .abbreviated, time: .standard))
            }
        }
    }

    private func countdown(_ date: Date, now: Date) -> String {
        let seconds = max(0, Int(date.timeIntervalSince(now)))
        if seconds == 0 { return "等待重置" }
        if seconds >= 86_400 { return "\(seconds / 86_400)天 \(seconds % 86_400 / 3600)时后" }
        return "\(seconds / 3600)时 \(seconds % 3600 / 60)分后"
    }
}
