import CryptoKit
import Foundation

public struct Account: Identifiable, Equatable, Sendable {
    public let id: String
    public let accountID: String
    public let label: String
    public let plan: String?

    public init(id: String, accountID: String, label: String, plan: String? = nil) {
        self.id = id
        self.accountID = accountID
        self.label = label
        self.plan = plan
    }
}

/// Access tokens stay in memory. Never persist or log this object.
public struct Credential: Sendable, CustomStringConvertible, CustomDebugStringConvertible {
    public let account: Account
    public let accessToken: String
    public let expiresAt: Date?
    public let revision: String

    public init(account: Account, accessToken: String, expiresAt: Date?) {
        self.account = account
        self.accessToken = accessToken
        self.expiresAt = expiresAt
        self.revision = SHA256.hash(data: Data(accessToken.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    public func isExpired(at date: Date = Date()) -> Bool {
        expiresAt.map { $0 <= date } ?? false
    }

    public var description: String { "Credential(<redacted>)" }
    public var debugDescription: String { description }
}

public struct AccountCatalog: Sendable {
    public var credentials: [Credential]
    public var currentID: String?
    public var notices: [String]

    public init(credentials: [Credential] = [], currentID: String? = nil, notices: [String] = []) {
        self.credentials = credentials
        self.currentID = currentID
        self.notices = notices
    }
}
