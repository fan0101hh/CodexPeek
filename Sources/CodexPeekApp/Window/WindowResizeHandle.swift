import AppKit
import SwiftUI

struct WindowResizeHandle: NSViewRepresentable {
    let resize: (CGSize, Bool) -> Void
    func makeNSView(context: Context) -> ResizeHandleView {
        let view = ResizeHandleView()
        view.resize = resize
        return view
    }
    func updateNSView(_ nsView: ResizeHandleView, context: Context) { nsView.resize = resize }
}

final class ResizeHandleView: NSView {
    var resize: ((CGSize, Bool) -> Void)?
    private var initialFrame: CGRect?
    private var initialPoint = CGPoint.zero
    private var lastSize = CGSize.zero
    override var isOpaque: Bool { false }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func resetCursorRects() { addCursorRect(bounds, cursor: .crosshair) }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.white.withAlphaComponent(0.5).setStroke()
        let path = NSBezierPath()
        path.lineWidth = 1
        for offset in [CGFloat(4), CGFloat(8)] {
            path.move(to: NSPoint(x: bounds.maxX - offset - 3, y: 3))
            path.line(to: NSPoint(x: bounds.maxX - 3, y: offset + 3))
        }
        path.stroke()
    }

    override func mouseDown(with event: NSEvent) {
        guard let window else { return }
        initialFrame = window.frame
        initialPoint = window.convertPoint(toScreen: event.locationInWindow)
        lastSize = window.frame.size
    }

    override func mouseDragged(with event: NSEvent) {
        guard let window, let initialFrame else { return }
        let point = window.convertPoint(toScreen: event.locationInWindow)
        lastSize = CGSize(width: initialFrame.width + point.x - initialPoint.x,
                          height: initialFrame.height - point.y + initialPoint.y)
        resize?(lastSize, false)
    }

    override func mouseUp(with event: NSEvent) {
        guard initialFrame != nil else { return }
        resize?(lastSize, true)
        initialFrame = nil
    }
}
