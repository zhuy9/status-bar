import Foundation

enum ClaudeUsageError: LocalizedError {
    case setupRequired, noUsage, unreadable
    var errorDescription: String? {
        switch self {
        case .setupRequired: "Claude setup required or no Claude session has produced data yet."
        case .noUsage: "Send one Claude request to populate subscription usage."
        case .unreadable: "Claude usage file could not be read."
        }
    }
}

struct ClaudeUsageReader {
    let url: URL

    init(url: URL = AppFiles.claudeURL) { self.url = url }

    func read() throws -> ProviderUsage {
        guard FileManager.default.fileExists(atPath: url.path) else { throw ClaudeUsageError.setupRequired }
        let data: Data
        do { data = try Data(contentsOf: url) } catch { throw ClaudeUsageError.unreadable }
        guard let payload = try? JSONDecoder().decode(Payload.self, from: data) else { throw ClaudeUsageError.unreadable }
        guard let limits = payload.rateLimits else { throw ClaudeUsageError.noUsage }
        let windows = [window(limits.fiveHour, id: "claude-five-hour", label: "5h"), window(limits.sevenDay, id: "claude-seven-day", label: "7d")].compactMap { $0 }
        guard !windows.isEmpty else { throw ClaudeUsageError.noUsage }
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        return ProviderUsage(provider: .claude, updatedAt: attributes?[.modificationDate] as? Date ?? Date(), windows: windows)
    }

    private func window(_ source: Limit?, id: String, label: String) -> UsageWindow? {
        guard let used = source?.usedPercentage else { return nil }
        return UsageWindow(id: id, label: label, usedPercent: used, resetsAt: source?.resetsAt.map(Date.init(timeIntervalSince1970:)))
    }

    private struct Payload: Decodable { let rateLimits: Limits?; enum CodingKeys: String, CodingKey { case rateLimits = "rate_limits" } }
    private struct Limits: Decodable { let fiveHour: Limit?; let sevenDay: Limit?; enum CodingKeys: String, CodingKey { case fiveHour = "five_hour"; case sevenDay = "seven_day" } }
    private struct Limit: Decodable { let usedPercentage: Double?; let resetsAt: TimeInterval?; enum CodingKeys: String, CodingKey { case usedPercentage = "used_percentage"; case resetsAt = "resets_at" } }
}
