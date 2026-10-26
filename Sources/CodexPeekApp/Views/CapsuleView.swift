import CodexPeekCore
import SwiftUI

struct CapsuleView: View {
    @ObservedObject var model: PeekModel
    let showDetails: () -> Void
    @State private var hovering = false

    var body: some View {
        Group {
            if model.displayedIDs.isEmpty {
                Button(action: showDetails) {
                    Label("配置账号来源", systemImage: "plus.circle")
                        .font(.system(size: 12, weight: .medium))
                        .frame(maxWidth: .infinity, minHeight: 40)
                }.buttonStyle(.plain)
            } else {
                if CapsuleLayout.naturalHeight(accountCount: model.displayedIDs.count) > model.availableHeight {
                    ScrollViewReader { proxy in
                        ScrollView(.vertical) { rows }
                            .onChange(of: model.catalog.currentID) { _ in
                                if let first = model.displayedIDs.first { proxy.scrollTo(first, anchor: .top) }
                            }
                    }
                } else {
                    rows
                }
            }
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 11)
        .frame(width: CGFloat(CapsuleLayout.width), height: model.capsuleHeight)
        .background(Color.black.opacity(model.settings.effectiveBackgroundOpacity),
                    in: RoundedRectangle(cornerRadius: 19, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 19).strokeBorder(.white.opacity(hovering ? 0.24 : 0.12), lineWidth: 0.5))
        .onHover { hovering = $0 }
        .preferredColorScheme(.dark)
        .accessibilityLabel("CodexPeek，显示剩余额度")
    }

    private var rows: some View {
        VStack(spacing: 5) {
            ForEach(model.displayedIDs, id: \.self) { id in
                Button(action: showDetails) {
                    row(id).shadow(color: .black.opacity(0.65), radius: 1, x: 0, y: 1)
                }
                .buttonStyle(.plain)
                .help(model.tooltip(id))
            }
        }
    }

    private func row(_ id: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(model.catalog.currentID == id ? Color.mint : Color.white.opacity(0.28))
                .frame(width: 5, height: 5)
                .accessibilityLabel(model.catalog.currentID == id ? "当前账号" : "其他账号")
            Text(model.label(id))
                .font(.system(size: 11, weight: .medium))
                .lineLimit(1).frame(width: 47, alignment: .leading)
            if let error = model.errors[id], model.snapshots[id] == nil {
                Text(error.shortLabel).font(.system(size: 10)).foregroundStyle(.orange)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            } else {
                quota("5h", model.snapshots[id]?.fiveHour, stale: model.errors[id] != nil)
                quota("周", model.snapshots[id]?.weekly, stale: model.errors[id] != nil)
            }
        }
        .frame(height: 18)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private func quota(_ title: String, _ window: QuotaWindow?, stale: Bool) -> some View {
        HStack(spacing: 3) {
            Text(title).font(.system(size: 9)).foregroundStyle(.white.opacity(0.45))
            Text(window.map { "\($0.remainingPercent)%" } ?? "—")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(stale ? .gray : color(window?.remainingPercent))
        }.frame(maxWidth: .infinity, alignment: .trailing)
    }

    private func color(_ remaining: Int?) -> Color {
        guard let remaining else { return .gray }
        if remaining < 10 { return .red }
        if remaining < 20 { return .orange }
        return .white.opacity(0.9)
    }
}
