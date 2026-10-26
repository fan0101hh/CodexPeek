import Foundation

public struct QuotaWindow: Equatable, Sendable {
    public let usedPercent: Double
    public let durationSeconds: Int
    public let resetsAt: Date?
    public var remainingPercent: Int { Int((100 - usedPercent).rounded()) }

    public init?(usedPercent: Double, durationSeconds: Int, resetsAt: Date?) {
        guard usedPercent.isFinite, durationSeconds > 0 else { return nil }
        self.usedPercent = min(100, max(0, usedPercent))
        self.durationSeconds = durationSeconds
        self.resetsAt = resetsAt
    }
}

public struct QuotaSnapshot: Equatable, Sendable {
    public let fiveHour: QuotaWindow?
    public let weekly: QuotaWindow?
    public let fetchedAt: Date
    public let plan: String?

    public init(fiveHour: QuotaWindow?, weekly: QuotaWindow?, fetchedAt: Date = Date(), plan: String? = nil) {
        self.fiveHour = fiveHour
        self.weekly = weekly
        self.fetchedAt = fetchedAt
        self.plan = plan
    }
}

public enum QuotaError: Error, Equatable, LocalizedError, Sendable {
    case expired, unauthorized, invalidSource, invalidResponse, identityMismatch
    case rateLimited(TimeInterval?), network, server(Int)

    public var errorDescription: String? {
        switch self {
        case .expired: return "授权已过期，请在原工具重新登录"
        case .unauthorized: return "授权不可用，请在原工具重新登录"
        case .invalidSource: return "账号来源格式无法识别"
        case .invalidResponse: return "额度数据格式无法识别"
        case .identityMismatch: return "响应账号不匹配，已丢弃数据"
        case .rateLimited: return "查询频率受限，稍后自动重试"
        case .network: return "网络连接失败，稍后自动重试"
        case .server(let code): return "额度服务暂不可用（\(code)）"
        }
    }

    public var shortLabel: String {
        switch self {
        case .expired, .unauthorized: return "需重新登录"
        case .rateLimited: return "限流等待"
        case .identityMismatch: return "账号不匹配"
        case .invalidResponse: return "格式变化"
        default: return "读取失败"
        }
    }
}
