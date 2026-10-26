import CodexPeekCore
import SwiftUI

struct CapsuleView: View {
    @ObservedObject var model: PeekModel
    let showDetails: () -> Void
    @State private var hovering = false

    var body: some View {
        VStack(spacing: 5) {
            if model.selectedIDs.isEmpty {
                Button(action: showDetails) {
                    Label("添加展示账号", systemImage: "plus.circle")
                        .font(.system(size: 12, weight: .medium))
                        .frame(maxWidth: .infinity, minHeight: 40)
                }.buttonStyle(.plain)
            } else {
                ForEach(model.selectedIDs, id: \.self) { id in
                    Button(action: showDetails) { row(id) }
                        .buttonStyle(.plain)
                        .help(model.tooltip(id))
                }
            }
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 11)
        .frame(width: 212, height: 64)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 19, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 19).strokeBorder(.white.opacity(hovering ? 0.24 : 0.12), lineWidth: 0.5))
        .onHover { hovering = $0 }
        .preferredColorScheme(.dark)
        .accessibilityLabel("CodexPeek，显示剩余额度")
    }

    private func row(_ id: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(model.catalog.currentID == id ? Color.mint : Color.white.opacity(0.28))
                .frame(width: 5, height: 5)
                .accessibilityLabel(model.catalog.currentID == id ? "当前账号" : "固定账号")
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
