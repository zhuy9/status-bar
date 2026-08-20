import XCTest
@testable import AIUsageMenu

final class CodexResponseParserTests: XCTestCase {
    func testParsesBothWindows() throws {
        let line = "{\"id\":2,\"result\":{\"rateLimits\":{\"primary\":{\"usedPercent\":25,\"windowDurationMins\":300,\"resetsAt\":1730947200},\"secondary\":{\"usedPercent\":41,\"windowDurationMins\":10080}}}}"
        XCTAssertEqual(try CodexAppServerClient.parseResponse(line)?.windows.map(\.label), ["5h", "7d"])
    }
    func testParsesOneWindow() throws {
        let line = "{\"id\":2,\"result\":{\"rateLimits\":{\"primary\":{\"usedPercent\":25,\"windowDurationMins\":300}}}}"
        XCTAssertEqual(try CodexAppServerClient.parseResponse(line)?.windows.count, 1)
    }
    func testIgnoresNotification() throws { XCTAssertNil(try CodexAppServerClient.parseResponse("{\"method\":\"notice\"}")) }
    func testDurationLabels() { XCTAssertEqual(durationLabel(30), "30m"); XCTAssertEqual(durationLabel(300), "5h"); XCTAssertEqual(durationLabel(10080), "7d") }
    func testCacheRoundTrip() throws {
        let value = ProviderUsage(provider: .codex, updatedAt: .now, windows: [])
        XCTAssertEqual(try JSONDecoder().decode(ProviderUsage.self, from: JSONEncoder().encode(value)), value)
    }
}
