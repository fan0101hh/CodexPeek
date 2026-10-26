import Foundation
import CodexPeekCore

final class QuotaResetTextTests: CheckSuite {
    private let formatter = ISO8601DateFormatter()
    private let zone = TimeZone(secondsFromGMT: 8 * 3600)!

    func testReferenceResetLabelsUseLocalTimeAndDate() {
        let now = formatter.date(from: "2026-10-26T10:00:00Z")!
        let sameDay = formatter.date(from: "2026-10-26T11:11:00Z")!
        let nextWeek = formatter.date(from: "2026-11-02T00:00:00Z")!
        let tomorrow = formatter.date(from: "2026-10-27T01:00:00Z")!
        expectEqual(QuotaResetText.label(date: sameDay, windowSeconds: 18_000, now: now, timeZone: zone), "重置时间：19:11")
        expectEqual(QuotaResetText.label(date: nextWeek, windowSeconds: 604_800, now: now, timeZone: zone), "重置时间：11月2日")
        expectEqual(QuotaResetText.label(date: tomorrow, windowSeconds: 18_000, now: now, timeZone: zone), "重置时间：10月27日 09:00")
    }

    func testMissingPastAndCrossYearResetAreUnambiguous() {
        let now = formatter.date(from: "2026-12-31T10:00:00Z")!
        let nextYear = formatter.date(from: "2027-01-01T00:00:00Z")!
        expectEqual(QuotaResetText.label(date: nil, windowSeconds: 18_000, now: now, timeZone: zone), "重置时间：—")
        expectEqual(QuotaResetText.label(date: now, windowSeconds: 18_000, now: now, timeZone: zone), "等待重置")
        expectEqual(QuotaResetText.label(date: nextYear, windowSeconds: 604_800, now: now, timeZone: zone), "重置时间：2027年1月1日 08:00")
    }
}
