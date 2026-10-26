import Foundation
import CodexPeekCore

final class AccountFileStoreTests: CheckSuite {
    private var directory: URL!
    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { try FileManager.default.removeItem(at: directory) }

    func testDeduplicatesAndUsesNewestCredentialWithoutWritingSources() throws {
        let old = record(expiry: 100)
        let current = record(expiry: 200)
        let stash = try write(["logins": ["entry-a": old, "duplicate": old]], name: "stash.json")
        let auth = try write(current, name: "current.json")
        let original = try Data(contentsOf: stash)
        let catalog = AccountFileStore(stashURL: stash, authURL: auth).load()
        expectEqual(catalog.credentials.count, 1)
        expectEqual(catalog.currentID, catalog.credentials.first?.account.id)
        expectEqual(catalog.credentials.first?.expiresAt, Date(timeIntervalSince1970: 200))
        expectEqual(catalog.credentials.first?.account.label, "sample")
        expectTrue(catalog.credentials[0].isExpired(at: Date(timeIntervalSince1970: 201)))
        expectEqual(try Data(contentsOf: stash), original)
        expectEqual(String(describing: catalog.credentials[0]), "Credential(<redacted>)")
    }

    func testDifferentSubjectsInSameWorkspaceAreSeparateAccounts() throws {
        let stash = try write(["logins": ["one": record(subject: "one"), "two": record(subject: "two")]], name: "stash.json")
        let catalog = AccountFileStore(stashURL: stash, authURL: directory.appendingPathComponent("missing")).load()
        expectEqual(catalog.credentials.count, 2)
        expectNil(catalog.currentID)
    }

    func testSkipsMalformedRecordAndReadsAtomicReplacement() throws {
        let stash = try write(["logins": ["one": record(), "bad": ["tokens": [:]]]], name: "stash.json")
        let auth = directory.appendingPathComponent("missing")
        let store = AccountFileStore(stashURL: stash, authURL: auth)
        expectEqual(store.load().credentials.count, 1)
        expectEqual(store.load().notices.count, 1)
        let data = try JSONSerialization.data(withJSONObject: ["logins": ["two": record(subject: "other")]])
        try data.write(to: stash, options: .atomic)
        expectTrue(store.load().credentials[0].account.id.hasSuffix(":other"))
    }

    func testMalformedSourcesProduceNoticeWithoutLeakingContents() throws {
        let stash = directory.appendingPathComponent("stash.json")
        try Data("not-json-secret".utf8).write(to: stash)
        let result = AccountFileStore(stashURL: stash, authURL: directory.appendingPathComponent("missing")).load()
        expectTrue(result.credentials.isEmpty)
        expectFalse(result.notices.joined().contains("not-json-secret"))
    }

    private func record(subject: String = "subject", expiry: Int = 1000) -> [String: Any] {
        let claims: [String: Any] = ["sub": subject, "exp": expiry, "email": "sample@example.invalid"]
        let payload = try! JSONSerialization.data(withJSONObject: claims).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
        let jwt = "header.\(payload).signature"
        return ["tokens": ["access_token": jwt, "id_token": jwt, "account_id": "test-workspace", "refresh_token": "never-use"]]
    }

    private func write(_ value: [String: Any], name: String) throws -> URL {
        let url = directory.appendingPathComponent(name)
        try JSONSerialization.data(withJSONObject: value).write(to: url)
        return url
    }
}
