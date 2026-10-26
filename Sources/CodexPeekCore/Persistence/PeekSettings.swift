import Foundation

public struct PeekSettings: Codable, Equatable, Sendable {
    public var followCurrent = true
    public var pinnedIDs: [String] = []
    public var aliases: [String: String] = [:]
    public var interval: TimeInterval = 5
    public var alwaysOnTop = true
    public var stashPath = "~/.cc-switch/codex-login-stash.json"
    public var authPath = "~/.codex/auth.json"

    public init() {}

    @discardableResult
    public mutating func chooseInitialAccounts(in catalog: AccountCatalog, now: Date = Date()) -> Bool {
        guard pinnedIDs.isEmpty, !catalog.credentials.isEmpty else { return false }
        let candidates = catalog.credentials.filter { $0.account.id != catalog.currentID }.sorted {
            let leftExpired = $0.isExpired(at: now)
            let rightExpired = $1.isExpired(at: now)
            if leftExpired != rightExpired { return !leftExpired }
            return $0.account.id < $1.account.id
        }
        pinnedIDs = Array(candidates.prefix(catalog.currentID == nil ? 2 : 1).map(\.account.id))
        // Explicit empty slot avoids repeatedly initializing a single-current-account catalog.
        if pinnedIDs.isEmpty { pinnedIDs = [""] }
        return true
    }

    public func selectedIDs(in catalog: AccountCatalog) -> [String] {
        var result: [String] = []
        if followCurrent, let id = catalog.currentID { result.append(id) }
        for id in pinnedIDs where !id.isEmpty && !result.contains(id) {
            if result.count == 2 { break }
            result.append(id)
        }
        return Array(result.prefix(2))
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
