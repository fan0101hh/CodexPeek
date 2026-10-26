import Foundation
import CodexPeekCore

final class UsageClientTests: CheckSuite {
    func testMapsByDurationInsteadOfPrimarySecondaryOrder() throws {
        let data = Data("""
        {"account_id":"test","plan_type":"pro","rate_limit":{
          "primary_window":{"used_percent":62,"limit_window_seconds":604800,"reset_at":2000000000},
          "secondary_window":{"used_percent":28,"limit_window_seconds":18000,"reset_at":1900000000}},
          "additional_rate_limits":[{"rate_limit":{"primary_window":{"used_percent":99,"limit_window_seconds":18000}}}]}
        """.utf8)
        let snapshot = try UsageClient.decode(data, expectedAccountID: "test")
        expectEqual(snapshot.fiveHour?.remainingPercent, 72)
        expectEqual(snapshot.weekly?.remainingPercent, 38)
        expectEqual(snapshot.fiveHour?.resetsAt, Date(timeIntervalSince1970: 1900000000))
        expectEqual(snapshot.plan, "pro")
    }

    func testMissingWindowsAreNotZeroAndUnknownDurationsAreIgnored() throws {
        let data = Data(#"{"rate_limit":{"primary_window":{"used_percent":25,"limit_window_seconds":900}}}"#.utf8)
        let snapshot = try UsageClient.decode(data, expectedAccountID: "test")
        expectNil(snapshot.fiveHour)
        expectNil(snapshot.weekly)
        expectFailure(try UsageClient.decode(Data("{}".utf8), expectedAccountID: "test"))
    }

    func testRejectsIdentityMismatchAndInvalidTypes() {
        expectFailure(try UsageClient.decode(Data(#"{"account_id":"other","rate_limit":{}}"#.utf8), expectedAccountID: "test")) {
            expectEqual($0 as? QuotaError, .identityMismatch)
        }
        expectFailure(try UsageClient.decode(Data(#"{"rate_limit":{"primary_window":{"used_percent":"secret"}}}"#.utf8), expectedAccountID: "test")) {
            expectEqual($0 as? QuotaError, .invalidResponse)
        }
    }

    func testClampsPercentAndRejectsNonFiniteValues() {
        expectEqual(QuotaWindow(usedPercent: 120, durationSeconds: 1, resetsAt: nil)?.remainingPercent, 0)
        expectEqual(QuotaWindow(usedPercent: -20, durationSeconds: 1, resetsAt: nil)?.remainingPercent, 100)
        expectNil(QuotaWindow(usedPercent: .nan, durationSeconds: 1, resetsAt: nil))
        expectNil(QuotaWindow(usedPercent: 0, durationSeconds: 0, resetsAt: nil))
    }

    func testRetryAfterSupportsSecondsAndHTTPDate() {
        expectEqual(UsageClient.retryAfter("120"), 120)
        expectEqual(UsageClient.retryAfter("-1"), 0)
        expectNil(UsageClient.retryAfter("nan"))
        expectEqual(UsageClient.retryAfter("Thu, 01 Jan 1970 00:02:00 GMT", now: Date(timeIntervalSince1970: 0)), 120)
    }

    func testHTTPFailuresAreSanitizedAndExpiredTokenMakesNoRequest() async {
        for (status, expected) in [(401, QuotaError.unauthorized), (403, .unauthorized), (429, .rateLimited(90)), (503, .server(503))] {
            let config = URLSessionConfiguration.ephemeral
            config.protocolClasses = [StubProtocol.self]
            StubProtocol.status = status
            let client = UsageClient(configuration: config)
            let credential = Credential(account: Account(id: "test", accountID: "test", label: "test"), accessToken: "fake", expiresAt: nil)
            do { _ = try await client.fetch(credential); failCheck("Expected HTTP failure") }
            catch { expectEqual(error as? QuotaError, expected) }
        }
        let client = UsageClient()
        do {
            _ = try await client.fetch(Credential(account: Account(id: "test", accountID: "test", label: "test"), accessToken: "fake", expiresAt: .distantPast))
            failCheck("Expired authorization must not be sent")
        } catch { expectEqual(error as? QuotaError, .expired) }
    }

    func testSuccessfulRequestUsesOnlyExpectedDestinationAndHeaders() async {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubProtocol.self]
        StubProtocol.status = 200
        let client = UsageClient(configuration: config)
        let credential = Credential(account: Account(id: "test", accountID: "test", label: "test"), accessToken: "fake", expiresAt: nil)
        do {
            let snapshot = try await client.fetch(credential)
            expectEqual(snapshot.fiveHour?.remainingPercent, 73)
            expectNil(snapshot.weekly)
            expectEqual(StubProtocol.lastRequest?.url, UsageClient.endpoint)
            expectEqual(StubProtocol.lastRequest?.httpMethod, "GET")
            expectEqual(StubProtocol.lastRequest?.value(forHTTPHeaderField: "Authorization"), "Bearer fake")
            expectEqual(StubProtocol.lastRequest?.value(forHTTPHeaderField: "ChatGPT-Account-Id"), "test")
            expectNil(StubProtocol.lastRequest?.httpBody)
        } catch { failCheck("Synthetic successful request failed") }
    }

    func testRedirectResponseIsNotAcceptedAsUsage() async {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubProtocol.self]
        StubProtocol.status = 302
        let client = UsageClient(configuration: config)
        do {
            _ = try await client.fetch(Credential(account: Account(id: "test", accountID: "test", label: "test"), accessToken: "fake", expiresAt: nil))
            failCheck("Redirect response must not be accepted")
        } catch { expectEqual(error as? QuotaError, .server(302)) }
    }
}

private final class StubProtocol: URLProtocol {
    static var status = 401
    static var lastRequest: URLRequest?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.lastRequest = request
        let response = HTTPURLResponse(url: request.url!, statusCode: Self.status, httpVersion: nil, headerFields: ["Retry-After": "90"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        let body = Self.status == 200
            ? #"{"account_id":"test","rate_limit":{"primary_window":{"used_percent":27,"limit_window_seconds":18000}}}"#
            : "private-server-response"
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
