import Foundation
import CodexPeekCore

final class SettingsTests: CheckSuite {
    func testLegacyPreferencesKeepAliasesAndReceiveTransparentDefault() throws {
        let suite = "CodexPeek-check-" + UUID().uuidString
        let defaults = try requireValue(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let legacy = Data(#"{"followCurrent":false,"pinnedIDs":["work"],"aliases":{"work":"工作"},"interval":10,"alwaysOnTop":false,"stashPath":"~/custom-stash.json","authPath":"~/custom-auth.json"}"#.utf8)
        defaults.set(legacy, forKey: "peek.settings")
        let settings = PeekSettings.read(from: defaults)
        expectEqual(settings.aliases["work"], "工作")
        expectEqual(settings.pinnedIDs, ["work"])
        expectFalse(settings.followCurrent)
        expectEqual(settings.interval, 10)
        expectFalse(settings.alwaysOnTop)
        expectEqual(settings.stashPath, "~/custom-stash.json")
        settings.save(to: defaults)
        let saved = try requireValue(defaults.data(forKey: "peek.settings"))
        let object = try JSONSerialization.jsonObject(with: saved) as? [String: Any]
        expectEqual(object?["backgroundOpacity"] as? Double, 0.15)
    }
}
