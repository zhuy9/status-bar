import XCTest
@testable import AIUsageMenu

final class ClaudeUsageReaderTests: XCTestCase {
    private func fixture(_ json: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try Data(json.utf8).write(to: url); return url
    }

    func testReadsBothWindows() throws {
        let url = try fixture("{\"rate_limits\":{\"five_hour\":{\"used_percentage\":23.5,\"resets_at\":1738425600},\"seven_day\":{\"used_percentage\":41.2}}}")
        XCTAssertEqual(try ClaudeUsageReader(url: url).read().windows.map(\.id), ["claude-five-hour", "claude-seven-day"])
    }
    func testReadsSingleWindow() throws {
        let url = try fixture("{\"rate_limits\":{\"five_hour\":{\"used_percentage\":23.5}}}")
        XCTAssertEqual(try ClaudeUsageReader(url: url).read().windows.count, 1)
    }
    func testMissingLimitsNeedsRequest() throws {
        XCTAssertThrowsError(try ClaudeUsageReader(url: fixture("{}")).read())
    }
    func testMalformedFileIsUnreadable() throws {
        XCTAssertThrowsError(try ClaudeUsageReader(url: fixture("not-json")).read())
    }
}
