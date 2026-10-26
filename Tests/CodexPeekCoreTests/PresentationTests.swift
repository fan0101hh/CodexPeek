import Foundation
import CodexPeekCore

final class PresentationTests: CheckSuite {
    private func catalog(_ ids: [String], current: String? = nil) -> AccountCatalog {
        AccountCatalog(credentials: ids.map {
            Credential(account: Account(id: $0, accountID: $0, label: $0), accessToken: "synthetic", expiresAt: nil)
        }, currentID: current)
    }

    func testAllAccountsShownWithCurrentFirstDespiteLegacySettings() {
        var settings = PeekSettings()
        settings.followCurrent = false
        settings.pinnedIDs = ["removed"]
        expectEqual(settings.displayedIDs(in: catalog(["d", "b", "a", "c"], current: "c")), ["c", "a", "b", "d"])
        settings.aliases["d"] = "AAA"
        expectEqual(settings.displayedIDs(in: catalog(["d", "b", "a", "c"], current: "c")), ["c", "a", "b", "d"])
    }

    func testSwitchAndRemovalReorderWithoutGhostOrDuplicateAccounts() {
        let settings = PeekSettings()
        expectEqual(settings.displayedIDs(in: catalog(["c", "b", "a", "a"], current: "b")), ["b", "a", "c"])
        expectEqual(settings.displayedIDs(in: catalog(["c", "b", "a"], current: "a")), ["a", "b", "c"])
        expectEqual(settings.displayedIDs(in: catalog(["c", "b"], current: "a")), ["b", "c"])
    }

    func testEmptySingleAndUnidentifiedCurrent() {
        expectEqual(AccountPresentation.orderedIDs(in: catalog([], current: "missing")), [])
        expectEqual(AccountPresentation.orderedIDs(in: catalog(["a"], current: "a")), ["a"])
        expectEqual(AccountPresentation.orderedIDs(in: catalog(["b", "a"])), ["a", "b"])
    }

    func testHeightTracksRowsAndIsCappedByScreen() {
        expectEqual(CapsuleLayout.naturalHeight(accountCount: 0), 64)
        expectEqual(CapsuleLayout.naturalHeight(accountCount: 1), 44)
        expectEqual(CapsuleLayout.naturalHeight(accountCount: 2), 64)
        expectEqual(CapsuleLayout.naturalHeight(accountCount: 3), 87)
        expectEqual(CapsuleLayout.height(accountCount: 100, availableHeight: 700), 700)
        expectEqual(CapsuleLayout.height(accountCount: 1, availableHeight: 700), 44)
    }
}
