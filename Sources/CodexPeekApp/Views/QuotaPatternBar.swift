import SwiftUI

/// Solid remaining portion with a dotted used portion, drawn only when the view changes.
struct QuotaPatternBar: View {
    let remaining: Int?
    let stale: Bool

    var body: some View {
        Canvas { context, size in
            let ink = Color.white.opacity(stale ? 0.35 : 0.9)
            let fraction = CGFloat(min(100, max(0, remaining ?? 0))) / 100
            let filledWidth = size.width * fraction
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.white.opacity(0.025)))
            // Missing data gets only an outline, never a fabricated full-used pattern.
            guard remaining != nil else {
                context.stroke(Path(CGRect(origin: .zero, size: size)), with: .color(.white.opacity(0.18)), lineWidth: 0.5)
                return
            }
            var dots = Path()
            for (row, y) in stride(from: CGFloat(1), to: size.height, by: 3).enumerated() {
                let offset: CGFloat = row.isMultiple(of: 2) ? 0 : 1.5
                for x in stride(from: offset, to: size.width, by: 3) where x >= filledWidth {
                    dots.addRect(CGRect(x: x, y: y, width: 1, height: 1.5))
                }
            }
            context.fill(dots, with: .color(ink.opacity(0.7)))
            context.fill(Path(CGRect(x: 0, y: 0, width: filledWidth, height: size.height)), with: .color(ink))
            var seams = Path()
            for x in stride(from: CGFloat(8), to: filledWidth, by: 8) {
                seams.move(to: CGPoint(x: x, y: 0))
                seams.addLine(to: CGPoint(x: x, y: size.height))
            }
            context.stroke(seams, with: .color(.black.opacity(0.09)), lineWidth: 0.5)
        }
        .frame(minWidth: 36, idealWidth: 120, maxWidth: .infinity, minHeight: 12, maxHeight: 12)
        .clipped()
        .accessibilityHidden(true)
    }
}
