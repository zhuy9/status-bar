import SwiftUI

// A menu, not a popover (HIG, The menu bar). Rows are hosted views because a menu item is only a
// string: it cannot draw a bar, and an item that does nothing is disabled and therefore gray.
@MainActor final class StatusBarController: NSObject, NSMenuDelegate {
    private let store = UsageStore()
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

    override init() {
        super.init()
        // A symbol, so the system tints it for the light bar, the dark bar and the selected state.
        item.button?.image = NSImage(systemSymbolName: "chart.bar.xaxis", accessibilityDescription: "Token Usage")
        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu
    }

    // Rebuilt on each open, so a provider toggled in Settings needs no bookkeeping.
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        for provider in Provider.allCases where store.isEnabled(provider) {
            if !menu.items.isEmpty { menu.addItem(.separator()) }
            menu.addItem(hosted(ProviderSection(store: store, provider: provider)))
        }
        if menu.items.isEmpty { menu.addItem(disabled("Enable a provider in Settings.")) }
        menu.addItem(.separator())

        let refresh = action("Refresh Now", #selector(refreshNow), key: "r")
        refresh.isEnabled = !store.isBusy
        menu.addItem(refresh)

        let every = NSMenuItem(title: "Refresh Every", action: nil, keyEquivalent: "")
        every.submenu = intervalMenu()
        menu.addItem(every)

        let greeting = NSMenuItem(title: "Send a Greeting", action: nil, keyEquivalent: "")
        greeting.submenu = greetingMenu()
        menu.addItem(greeting)

        menu.addItem(.separator())
        menu.addItem(action("Settings…", #selector(openSettings), key: ","))
        menu.addItem(action("Quit Token Usage", #selector(quit), key: "q"))
    }

    private func action(_ title: String, _ selector: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: selector, keyEquivalent: key)
        item.target = self
        return item
    }

    private func intervalMenu() -> NSMenu {
        let menu = NSMenu()
        for interval in RefreshInterval.allCases {
            let item = action(interval.menuLabel, #selector(pickInterval(_:)))
            item.representedObject = interval
            item.state = store.refreshInterval == interval ? .on : .off
            menu.addItem(item)
        }
        return menu
    }

    private func greetingMenu() -> NSMenu {
        let menu = NSMenu()
        for provider in Provider.allCases {
            let item = action("To \(provider.title)", #selector(sayHello(_:)))
            item.representedObject = provider
            item.isEnabled = !store.isBusy && store.isEnabled(provider)
            menu.addItem(item)
        }
        menu.addItem(.separator())
        menu.addItem(disabled("Sends “\(store.greetingText)” to start a rate-limit window. Spends real usage."))
        return menu
    }

    private func hosted<Content: View>(_ view: Content) -> NSMenuItem {
        let item = NSMenuItem()
        item.view = sizedHost(view)
        return item
    }

    // Ideal size, not fittingSize: fittingSize forces a layout pass from inside AppKit's own.
    private func sizedHost<Content: View>(_ view: Content) -> NSHostingView<Content> {
        let host = NSHostingView(rootView: view)
        host.sizingOptions = [.intrinsicContentSize]
        host.frame.size = host.intrinsicContentSize
        return host
    }

    private func disabled(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    @objc private func refreshNow() { store.refresh() }
    @objc private func quit() { NSApplication.shared.terminate(nil) }

    @objc private func pickInterval(_ sender: NSMenuItem) {
        guard let interval = sender.representedObject as? RefreshInterval else { return }
        store.refreshInterval = interval
    }

    @objc private func sayHello(_ sender: NSMenuItem) {
        guard let provider = sender.representedObject as? Provider else { return }
        store.sayHello(provider)
    }

    // SwiftUI's Settings scene only opens via SettingsLink, which a menu action cannot reach.
    // Deferred: showing a window inside a menu action deadlocks on the tracking run loop.
    @objc private func openSettings() {
        Task { @MainActor in
            NSApplication.shared.activate(ignoringOtherApps: true)
            self.settings.makeKeyAndOrderFront(nil)
        }
    }

    private lazy var settings: NSWindow = {
        let view = sizedHost(SettingsView(store: store))
        let window = NSWindow(contentRect: view.frame, styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "Token Usage Settings"
        window.contentView = view
        window.isReleasedWhenClosed = false
        window.center()
        return window
    }()
}

// One hosted view per provider, not per row: columns line up, and a refresh lands while open.
private struct ProviderSection: View {
    @ObservedObject var store: UsageStore
    let provider: Provider

    var body: some View {
        let status = store.status(for: provider)
        VStack(alignment: .leading, spacing: 0) {
            Text(provider.title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(height: 22)
            if let usage = status.usage {
                ForEach(usage.windows) { window in
                    HStack(spacing: 8) {
                        Text(window.label).frame(width: 46, alignment: .leading)
                        ProgressView(value: window.clampedPercent, total: 100)
                            .frame(width: 58)
                            .tint(usageColor(window.clampedPercent))
                        Text("\(Int(window.clampedPercent.rounded()))%")
                            .monospacedDigit()
                            .frame(width: 38, alignment: .trailing)
                        Spacer(minLength: 12)
                        Text(resetText(window.resetsAt)).foregroundStyle(.secondary)
                    }
                    .frame(height: 22)
                }
                Text("Updated \(Self.age.localizedString(for: usage.updatedAt, relativeTo: Date()))")
                    .foregroundStyle(.secondary)
                    .frame(height: 22)
            }
            if let error = status.errorMessage {
                Text(error).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true).padding(.vertical, 3)
            }
            if status.usage == nil && status.errorMessage == nil {
                Text("No usage data yet.").foregroundStyle(.secondary).frame(height: 22)
            }
        }
        .font(.system(size: 13))
        .frame(width: 296, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 2)
    }

    // .named so a fresh reading says "now" rather than "in 0 seconds".
    private static let age: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.dateTimeStyle = .named
        return formatter
    }()
}
