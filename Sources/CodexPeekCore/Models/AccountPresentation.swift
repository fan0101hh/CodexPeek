import Foundation

public enum AccountPresentation {
    public static func orderedIDs(in catalog: AccountCatalog) -> [String] {
        let ids = Set(catalog.credentials.map(\.account.id)).sorted()
        guard let current = catalog.currentID, ids.contains(current) else { return ids }
        return [current] + ids.filter { $0 != current }
    }
}

public enum CapsuleLayout {
    public static let width: Double = 212

    public static func naturalHeight(accountCount: Int) -> Double {
        guard accountCount > 0 else { return 64 }
        return max(44, 23 + Double(accountCount) * 18 + Double(accountCount - 1) * 5)
    }

    public static func height(accountCount: Int, availableHeight: Double) -> Double {
        min(naturalHeight(accountCount: accountCount), max(44, availableHeight))
    }
}
