import SwiftUI

enum Provider: String, Codable, CaseIterable {
    case claude, codex
    var title: String { self == .claude ? "Claude Code" : "Codex" }
}

// 70 is Claude Code's own warning threshold.
// ponytail: 90 for red is ours — the CLI only goes red on a 429, too late to be useful here.
func usageColor(_ percent: Double) -> Color {
    percent >= 90 ? .red : percent >= 70 ? .yellow : .blue
}

struct UsageWindow: Identifiable, Codable, Equatable {
    let id: String
    let label: String
    let usedPercent: Double
    let resetsAt: Date?

    var clampedPercent: Double { min(100, max(0, usedPercent)) }
}

struct ProviderUsage: Codable, Equatable {
    let provider: Provider
    let updatedAt: Date
    let windows: [UsageWindow]
}

struct ProviderStatus {
    var usage: ProviderUsage?
    var errorMessage: String?
    var isRefreshing = false
}

// A GUI app inherits a bare PATH, and `zsh -lc` skips .zshrc — hence the explicit locations, then
// an interactive login shell. Known paths go first: stat'ing a stale automounted PATH entry is
// what makes macOS ask for network-volume access.
func findExecutable(_ name: String) -> URL? {
    let paths = [
        FileManager.default.homeDirectoryForCurrentUser.appending(path: ".local/bin/\(name)").path,
        "/opt/homebrew/bin/\(name)",
        "/usr/local/bin/\(name)"
    ] + (ProcessInfo.processInfo.environment["PATH"] ?? "").split(separator: ":").map { String($0) + "/" + name }
    if let path = paths.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) { return URL(fileURLWithPath: path) }
    let task = Process(); task.executableURL = URL(fileURLWithPath: "/bin/zsh"); task.arguments = ["-ilc", "command -v \(name)"]
    let output = Pipe(); task.standardOutput = output; task.standardError = Pipe()
    guard (try? task.run()) != nil else { return nil }; task.waitUntilExit()
    let path = String(data: output.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    return FileManager.default.isExecutableFile(atPath: path) ? URL(fileURLWithPath: path) : nil
}

// Both CLIs get the same hardening. Returns nil on spawn failure or non-zero exit; callers map
// that to their own error. USER is pinned because the Claude CLI resolves the plan from it —
// without it /usage exits 0 with no percentages. The cwd is pinned because a Finder launch is "/".
func runCLI(_ executable: URL, _ arguments: [String], timeout: TimeInterval = 20) -> Data? {
    let process = Process(), output = Pipe()
    process.executableURL = executable
    process.arguments = arguments
    var environment = ProcessInfo.processInfo.environment
    environment["USER"] = NSUserName()
    environment["HOME"] = FileManager.default.homeDirectoryForCurrentUser.path
    process.environment = environment
    process.currentDirectoryURL = AppFiles.directory
    process.standardOutput = output
    process.standardError = Pipe()
    guard (try? process.run()) != nil else { return nil }
    DispatchQueue.global().asyncAfter(deadline: .now() + timeout) { if process.isRunning { process.terminate() } }
    let data = output.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    return process.terminationStatus == 0 ? data : nil
}

func durationLabel(_ minutes: Int?) -> String {
    guard let minutes, minutes > 0 else { return "Usage" }
    if minutes % 1_440 == 0 { return "\(minutes / 1_440)d" }
    if minutes >= 1_440 { return "\(minutes / 1_440)d \((minutes % 1_440) / 60)h" }
    if minutes % 60 == 0 { return "\(minutes / 60)h" }
    return minutes < 60 ? "\(minutes)m" : "\(minutes / 60)h \(minutes % 60)m"
}

enum RefreshInterval: Int, CaseIterable, Identifiable {
    case fifteenMinutes = 900, hour = 3600, fiveHours = 18_000, day = 86_400

    var id: Int { rawValue }
    var menuLabel: String {
        switch self {
        case .fifteenMinutes: "15 Minutes"
        case .hour: "1 Hour"
        case .fiveHours: "5 Hours"
        case .day: "1 Day"
        }
    }
}

// Absolute, not relative: "4:29 PM" survives a menu left open, "in 3 hours" does not.
func resetText(_ date: Date?) -> String {
    guard let date else { return "reset unknown" }
    let formatter = DateFormatter()
    formatter.setLocalizedDateFormatFromTemplate(Calendar.current.isDateInToday(date) ? "jmm" : "EEEjmm")
    return formatter.string(from: date)
}
