import AppKit

@main
struct CodexPeekEntry {
    @MainActor
    static func main() {
        if CommandLine.arguments.contains("--diagnose") {
            Task { exit(await Diagnostics.run()) }
            dispatchMain()
        }
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let delegate = AppDelegate()
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}
