import AppKit

enum MenuBarIcon {
    static func make() -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
            for (y, filled) in [(CGFloat(10.5), CGFloat(10)), (CGFloat(4.5), CGFloat(7))] {
                NSColor.black.withAlphaComponent(0.25).setFill()
                NSBezierPath(roundedRect: NSRect(x: 2, y: y, width: 14, height: 3), xRadius: 1.5, yRadius: 1.5).fill()
                NSColor.black.setFill()
                NSBezierPath(roundedRect: NSRect(x: 2, y: y, width: filled, height: 3), xRadius: 1.5, yRadius: 1.5).fill()
            }
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "CodexPeek"
        return image
    }
}
