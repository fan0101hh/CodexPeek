import CodexPeekCore
import SwiftUI

struct CapsuleView: View {
    @ObservedObject var model: PeekModel
    let showDetails: () -> Void
    let resizeWindow: (CGSize, Bool) -> Void
    @State private var hovering = false

    var body: some View {
        Group {
            if model.displayedIDs.isEmpty {
                Button(action: showDetails) {
                    VStack(spacing: 6) {
                        Image(systemName: "person.crop.circle.badge.plus").font(.system(size: 18))
                        Text("暂无已登录账号").font(.system(size: 12, weight: .medium))
                    }.foregroundStyle(.white.opacity(0.75)).frame(maxWidth: .infinity, maxHeight: .infinity)
                }.buttonStyle(.plain)
            } else if CapsuleLayout.naturalHeight(accountCount: model.displayedIDs.count) > Double(model.capsuleHeight) {
                ScrollViewReader { proxy in
                    ScrollView(.vertical) { rows }
                        .onChange(of: model.catalog.currentID) { _ in
                            if let first = model.displayedIDs.first { proxy.scrollTo(first, anchor: .top) }
                        }
                }
            } else {
                VStack(spacing: 0) { rows; Spacer(minLength: 0) }
            }
        }
        .padding(14)
        .frame(width: model.capsuleWidth, height: model.capsuleHeight)
        .background(Color.black.opacity(model.settings.effectiveBackgroundOpacity),
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(.white.opacity(hovering ? 0.24 : 0.1), lineWidth: 0.6))
        .overlay(alignment: .top) {
            WindowDragHandle().frame(height: 11).padding(.horizontal, 20)
                .help("按住顶部短线移动窗口").accessibilityLabel("拖动悬浮窗")
        }
        .overlay(alignment: .bottomTrailing) {
            WindowResizeHandle(resize: resizeWindow).frame(width: 17, height: 17).padding(3)
                .help("拖动右下角调整宽度与高度，尺寸自动保存")
                .accessibilityLabel("调整窗口尺寸")
        }
        .onHover { hovering = $0 }
        .preferredColorScheme(.dark)
        .accessibilityLabel("CodexPeek，显示剩余额度")
    }

    private var rows: some View {
        VStack(spacing: 8) {
            ForEach(model.displayedIDs, id: \.self) { id in
                Button(action: showDetails) { accountCard(id) }
                    .buttonStyle(.plain).help(model.tooltip(id))
            }
        }
    }

    private func accountCard(_ id: String) -> some View {
        let current = model.catalog.currentID == id
        let stale = model.errors[id] != nil
        return VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 6) {
                Circle().fill(current ? Color.mint : Color.white.opacity(0.3)).frame(width: 5, height: 5)
                Text(model.label(id)).font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.95)).lineLimit(1).truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if current {
                    Text("当前").font(.system(size: 9, weight: .medium)).foregroundStyle(.mint)
                        .padding(.horizontal, 5).padding(.vertical, 2)
                        .background(.mint.opacity(0.1), in: Capsule())
                }
                if stale { Image(systemName: "exclamationmark.circle").font(.system(size: 10)).foregroundStyle(.orange) }
            }.frame(height: 14)
            VStack(spacing: 5) {
                quotaBar("5h", model.snapshots[id]?.fiveHour, tint: .mint, stale: stale)
                quotaBar("周", model.snapshots[id]?.weekly, tint: Color(red: 0.52, green: 0.68, blue: 1), stale: stale)
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 8)
        .frame(height: 72)
        .background(current ? Color.mint.opacity(0.055) : Color.white.opacity(0.025),
                    in: RoundedRectangle(cornerRadius: 11))
        .overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(current ? .mint.opacity(0.16) : .white.opacity(0.055), lineWidth: 0.5))
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private func quotaBar(_ title: String, _ window: QuotaWindow?, tint: Color, stale: Bool) -> some View {
        let remaining = window?.remainingPercent
        let color: Color = stale ? .gray : (remaining.map { $0 < 10 ? .red : ($0 < 20 ? .orange : tint) } ?? .gray)
        return HStack(spacing: 8) {
            Text(title).font(.system(size: 10, weight: .medium)).foregroundStyle(.white.opacity(0.55))
                .frame(width: 17, alignment: .leading)
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.09))
                    Capsule().fill(color).frame(width: geometry.size.width * CGFloat(remaining ?? 0) / 100)
                }
            }.frame(height: 4)
            Text(remaining.map { "\($0)%" } ?? "—")
                .font(.system(size: 11, weight: .semibold, design: .rounded)).monospacedDigit()
                .foregroundStyle(stale ? .gray : .white.opacity(0.92))
                .frame(width: 34, alignment: .trailing)
        }
        .frame(height: 12)
        .accessibilityLabel("\(title == "5h" ? "5 小时" : "周额度")，\(remaining.map { "剩余 \($0)%" } ?? "暂不可用")")
    }
}
