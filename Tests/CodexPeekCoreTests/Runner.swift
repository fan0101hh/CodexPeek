import Foundation

@main
struct Runner {
    static func main() async {
        let accounts = AccountFileStoreTests()
        let usage = UsageClientTests()
        let refresh = RefreshPolicyTests()
        let checks: [(String, CheckSuite, () async throws -> Void)] = [
            ("账号去重及只读", accounts, accounts.testDeduplicatesAndUsesNewestCredentialWithoutWritingSources),
            ("同工作区不同登录者", accounts, accounts.testDifferentSubjectsInSameWorkspaceAreSeparateAccounts),
            ("坏记录与原子替换", accounts, accounts.testSkipsMalformedRecordAndReadsAtomicReplacement),
            ("来源异常脱敏", accounts, accounts.testMalformedSourcesProduceNoticeWithoutLeakingContents),
            ("按窗口时长映射", usage, usage.testMapsByDurationInsteadOfPrimarySecondaryOrder),
            ("缺失与未知窗口", usage, usage.testMissingWindowsAreNotZeroAndUnknownDurationsAreIgnored),
            ("身份及格式验证", usage, usage.testRejectsIdentityMismatchAndInvalidTypes),
            ("百分比边界", usage, usage.testClampsPercentAndRejectsNonFiniteValues),
            ("Retry-After 解析", usage, usage.testRetryAfterSupportsSecondsAndHTTPDate),
            ("HTTP 错误及过期拒发", usage, usage.testHTTPFailuresAreSanitizedAndExpiredTokenMakesNoRequest),
            ("请求目标与认证头", usage, usage.testSuccessfulRequestUsesOnlyExpectedDestinationAndHeaders),
            ("拒绝重定向响应", usage, usage.testRedirectResponseIsNotAcceptedAsUsage),
            ("单请求及旧响应隔离", refresh, refresh.testSingleFlightAndRejectsStaleOrDuplicateResponses),
            ("退避与限流保护", refresh, refresh.testBackoffAndServerLimitCannotBeBypassedWithForce),
            ("取消与凭据更换", refresh, refresh.testCancellationAndCredentialReplacementInvalidateTickets),
            ("选择去重与失效账号", refresh, refresh.testSelectionDeduplicatesAndRetainsUnavailablePins),
            ("初始优选有效账号", refresh, refresh.testInitialSelectionPrefersValidAccountAndRespectsExplicitEmptySlot)
        ]
        for (name, suite, check) in checks {
            let before = CheckReport.failures.count
            do {
                try suite.setUpWithError()
                try await check()
            } catch { failCheck("Uncaught test error: \(error)") }
            do { try suite.tearDownWithError() } catch { failCheck("Test cleanup failed") }
            print("\(before == CheckReport.failures.count ? "PASS" : "FAIL") \(name)")
        }
        for failure in CheckReport.failures { print(failure) }
        print("\(checks.count) checks, \(CheckReport.failures.count) failures")
        exit(CheckReport.failures.isEmpty ? 0 : 1)
    }
}
