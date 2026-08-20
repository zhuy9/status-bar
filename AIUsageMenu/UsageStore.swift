import SwiftUI

enum AppFiles {
    static let directory = FileManager.default.homeDirectoryForCurrentUser.appending(path: "Library/Application Support/AIUsage")
    static let claudeURL = directory.appending(path: "claude-status.json")
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
    private let claudeReader = ClaudeUsageReader()
    private lazy var codexClient = CodexAppServerClient()

    init() {
        claudeEnabled = UserDefaults.standard.object(forKey: "claudeEnabled") as? Bool ?? true
        codexEnabled = UserDefaults.standard.object(forKey: "codexEnabled") as? Bool ?? true
        AppFiles.prepareDirectory()
        loadCachedValues()
        refresh()
        Task { [weak self] in
            while !Task.isCancelled { try? await Task.sleep(nanoseconds: 300_000_000_000); self?.refresh() }
        }
    }

    func refresh() {
        guard !claude.isRefreshing && !codex.isRefreshing else { return }
        guard claudeEnabled || codexEnabled else { return }
        if claudeEnabled { claude.isRefreshing = true }
        if codexEnabled { codex.isRefreshing = true }
        Task { [weak self] in
            guard let self else { return }
            if self.claudeEnabled {
                do { self.claude.usage = try self.claudeReader.read(); self.claude.errorMessage = nil }
                catch { self.claude.errorMessage = error.localizedDescription }
                self.claude.isRefreshing = false
            }
            if self.codexEnabled {
                do { let usage = try await self.codexClient.fetch(); self.codex.usage = usage; self.codex.errorMessage = nil; self.saveCodex(usage) }
                catch { self.codex.errorMessage = error.localizedDescription }
                self.codex.isRefreshing = false
            }
        }
    }

    func setClaudeEnabled(_ enabled: Bool) { setEnabled(enabled, key: "claudeEnabled", provider: .claude) }
    func setCodexEnabled(_ enabled: Bool) { setEnabled(enabled, key: "codexEnabled", provider: .codex) }

    private func loadCachedValues() {
        if claudeEnabled, let usage = try? claudeReader.read() { claude.usage = usage }
        if codexEnabled, let data = try? Data(contentsOf: AppFiles.codexURL), let usage = try? JSONDecoder().decode(ProviderUsage.self, from: data) { codex.usage = usage }
    }

    private func saveCodex(_ usage: ProviderUsage) {
        guard let data = try? JSONEncoder().encode(usage) else { return }
        try? data.write(to: AppFiles.codexURL, options: .atomic)
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: AppFiles.codexURL.path)
    }

    private func setEnabled(_ enabled: Bool, key: String, provider: Provider) {
        UserDefaults.standard.set(enabled, forKey: key)
        if provider == .claude { claudeEnabled = enabled } else { codexEnabled = enabled }
        if enabled { refresh() }
    }
}
