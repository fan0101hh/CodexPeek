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

    func testLoggedOutAndExpiredRecordsAreNotDisplayed() {
        let account = Account(id: "expired-current", accountID: "expired-current", label: "expired")
        let expired = Credential(account: account, accessToken: "synthetic", expiresAt: .distantPast)
        let empty = Credential(account: Account(id: "logged-out", accountID: "logged-out", label: "out"), accessToken: "", expiresAt: nil)
        var result = catalog(["valid"])
        result.credentials += [expired, empty]
        result.currentID = account.id
        expectEqual(AccountPresentation.orderedIDs(in: result), ["valid"])
    }

    func testAuthFailuresHideButNetworkAndRateLimitsRemainVisible() {
        let result = catalog(["a", "b", "c", "d"], current: "a")
        expectEqual(AccountPresentation.orderedIDs(in: result, errors: ["a": .unauthorized, "b": .expired,
                                                                          "c": .network, "d": .rateLimited(60)]), ["c", "d"])
        // New credentials clear the old error in the model; the account can then reappear first.
        expectEqual(AccountPresentation.orderedIDs(in: result, errors: ["c": .network]), ["a", "b", "c", "d"])
    }

    func testExpiryAtBoundaryAutomaticallyRemovesAccount() {
        let now = Date(timeIntervalSince1970: 1000)
        let credential = Credential(account: Account(id: "a", accountID: "a", label: "a"), accessToken: "synthetic",
                                    expiresAt: now.addingTimeInterval(1))
        let result = AccountCatalog(credentials: [credential], currentID: "a")
        expectEqual(AccountPresentation.orderedIDs(in: result, now: now), ["a"])
        expectEqual(AccountPresentation.orderedIDs(in: result, now: now.addingTimeInterval(1)), [])
    }
}
