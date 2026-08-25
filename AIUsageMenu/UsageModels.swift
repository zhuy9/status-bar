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

// Both CLIs need the same hardening, so spawn them the same way. Returns nil on a spawn failure
// or non-zero exit; callers translate that into their own error.
// USER is pinned because the Claude CLI resolves the subscription profile from it — without it
// /usage exits 0 and reports no plan percentages at all. The working directory is pinned because
// a Finder-launched app starts at "/", where both CLIs walk up hunting for git roots.
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
