import Foundation

// A small assertion runner so checks also work with Command Line Tools, without XCTest.
class CheckSuite {
    func setUpWithError() throws {}
    func tearDownWithError() throws {}
}

enum CheckFailure: Error { case unwrap }
enum CheckReport {
    static var failures: [String] = []
    static func fail(_ message: String, file: StaticString, line: UInt) {
        failures.append("\(file):\(line): \(message)")
    }
}

func expectEqual<T: Equatable>(_ actual: T, _ expected: T, file: StaticString = #filePath, line: UInt = #line) {
    if actual != expected { CheckReport.fail("Values differ: \(actual) != \(expected)", file: file, line: line) }
}
func expectTrue(_ value: Bool, file: StaticString = #filePath, line: UInt = #line) {
    if !value { CheckReport.fail("Expected true", file: file, line: line) }
}
func expectFalse(_ value: Bool, file: StaticString = #filePath, line: UInt = #line) {
    if value { CheckReport.fail("Expected false", file: file, line: line) }
}
func expectNil<T>(_ value: T?, file: StaticString = #filePath, line: UInt = #line) {
    if value != nil { CheckReport.fail("Expected nil", file: file, line: line) }
}
func expectNotNil<T>(_ value: T?, file: StaticString = #filePath, line: UInt = #line) {
    if value == nil { CheckReport.fail("Expected non-nil", file: file, line: line) }
}
func requireValue<T>(_ value: T?, file: StaticString = #filePath, line: UInt = #line) throws -> T {
    guard let value else { CheckReport.fail("Missing required value", file: file, line: line); throw CheckFailure.unwrap }
    return value
}
func expectFailure<T>(_ expression: @autoclosure () throws -> T, file: StaticString = #filePath, line: UInt = #line,
                      inspect: (Error) -> Void = { _ in }) {
    do { _ = try expression(); CheckReport.fail("Expected error", file: file, line: line) }
    catch { inspect(error) }
}
func failCheck(_ message: String, file: StaticString = #filePath, line: UInt = #line) {
    CheckReport.fail(message, file: file, line: line)
}
