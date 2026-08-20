import SwiftUI

@main struct AIUsageMenuApp: App {
    @StateObject private var store = UsageStore()

    var body: some Scene {
        MenuBarExtra("Token Usage", systemImage: "chart.bar") {
            MenuContentView(store: store)
        }
        .menuBarExtraStyle(.window)

        Settings {
            Form {
                Toggle("Show Claude", isOn: Binding(get: { store.claudeEnabled }, set: store.setClaudeEnabled))
                Toggle("Show Codex", isOn: Binding(get: { store.codexEnabled }, set: store.setCodexEnabled))
            }
            .toggleStyle(.switch)
            .padding()
            .frame(width: 260)
        }
    }
}
