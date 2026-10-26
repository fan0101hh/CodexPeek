import Foundation

public enum AccountPresentation {
    public static func orderedIDs(in catalog: AccountCatalog, errors: [String: QuotaError] = [:], now: Date = Date()) -> [String] {
        let ids = Set(catalog.credentials.filter {
            !$0.accessToken.isEmpty && !$0.isExpired(at: now)
                && errors[$0.account.id] != .unauthorized && errors[$0.account.id] != .expired
        }.map(\.account.id)).sorted()
        guard let current = catalog.currentID, ids.contains(current) else { return ids }
        return [current] + ids.filter { $0 != current }
    }
}

public enum CapsuleLayout {
    public static let width: Double = 300
    public static let minimumWidth: Double = 260
    public static let maximumWidth: Double = 720
    public static let minimumHeight: Double = 100

    public static func accountHeight(width: Double) -> Double { width >= 500 ? 76 : 108 }

    public static func naturalHeight(accountCount: Int, width: Double = CapsuleLayout.width) -> Double {
        guard accountCount > 0 else { return minimumHeight }
        return 28 + Double(accountCount) * accountHeight(width: width) + Double(accountCount - 1) * 8
    }

    public static func height(accountCount: Int, availableHeight: Double, preferredHeight: Double? = nil,
                              width: Double = CapsuleLayout.width) -> Double {
        let desired = preferredHeight.flatMap { $0.isFinite ? $0 : nil } ?? naturalHeight(accountCount: accountCount, width: width)
        return min(max(minimumHeight, desired), max(minimumHeight, availableHeight))
    }

    public static func resolvedWidth(_ preferred: Double, availableWidth: Double) -> Double {
        let desired = preferred.isFinite ? preferred : width
        return min(max(minimumWidth, desired), max(minimumWidth, min(maximumWidth, availableWidth)))
    }
}
