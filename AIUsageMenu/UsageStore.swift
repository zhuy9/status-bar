import SwiftUI

enum AppFiles {
    static let directory = FileManager.default.homeDirectoryForCurrentUser.appending(path: "Library/Application Support/AIUsage")
    static let claudeURL = directory.appending(path: "claude-cache.json")
    static let codexURL = directory.appending(path: "codex-cache.json")

    static func prepareDirectory() {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
    }
}

@MainActor final class UsageStore: ObservableObject {
    @Published var claude = ProviderStatus()
    @Published var codex = ProviderStatus()
    @Published private(set) var claudeEnabled: Bool
    @Published private(set) var codexEnabled: Bool
    @Published var greeting: String { didSet { UserDefaults.standard.set(greeting, forKey: "greeting") } }
    private let claudeReader = ClaudeUsageReader()
    private lazy var codexClient = CodexAppServerClient()

    init() {
        claudeEnabled = UserDefaults.standard.object(forKey: "claudeEnabled") as? Bool ?? true
        codexEnabled = UserDefaults.standard.object(forKey: "codexEnabled") as? Bool ?? true
        greeting = UserDefaults.standard.string(forKey: "greeting") ?? UsageStore.defaultGreeting
        AppFiles.prepareDirectory()
        loadCachedValues()
        refresh()
        Task { [weak self] in
            while !Task.isCancelled { try? await Task.sleep(for: .seconds(3600)); self?.refresh() }
        }
        // Task.sleep does not run through system sleep, so the hourly tick would otherwise leave
        // hour-old numbers on screen after the lid opens. Note: NSWorkspace posts to its own
        // notification centre, not NotificationCenter.default.
        _ = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    var isBusy: Bool { claude.isRefreshing || codex.isRefreshing }

    static let defaultGreeting = "hi"

    // Empty or whitespace-only would send a blank prompt, so fall back at use rather than
    // coercing the field while it is being typed in. Also the button label, so the two cannot drift.
    var greetingText: String {
        let trimmed = greeting.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? Self.defaultGreeting : trimmed
    }

    // One throwaway turn, which is what starts a rate-limit window. It spends real usage, and a
    // single "hi" is well under 1% of a window, so the bar may not visibly move.
    func sayHello(_ provider: Provider) {
        guard !isBusy else { return }
        let isClaude = provider == .claude
        if isClaude { claude.isRefreshing = true } else { codex.isRefreshing = true }
        Task { [weak self] in
            guard let self else { return }
            do {
                if isClaude { try await self.claudeReader.sayHello(self.greetingText) }
                else { try await self.codexClient.sayHello(self.greetingText) }
            } catch {
                if isClaude { self.claude.errorMessage = error.localizedDescription }
                else { self.codex.errorMessage = error.localizedDescription }
            }
            if isClaude { self.claude.isRefreshing = false } else { self.codex.isRefreshing = false }
            self.refresh()
        }
    }

    func refresh() {
        guard !isBusy else { return }
        guard claudeEnabled || codexEnabled else { return }
        if claudeEnabled { claude.isRefreshing = true }
        if codexEnabled { codex.isRefreshing = true }
        Task { [weak self] in
            guard let self else { return }
            if self.claudeEnabled {
                do { let usage = try await self.claudeReader.read(); self.claude.usage = usage; self.claude.errorMessage = nil; self.save(usage, to: AppFiles.claudeURL) }
                catch { self.claude.errorMessage = error.localizedDescription }
                self.claude.isRefreshing = false
            }
            if self.codexEnabled {
                do { let usage = try await self.codexClient.fetch(); self.codex.usage = usage; self.codex.errorMessage = nil; self.save(usage, to: AppFiles.codexURL) }
                catch { self.codex.errorMessage = error.localizedDescription }
                self.codex.isRefreshing = false
            }
        }
    }

    func setClaudeEnabled(_ enabled: Bool) { setEnabled(enabled, key: "claudeEnabled", provider: .claude) }
    func setCodexEnabled(_ enabled: Bool) { setEnabled(enabled, key: "codexEnabled", provider: .codex) }

    private func loadCachedValues() {
        if claudeEnabled { claude.usage = Self.loadCache(AppFiles.claudeURL) }
        if codexEnabled { codex.usage = Self.loadCache(AppFiles.codexURL) }
    }

    private static func loadCache(_ url: URL) -> ProviderUsage? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(ProviderUsage.self, from: data)
    }

    private func save(_ usage: ProviderUsage, to url: URL) {
        guard let data = try? JSONEncoder().encode(usage) else { return }
        try? data.write(to: url, options: .atomic)
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }

    private func setEnabled(_ enabled: Bool, key: String, provider: Provider) {
        UserDefaults.standard.set(enabled, forKey: key)
        if provider == .claude { claudeEnabled = enabled } else { codexEnabled = enabled }
        if enabled { refresh() }
    }
}
