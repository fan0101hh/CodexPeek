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
        expectEqual(settings.windowWidth, 300)
        expectNil(settings.windowHeight)
        settings.save(to: defaults)
        let saved = try requireValue(defaults.data(forKey: "peek.settings"))
        let object = try JSONSerialization.jsonObject(with: saved) as? [String: Any]
        expectEqual(object?["backgroundOpacity"] as? Double, 0.15)
    }

    func testManualWindowSizePersistsWithoutLosingAliases() throws {
        var settings = PeekSettings()
        settings.windowWidth = 440
        settings.windowHeight = 260
        settings.aliases = ["work": "工作"]
        let restored = try JSONDecoder().decode(PeekSettings.self, from: JSONEncoder().encode(settings))
        expectEqual(restored.windowWidth, 440)
        expectEqual(restored.windowHeight, 260)
        expectEqual(restored.aliases["work"], "工作")
        settings.windowHeight = nil
        let automatic = try JSONDecoder().decode(PeekSettings.self, from: JSONEncoder().encode(settings))
        expectNil(automatic.windowHeight)
    }
}
