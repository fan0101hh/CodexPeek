import Foundation
import CodexPeekCore

final class RefreshPolicyTests: CheckSuite {
    let now = Date(timeIntervalSince1970: 1000)

    func testSingleFlightAndRejectsStaleOrDuplicateResponses() throws {
        var policy = RefreshPolicy(revision: "one")
        let ticket = try requireValue(policy.begin(at: now))
        expectNil(policy.begin(at: now, force: true))
        expectFalse(policy.finish(ticket: ticket, revision: "old", error: nil, at: now, interval: 5))
        expectTrue(policy.finish(ticket: ticket, revision: "one", error: nil, at: now, interval: 5))
        expectFalse(policy.finish(ticket: ticket, revision: "one", error: .network, at: now, interval: 5))
        expectNil(policy.begin(at: now.addingTimeInterval(4)))
        expectNotNil(policy.begin(at: now.addingTimeInterval(5)))
    }

    func testBackoffAndServerLimitCannotBeBypassedWithForce() throws {
        var policy = RefreshPolicy(revision: "one")
        let first = try requireValue(policy.begin(at: now))
        policy.finish(ticket: first, revision: "one", error: .network, at: now, interval: 5)
        expectEqual(policy.nextDue, now.addingTimeInterval(10))
        let second = try requireValue(policy.begin(at: now.addingTimeInterval(10)))
        policy.finish(ticket: second, revision: "one", error: .rateLimited(600), at: now.addingTimeInterval(10), interval: 5)
        expectNil(policy.begin(at: now.addingTimeInterval(100), force: true))
        expectNotNil(policy.begin(at: now.addingTimeInterval(610)))
    }

    func testCancellationAndCredentialReplacementInvalidateTickets() throws {
        var policy = RefreshPolicy(revision: "one")
        let first = try requireValue(policy.begin(at: now))
        policy.cancel()
        expectFalse(policy.finish(ticket: first, revision: "one", error: nil, at: now, interval: 5))
        policy = RefreshPolicy(revision: "two")
        expectFalse(policy.finish(ticket: first, revision: "one", error: nil, at: now, interval: 5))
    }

    func testSelectionDeduplicatesAndRetainsUnavailablePins() {
        var settings = PeekSettings()
        settings.pinnedIDs = ["current", "fixed", "third"]
        let catalog = AccountCatalog(currentID: "current")
        expectEqual(settings.selectedIDs(in: catalog), ["current", "fixed"])
        settings.followCurrent = false
        settings.pinnedIDs = ["removed", "fixed", "third"]
        expectEqual(settings.selectedIDs(in: catalog), ["removed", "fixed"])
        settings.interval = -1
        expectEqual(settings.refreshInterval, 5)
    }

    func testInitialSelectionPrefersValidAccountAndRespectsExplicitEmptySlot() {
        let current = Credential(account: Account(id: "current", accountID: "c", label: "current"), accessToken: "fake-c", expiresAt: nil)
        let expired = Credential(account: Account(id: "a-expired", accountID: "e", label: "expired"), accessToken: "fake-e", expiresAt: .distantPast)
        let valid = Credential(account: Account(id: "z-valid", accountID: "v", label: "valid"), accessToken: "fake-v", expiresAt: .distantFuture)
        let catalog = AccountCatalog(credentials: [expired, valid, current], currentID: "current")
        var settings = PeekSettings()
        expectTrue(settings.chooseInitialAccounts(in: catalog, now: now))
        expectEqual(settings.selectedIDs(in: catalog), ["current", "z-valid"])
        settings.pinnedIDs = [""]
        expectFalse(settings.chooseInitialAccounts(in: catalog))
        expectEqual(settings.selectedIDs(in: catalog), ["current"])
    }
}
