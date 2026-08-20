import SwiftUI

struct MenuContentView: View {
    @ObservedObject var store: UsageStore

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack { Text("AI Usage").font(.headline); Spacer(); Button("Refresh") { store.refresh() }.disabled(store.claude.isRefreshing || store.codex.isRefreshing) }
            provider("Claude", status: store.claude)
            Divider()
            provider("Codex", status: store.codex)
            HStack { Spacer(); Button("Quit") { NSApplication.shared.terminate(nil) } }
        }
        .padding()
        .frame(width: 320)
    }

    @ViewBuilder private func provider(_ name: String, status: ProviderStatus) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(name).font(.headline)
            if let usage = status.usage {
                ForEach(usage.windows) { window in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 8) {
                            Text(window.label).frame(width: 30, alignment: .leading)
                            ProgressView(value: window.clampedPercent, total: 100).frame(width: 92)
                            Text("\(Int(window.clampedPercent.rounded()))% used")
                        }
                        Text(resetText(window.resetsAt)).foregroundStyle(.secondary).padding(.leading, 38)
                    }.font(.caption)
                }
                Text("Updated \(RelativeDateTimeFormatter().localizedString(for: usage.updatedAt, relativeTo: Date()))").font(.caption).foregroundStyle(.secondary)
            }
            if let error = status.errorMessage { Text(error).font(.caption).foregroundStyle(.secondary) }
            if status.usage == nil && status.errorMessage == nil { Text("No usage data yet.").font(.caption).foregroundStyle(.secondary) }
        }
    }

    private func resetText(_ date: Date?) -> String {
        guard let date else { return "Reset unknown" }
        return "resets \(RelativeDateTimeFormatter().localizedString(for: date, relativeTo: Date()))"
    }
}
