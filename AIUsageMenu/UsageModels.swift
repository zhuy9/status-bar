import SwiftUI

enum Provider: String, Codable { case claude, codex }

// 70 is Claude Code's own threshold: below it, it suppresses the "close to your limit" warning
// outright. ponytail: 90 for red is ours — Claude Code only goes red on an actual 429, which is
// too late to be useful in a menu bar.
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

// A GUI app inherits a bare PATH, and `zsh -lc` skips .zshrc where PATH edits usually live —
// hence the explicit install locations before falling back to an interactive login shell.
// Known locations are checked before PATH so the common case stats three paths instead of
// every PATH entry: a stat under a stale or automounted PATH entry is what makes macOS ask
// for network-volume access.
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

func durationLabel(_ minutes: Int?) -> String {
    guard let minutes, minutes > 0 else { return "Usage" }
    if minutes % 1_440 == 0 { return "\(minutes / 1_440)d" }
    if minutes >= 1_440 { return "\(minutes / 1_440)d \((minutes % 1_440) / 60)h" }
    if minutes % 60 == 0 { return "\(minutes / 60)h" }
    return minutes < 60 ? "\(minutes)m" : "\(minutes / 60)h \(minutes % 60)m"
}
