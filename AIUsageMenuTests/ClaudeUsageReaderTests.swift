import XCTest
@testable import AIUsageMenu

final class ClaudeUsageReaderTests: XCTestCase {
    private let output = """
    You are currently using your subscription to power your Claude Code usage

    Current session: 52% used · resets Aug 24 at 4:29pm (America/Chicago)
    Current week (all models): 14% used · resets Aug 28 at 4:59am (America/Chicago)

    What's contributing to your limits usage?
    """

    func testReadsBothWindows() throws {
        let windows = try ClaudeUsageReader.parse(output).windows
        XCTAssertEqual(windows.map(\.id), ["claude-five-hour", "claude-seven-day"])
        XCTAssertEqual(windows.map(\.usedPercent), [52, 14])
        XCTAssertNotNil(windows.first?.resetsAt)
    }

    func testReadsSingleWindow() throws {
        let windows = try ClaudeUsageReader.parse("Current session: 3% used").windows
        XCTAssertEqual(windows.count, 1)
        XCTAssertNil(windows.first?.resetsAt)
    }

    func testNoLimitLinesNeedsRequest() {
        XCTAssertThrowsError(try ClaudeUsageReader.parse("Total cost: $0.0000"))
    }

    func testResetDateUsesSystemZoneAndCurrentYear() throws {
        let date = try XCTUnwrap(ClaudeUsageReader.resetDate("· resets Aug 24 at 4:29pm (America/Chicago)"))
        let parts = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        XCTAssertEqual(parts.year, Calendar.current.component(.year, from: Date()))
        XCTAssertEqual([parts.month, parts.day, parts.hour, parts.minute], [8, 24, 16, 29])
    }

    func testResetDateOnTheHourHasNoMinutes() throws {
        let date = try XCTUnwrap(ClaudeUsageReader.resetDate("· resets Aug 28 at 5am (America/Chicago)"))
        let parts = Calendar.current.dateComponents([.day, .hour, .minute], from: date)
        XCTAssertEqual([parts.day, parts.hour, parts.minute], [28, 5, 0])
    }
}
