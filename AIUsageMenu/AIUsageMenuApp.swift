import SwiftUI

@main struct AIUsageMenuApp: App {
    @StateObject private var store = UsageStore()

    var body: some Scene {
        MenuBarExtra("AI Usage", systemImage: "chart.bar") {
            MenuContentView(store: store)
        }
        .menuBarExtraStyle(.window)
    }
}
