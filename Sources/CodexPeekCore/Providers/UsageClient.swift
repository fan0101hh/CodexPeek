import Foundation

public protocol UsageProviding: Sendable {
    func fetch(_ credential: Credential) async throws -> QuotaSnapshot
}

/// Internal Codex endpoint: isolated here because its schema can change.
public final class UsageClient: UsageProviding, @unchecked Sendable {
    private let session: URLSession
    private let redirectGuard = RedirectGuard()
    public static let endpoint = URL(string: "https://chatgpt.com/backend-api/wham/usage")!

    public init(configuration: URLSessionConfiguration = .ephemeral) {
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        configuration.urlCredentialStorage = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = 12
        configuration.timeoutIntervalForResource = 18
        session = URLSession(configuration: configuration, delegate: redirectGuard, delegateQueue: nil)
    }

    deinit { session.invalidateAndCancel() }

    public func fetch(_ credential: Credential) async throws -> QuotaSnapshot {
        guard !credential.isExpired() else { throw QuotaError.expired }
        var request = URLRequest(url: Self.endpoint)
        request.setValue("Bearer " + credential.accessToken, forHTTPHeaderField: "Authorization")
        request.setValue(credential.account.accountID, forHTTPHeaderField: "ChatGPT-Account-Id")
        request.setValue("CodexPeek/0.1", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw QuotaError.invalidResponse }
            switch http.statusCode {
            case 200: break
            case 401, 403: throw QuotaError.unauthorized
            case 429: throw QuotaError.rateLimited(Self.retryAfter(http.value(forHTTPHeaderField: "Retry-After")))
            default: throw QuotaError.server(http.statusCode)
            }
            guard data.count < 2_000_000 else { throw QuotaError.invalidResponse }
            return try Self.decode(data, expectedAccountID: credential.account.accountID)
        } catch is CancellationError { throw CancellationError() }
        catch let error as QuotaError { throw error }
        catch let error as URLError where error.code == .cancelled { throw CancellationError() }
        catch { throw QuotaError.network }
    }

    public static func decode(_ data: Data, expectedAccountID: String, now: Date = Date()) throws -> QuotaSnapshot {
        let response: UsageResponse
        do { response = try JSONDecoder().decode(UsageResponse.self, from: data) }
        catch { throw QuotaError.invalidResponse }
        if let accountID = response.accountID, accountID != expectedAccountID { throw QuotaError.identityMismatch }
        guard response.rateLimit != nil else { throw QuotaError.invalidResponse }
        let windows = [response.rateLimit?.primary, response.rateLimit?.secondary].compactMap { $0?.window }
        return QuotaSnapshot(fiveHour: windows.first { $0.durationSeconds == 18_000 },
                             weekly: windows.first { $0.durationSeconds == 604_800 },
                             fetchedAt: now, plan: response.plan)
    }

    public static func retryAfter(_ value: String?, now: Date = Date()) -> TimeInterval? {
        guard let value else { return nil }
        if let seconds = Double(value), seconds.isFinite { return max(0, seconds) }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss z"
        return formatter.date(from: value).map { max(0, $0.timeIntervalSince(now)) }
    }
}

private final class RedirectGuard: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}

private struct UsageResponse: Decodable {
    let accountID: String?
    let plan: String?
    let rateLimit: Limit?
    enum CodingKeys: String, CodingKey {
        case accountID = "account_id", plan = "plan_type", rateLimit = "rate_limit"
    }
    struct Limit: Decodable {
        let primary: Window?
        let secondary: Window?
        enum CodingKeys: String, CodingKey { case primary = "primary_window", secondary = "secondary_window" }
    }
    struct Window: Decodable {
        let used: Double?
        let seconds: Int?
        let reset: Double?
        enum CodingKeys: String, CodingKey {
            case used = "used_percent", seconds = "limit_window_seconds", reset = "reset_at"
        }
        var window: QuotaWindow? {
            guard let used, let seconds else { return nil }
            return QuotaWindow(usedPercent: used, durationSeconds: seconds,
                               resetsAt: reset.flatMap { $0 > 0 ? Date(timeIntervalSince1970: $0) : nil })
        }
    }
}
