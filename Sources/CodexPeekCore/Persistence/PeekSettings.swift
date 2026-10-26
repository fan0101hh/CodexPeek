import Foundation

public struct PeekSettings: Codable, Equatable, Sendable {
    // Legacy selection values are decoded for compatibility, but no longer filter display.
    public var followCurrent = true
    public var pinnedIDs: [String] = []
    public var aliases: [String: String] = [:]
    public var interval: TimeInterval = 5
    public var alwaysOnTop = true
    public var backgroundOpacity: Double = 0.15
    public var windowWidth: Double = CapsuleLayout.width
    public var windowHeight: Double?
    public var stashPath = "~/.cc-switch/codex-login-stash.json"
    public var authPath = "~/.codex/auth.json"

    public init() {}

    private enum CodingKeys: String, CodingKey {
        case followCurrent, pinnedIDs, aliases, interval, alwaysOnTop, backgroundOpacity, windowWidth, windowHeight, stashPath, authPath
    }

    public init(from decoder: Decoder) throws {
        self.init()
        let values = try decoder.container(keyedBy: CodingKeys.self)
        followCurrent = try values.decodeIfPresent(Bool.self, forKey: .followCurrent) ?? followCurrent
        pinnedIDs = try values.decodeIfPresent([String].self, forKey: .pinnedIDs) ?? pinnedIDs
        aliases = try values.decodeIfPresent([String: String].self, forKey: .aliases) ?? aliases
        interval = try values.decodeIfPresent(Double.self, forKey: .interval) ?? interval
        alwaysOnTop = try values.decodeIfPresent(Bool.self, forKey: .alwaysOnTop) ?? alwaysOnTop
        backgroundOpacity = try values.decodeIfPresent(Double.self, forKey: .backgroundOpacity) ?? backgroundOpacity
        windowWidth = try values.decodeIfPresent(Double.self, forKey: .windowWidth) ?? windowWidth
        windowHeight = try values.decodeIfPresent(Double.self, forKey: .windowHeight)
        stashPath = try values.decodeIfPresent(String.self, forKey: .stashPath) ?? stashPath
        authPath = try values.decodeIfPresent(String.self, forKey: .authPath) ?? authPath
    }

    public var effectiveBackgroundOpacity: Double {
        backgroundOpacity.isFinite ? min(0.8, max(0, backgroundOpacity)) : 0.15
    }

    public func displayedIDs(in catalog: AccountCatalog) -> [String] {
        AccountPresentation.orderedIDs(in: catalog)
    }

    public var refreshInterval: TimeInterval { [5.0, 10, 30].contains(interval) ? interval : 5 }

    public func label(for account: Account) -> String {
        let name = aliases[account.id]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return name.isEmpty ? account.label : String(name.prefix(24))
    }

    public static func read(from defaults: UserDefaults = .standard) -> PeekSettings {
        guard let data = defaults.data(forKey: "peek.settings"),
              let value = try? JSONDecoder().decode(Self.self, from: data) else { return Self() }
        return value
    }

    public func save(to defaults: UserDefaults = .standard) {
        if let data = try? JSONEncoder().encode(self) { defaults.set(data, forKey: "peek.settings") }
    }
}
