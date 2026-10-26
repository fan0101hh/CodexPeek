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

}
