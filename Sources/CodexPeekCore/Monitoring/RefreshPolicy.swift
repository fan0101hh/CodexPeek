import Foundation

/// Value-type scheduler, driven only from the app's main actor.
public struct RefreshPolicy {
    public private(set) var revision: String
    public private(set) var nextDue: Date = .distantPast
    public private(set) var inFlight: UUID?
    public private(set) var failures = 0
    private var limitedUntil: Date = .distantPast

    public init(revision: String) { self.revision = revision }

    public mutating func begin(at now: Date, force: Bool = false) -> UUID? {
        guard inFlight == nil, now >= limitedUntil, force || now >= nextDue else { return nil }
        let ticket = UUID()
        inFlight = ticket
        return ticket
    }

    @discardableResult
    public mutating func finish(ticket: UUID, revision: String, error: QuotaError?,
                                at now: Date, interval: TimeInterval) -> Bool {
        guard inFlight == ticket, self.revision == revision else { return false }
        inFlight = nil
        if let error {
            failures = min(failures + 1, 10)
            var delay = min(300, interval * pow(2, Double(failures)))
            if case .rateLimited(let retry) = error {
                delay = max(delay, retry ?? 60)
                limitedUntil = now.addingTimeInterval(delay)
            }
            if error == .expired || error == .unauthorized { delay = max(delay, 60) }
            nextDue = now.addingTimeInterval(delay)
        } else {
            failures = 0
            nextDue = now.addingTimeInterval(interval)
        }
        return true
    }

    public mutating func cancel() { inFlight = nil }
}
