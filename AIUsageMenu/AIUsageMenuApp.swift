import SwiftUI
import AppKit

private enum MenuBarIcon {
    static let image: NSImage = {
        let image = NSImage(size: NSSize(width: 18, height: 18))
        image.lockFocus()
        NSColor.labelColor.setStroke()
        NSColor.labelColor.setFill()
        for (y, fillWidth) in [(CGFloat(3), CGFloat(4)), (CGFloat(8), CGFloat(7)), (CGFloat(13), CGFloat(7))] {
            NSBezierPath(roundedRect: NSRect(x: 2, y: y, width: 14, height: 2), xRadius: 1, yRadius: 1).stroke()
            NSBezierPath(roundedRect: NSRect(x: 2, y: y + 0.5, width: fillWidth, height: 1), xRadius: 0.5, yRadius: 0.5).fill()
        }
        image.unlockFocus()
        image.isTemplate = true
        return image
    }()
}

@main struct AIUsageMenuApp: App {
    @StateObject private var store = UsageStore()

    var body: some Scene {
        MenuBarExtra {
            MenuContentView(store: store)
        } label: {
            Image(nsImage: MenuBarIcon.image)
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
