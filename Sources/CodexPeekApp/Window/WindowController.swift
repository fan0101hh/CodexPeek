import AppKit
import CodexPeekCore
import SwiftUI
import Combine

private final class FloatingPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

private final class TransparentHostingView<Content: View>: NSHostingView<Content> {
    override var isOpaque: Bool { false }
}

@MainActor
final class PeekWindowController: NSObject, NSWindowDelegate, NSPopoverDelegate {
    private let model: PeekModel
    let panel: NSPanel
    private let popover = NSPopover()
    private var status: NSStatusItem!
    private var catalogObserver: AnyCancellable?

    init(model: PeekModel) {
        self.model = model
        panel = FloatingPanel(contentRect: NSRect(x: 0, y: 0, width: CGFloat(CapsuleLayout.width), height: model.capsuleHeight),
                        styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        super.init()
        panel.title = "CodexPeek"
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.delegate = self
        let content = TransparentHostingView(rootView: CapsuleView(model: model) { [weak self] in self?.showDetails() })
        content.wantsLayer = true
        content.layer?.backgroundColor = NSColor.clear.cgColor
        panel.contentView = content
        popover.behavior = .transient
        popover.delegate = self
        popover.contentViewController = NSHostingController(rootView: DetailView(model: model) { [weak self] in self?.applySettings() })
        status = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        status.button?.image = NSImage(systemSymbolName: "gauge.with.dots.needle.50percent", accessibilityDescription: "CodexPeek")
        status.button?.toolTip = "CodexPeek · 订阅剩余额度"
        let menu = NSMenu()
        addItem("显示／隐藏悬浮窗", action: #selector(toggleWindow), to: menu)
        addItem("账号与设置…", action: #selector(showDetails), to: menu)
        addItem("刷新额度", action: #selector(refresh), to: menu)
        menu.addItem(.separator())
        addItem("退出 CodexPeek", action: #selector(quit), to: menu, key: "q")
        status.menu = menu
        applySettings()
        restorePosition()
        catalogObserver = model.$catalog
            .map { AccountPresentation.orderedIDs(in: $0).count }
            .removeDuplicates()
            .sink { [weak self] count in self?.resize(accountCount: count) }
        panel.orderFrontRegardless()
        NotificationCenter.default.addObserver(self, selector: #selector(screenChanged), name: NSApplication.didChangeScreenParametersNotification, object: nil)
    }

    func applySettings() { panel.level = model.settings.alwaysOnTop ? .floating : .normal }

    @objc func showDetails() {
        if !panel.isVisible { panel.orderFrontRegardless() }
        guard let view = panel.contentView else { return }
        if popover.isShown { popover.close(); return }
        popover.show(relativeTo: view.bounds, of: view, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }

    func windowDidMove(_ notification: Notification) {
        guard !model.demo else { return }
        UserDefaults.standard.set([panel.frame.origin.x, panel.frame.origin.y], forKey: "peek.windowOrigin")
    }

    func windowDidChangeScreen(_ notification: Notification) {
        resize(accountCount: model.displayedIDs.count)
    }

    func popoverWillShow(_ notification: Notification) { model.detailsVisible = true }
    func popoverDidClose(_ notification: Notification) { model.detailsVisible = false }

    @objc private func toggleWindow() {
        if panel.isVisible { popover.close(); panel.orderOut(nil) } else { panel.orderFrontRegardless() }
    }
    @objc private func refresh() { model.refresh() }
    @objc private func quit() { NSApplication.shared.terminate(nil) }
    @objc private func screenChanged() { resize(accountCount: model.displayedIDs.count) }

    private func resize(accountCount: Int) {
        let screen = panel.screen ?? NSScreen.main
        model.availableHeight = max(64, Double(screen?.visibleFrame.height ?? 640) - 16)
        let height = CGFloat(CapsuleLayout.height(accountCount: accountCount, availableHeight: model.availableHeight))
        if panel.frame.height != height {
            var frame = panel.frame
            frame.origin.y = frame.maxY - height
            frame.size.height = height
            panel.setFrame(frame, display: true)
        }
        constrainToScreen()
    }

    private func addItem(_ title: String, action: Selector, to menu: NSMenu, key: String = "") {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        menu.addItem(item)
    }

    private func restorePosition() {
        if !model.demo, let point = UserDefaults.standard.array(forKey: "peek.windowOrigin") as? [Double], point.count == 2,
           point.allSatisfy(\.isFinite) {
            panel.setFrameOrigin(NSPoint(x: point[0], y: point[1]))
        } else if let screen = NSScreen.main {
            panel.setFrameOrigin(NSPoint(x: screen.visibleFrame.maxX - 236, y: screen.visibleFrame.maxY - 90))
        }
        constrainToScreen()
    }

    private func constrainToScreen() {
        let screen = NSScreen.screens.first { $0.visibleFrame.intersects(panel.frame) } ?? NSScreen.main
        guard let visible = screen?.visibleFrame else { return }
        let x = min(max(panel.frame.minX, visible.minX), visible.maxX - panel.frame.width)
        let y = min(max(panel.frame.minY, visible.minY), visible.maxY - panel.frame.height)
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var model: PeekModel?
    private var controller: PeekWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let model = PeekModel(demo: CommandLine.arguments.contains("--demo"))
        self.model = model
        controller = PeekWindowController(model: model)
    }

    func applicationWillTerminate(_ notification: Notification) { model?.stop() }
}
