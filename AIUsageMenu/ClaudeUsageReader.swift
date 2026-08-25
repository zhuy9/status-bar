import Foundation

enum ClaudeUsageError: LocalizedError {
    case notFound, failed, noUsage, unreadable
    var errorDescription: String? {
        switch self {
        case .notFound: "Claude Code CLI not found."
        case .failed: "Claude usage request failed or timed out."
        case .noUsage: "Send one Claude request to populate subscription usage."
        case .unreadable: "Claude usage could not be read."
        }
    }
}

struct ClaudeUsageReader {
    private let executable = findExecutable("claude")

    // `/usage` is a local slash command: no model call, no tokens. It is the only source of plan
    // percentages outside the terminal status line, which the VS Code extension never renders.
    func read() async throws -> ProviderUsage {
        try await Task.detached { try Self.parse(Self.run(executable, prompt: "/usage")) }.value
    }

    // Costs a real turn — that is the point, it is what starts the rate-limit window.
    func sayHello(_ prompt: String) async throws {
        _ = try await Task.detached { try Self.run(executable, prompt: prompt, timeout: 90) }.value
    }

    static func parse(_ text: String) throws -> ProviderUsage {
        let windows = [
            window(text, id: "claude-five-hour", label: "5h", prefix: "Current session:"),
            window(text, id: "claude-seven-day", label: "7d", prefix: "Current week (all models):")
        ].compactMap { $0 }
        guard !windows.isEmpty else { throw ClaudeUsageError.noUsage }
        return ProviderUsage(provider: .claude, updatedAt: Date(), windows: windows)
    }

    // "Current session: 52% used · resets Aug 24 at 4:29pm (America/Chicago)"
    private static func window(_ text: String, id: String, label: String, prefix: String) -> UsageWindow? {
        guard let line = text.split(separator: "\n").first(where: { $0.hasPrefix(prefix) }) else { return nil }
        let rest = line.dropFirst(prefix.count).trimmingCharacters(in: .whitespaces)
        guard let percent = rest.split(separator: "%").first.flatMap({ Double($0) }) else { return nil }
        return UsageWindow(id: id, label: label, usedPercent: percent, resetsAt: resetDate(rest))
    }

    // Two formats because the CLI drops ":00" on the hour.
    // ponytail: no year in the stamp, so it comes from defaultDate — a late-December reading of a
    // January reset lands a year early.
    static func resetDate(_ text: String) -> Date? {
        guard let range = text.range(of: "resets ") else { return nil }
        let stamp = text[range.upperBound...].split(separator: "(").first?.trimmingCharacters(in: .whitespaces) ?? ""
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.defaultDate = Calendar.current.startOfDay(for: Date()) // not now: would leak the current minute
        for format in ["MMM d 'at' h:mma", "MMM d 'at' ha"] {
            formatter.dateFormat = format
            if let date = formatter.date(from: stamp) { return date }
        }
        return nil
    }

    // disableAllHooks: this polls hourly; firing the user's SessionStart hooks on a timer is rude.
    private static func run(_ executable: URL?, prompt: String, timeout: TimeInterval = 20) throws -> String {
        guard let executable else { throw ClaudeUsageError.notFound }
        let arguments = ["-p", prompt, "--output-format", "json", "--settings", #"{"disableAllHooks":true}"#]
        guard let data = runCLI(executable, arguments, timeout: timeout) else { throw ClaudeUsageError.failed }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let result = json["result"] as? String else { throw ClaudeUsageError.unreadable }
        return result
    }
}
