import SwiftUI
import AppKit

@main struct AIUsageMenuApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    // A stub: App requires a scene, and the real settings window is opened from the status menu.
    var body: some Scene {
        Settings { EmptyView() }
    }
}

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBar: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusBar = StatusBarController()
    }
}

struct SettingsView: View {
    @ObservedObject var store: UsageStore

    var body: some View {
        Form {
            Toggle("Show Claude", isOn: Binding(get: { store.claudeEnabled }, set: store.setClaudeEnabled))
            Toggle("Show Codex", isOn: Binding(get: { store.codexEnabled }, set: store.setCodexEnabled))
            Picker("Refresh every", selection: $store.refreshInterval) {
                ForEach(RefreshInterval.allCases) { Text($0.menuLabel).tag($0) }
            }
            TextField("Greeting", text: $store.greeting, prompt: Text(UsageStore.defaultGreeting))
            Text("Sent by Send a Greeting to start a rate-limit window. Leave blank for “\(UsageStore.defaultGreeting)”.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .toggleStyle(.switch)
        .frame(width: 280)
        .padding(20)
    }
}
