import Foundation

public struct AccountFileStore {
    public let stashURL: URL
    public let authURL: URL

    public init(stashURL: URL, authURL: URL) {
        self.stashURL = stashURL
        self.authURL = authURL
    }

    public func load() -> AccountCatalog {
        var result = AccountCatalog()
        var records: [String: Credential] = [:]
        if FileManager.default.fileExists(atPath: stashURL.path) {
            do {
                guard let root = try object(at: stashURL), let logins = root["logins"] as? [String: Any] else {
                    throw QuotaError.invalidSource
                }
                for value in logins.values {
                    if let record = value as? [String: Any], let credential = Self.parse(record) {
                        merge(credential, into: &records)
                    } else {
                        result.notices.append("部分账号记录无法识别，已跳过")
                    }
                }
            } catch {
                result.notices.append("账号来源文件无法读取，请检查路径与格式")
            }
        } else {
            result.notices.append("未找到账号来源文件，可在设置中修改路径")
        }

        if FileManager.default.fileExists(atPath: authURL.path) {
            do {
                if let root = try object(at: authURL), let credential = Self.parse(root) {
                    result.currentID = credential.account.id
                    merge(credential, into: &records)
                } else {
                    result.notices.append("当前 Codex 认证不是可识别的订阅账号")
                }
            } catch {
                result.notices.append("当前 Codex 认证读取失败，等待文件更新")
            }
        }
        result.credentials = records.values.sorted { $0.account.id < $1.account.id }
        return result
    }

    private func object(at url: URL) throws -> [String: Any]? {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        guard ((attributes[.size] as? NSNumber)?.intValue ?? 0) < 8_000_000 else {
            throw QuotaError.invalidSource
        }
        return try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any]
    }

    private func merge(_ credential: Credential, into records: inout [String: Credential]) {
        let id = credential.account.id
        if let existing = records[id],
           (existing.expiresAt ?? .distantPast) > (credential.expiresAt ?? .distantPast) { return }
        records[id] = credential
    }

    private static func parse(_ record: [String: Any]) -> Credential? {
        guard let tokens = record["tokens"] as? [String: Any],
              let accessToken = tokens["access_token"] as? String, !accessToken.isEmpty else { return nil }
        let access = claims(accessToken)
        let identity = claims(tokens["id_token"] as? String ?? "")
        let auth = access["https://api.openai.com/auth"] as? [String: Any] ?? [:]
        guard let accountID = tokens["account_id"] as? String ?? auth["chatgpt_account_id"] as? String,
              !accountID.isEmpty else { return nil }
        let subject = access["sub"] as? String ?? identity["sub"] as? String ?? accountID
        let profile = access["https://api.openai.com/profile"] as? [String: Any] ?? [:]
        let email = identity["email"] as? String ?? profile["email"] as? String
        let label = email?.components(separatedBy: "@").first ?? "账号"
        let account = Account(id: accountID + ":" + subject, accountID: accountID,
                              label: label, plan: auth["chatgpt_plan_type"] as? String)
        let expiry = (access["exp"] as? NSNumber).map { Date(timeIntervalSince1970: $0.doubleValue) }
        return Credential(account: account, accessToken: accessToken, expiresAt: expiry)
    }

    /// JWT decoding is for display and expiry only; server validates authentication.
    private static func claims(_ token: String) -> [String: Any] {
        let parts = token.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 3 else { return [:] }
        var encoded = String(parts[1]).replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        encoded += String(repeating: "=", count: (4 - encoded.count % 4) % 4)
        guard let data = Data(base64Encoded: encoded),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [:] }
        return object
    }
}
