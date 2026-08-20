import Foundation

enum CodexUsageError: LocalizedError {
    case notFound, timedOut, notLoggedIn, invalidResponse
    var errorDescription: String? {
        switch self {
        case .notFound: "Codex CLI not found."
        case .timedOut: "Codex usage request timed out."
        case .notLoggedIn: "Codex is not logged in. Run codex login."
        case .invalidResponse: "Codex usage could not be read."
        }
    }
}

struct CodexAppServerClient {
    private let executable: URL?
    init(executable: URL? = nil) { self.executable = executable ?? Self.findExecutable() }

    func fetch() async throws -> ProviderUsage {
        try await Task.detached { try fetchSynchronously(executable: executable) }.value
    }

    static func parseResponse(_ line: String, updatedAt: Date = Date()) throws -> ProviderUsage? {
        guard let data = line.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        if let error = json["error"] as? [String: Any], error["message"] != nil { throw CodexUsageError.notLoggedIn }
        guard (json["id"] as? NSNumber)?.intValue == 2 else { return nil }
        guard let limits = ((json["result"] as? [String: Any])?["rateLimits"] as? [String: Any]) else { throw CodexUsageError.invalidResponse }
        let sources: [(value: Any?, id: String)] = [(limits["primary"], "codex-primary"), (limits["secondary"], "codex-secondary")]
        let windows = sources.compactMap { source in makeWindow(source.value, id: source.id) }
            .sorted { windowDuration(limits[$0.id == "codex-primary" ? "primary" : "secondary"]) < windowDuration(limits[$1.id == "codex-primary" ? "primary" : "secondary"]) }
        guard !windows.isEmpty else { throw CodexUsageError.invalidResponse }
        return ProviderUsage(provider: .codex, updatedAt: updatedAt, windows: windows)
    }

    private static func makeWindow(_ value: Any?, id: String) -> UsageWindow? {
        guard let item = value as? [String: Any], let used = (item["usedPercent"] as? NSNumber)?.doubleValue else { return nil }
        let minutes = (item["windowDurationMins"] as? NSNumber)?.intValue
        let resetValue = (item["resetsAt"] as? NSNumber)?.doubleValue
        let reset = resetValue.map(Date.init(timeIntervalSince1970:))
        return UsageWindow(id: id, label: durationLabel(minutes), usedPercent: used, resetsAt: reset)
    }

    private static func windowDuration(_ value: Any?) -> Int {
        ((value as? [String: Any])?["windowDurationMins"] as? NSNumber)?.intValue ?? .max
    }

    private static func findExecutable() -> URL? {
        let paths = (ProcessInfo.processInfo.environment["PATH"] ?? "").split(separator: ":").map { String($0) + "/codex" } + [
            FileManager.default.homeDirectoryForCurrentUser.appending(path: ".local/bin/codex").path,
            "/opt/homebrew/bin/codex",
            "/usr/local/bin/codex"
        ]
        if let path = paths.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) { return URL(fileURLWithPath: path) }
        let task = Process(); task.executableURL = URL(fileURLWithPath: "/bin/zsh"); task.arguments = ["-lc", "command -v codex"]
        let output = Pipe(); task.standardOutput = output
        guard (try? task.run()) != nil else { return nil }; task.waitUntilExit()
        let path = String(data: output.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return FileManager.default.isExecutableFile(atPath: path) ? URL(fileURLWithPath: path) : nil
    }
}

private func fetchSynchronously(executable: URL?) throws -> ProviderUsage {
    guard let executable else { throw CodexUsageError.notFound }
    let process = Process(), input = Pipe(), output = Pipe()
    process.executableURL = executable; process.arguments = ["app-server", "--stdio"]; process.standardInput = input; process.standardOutput = output; process.standardError = Pipe()
    try process.run()
    let requests = ["{\"method\":\"initialize\",\"id\":1,\"params\":{\"clientInfo\":{\"name\":\"ai_usage_menu\",\"title\":\"AI Usage Menu\",\"version\":\"0.1.0\"}}}", "{\"method\":\"initialized\",\"params\":{}}", "{\"method\":\"account/rateLimits/read\",\"id\":2}"]
    input.fileHandleForWriting.write(Data((requests.joined(separator: "\n") + "\n").utf8))
    let deadline = Date().addingTimeInterval(10)
    DispatchQueue.global().asyncAfter(deadline: .now() + 10) {
        if process.isRunning { process.terminate() }
    }
    var buffer = Data()
    defer { if process.isRunning { process.terminate() } }
    while true {
        let data = output.fileHandleForReading.availableData
        if data.isEmpty { break }
        buffer.append(data)
        while let range = buffer.range(of: Data([10])) {
            let line = String(data: buffer.subdata(in: 0..<range.lowerBound), encoding: .utf8) ?? ""
            buffer.removeSubrange(0...range.lowerBound)
            if let usage = try CodexAppServerClient.parseResponse(line) { return usage }
        }
    }
    throw Date() >= deadline ? CodexUsageError.timedOut : CodexUsageError.invalidResponse
}
