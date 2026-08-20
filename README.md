# AI Usage Menu

A personal macOS menu-bar app showing end-user subscription usage from existing Claude Code and Codex CLI logins. It requires macOS 13+, Xcode, Claude Code (optional), and Codex CLI logged in with `codex login`. No API keys are used.

## Use the app

1. Log into Codex once: `codex login`.
2. Complete the Claude setup below if you want Claude usage.
3. Open `AIUsageMenu.xcodeproj` in Xcode and click Run.
4. Click the chart icon in the menu bar. The app refreshes immediately, every five minutes, and whenever you choose **Refresh**.

Each row shows percentage used and its reset time. If a provider is unavailable, its section shows a short error while retaining the last successful reading.

Use **Settings…** in the menu-bar panel to hide Claude or Codex. Disabled providers are not read or queried; turn one back on to refresh it.

## Install a local app build

You do not need to launch the app from Xcode every time.

1. Open `AIUsageMenu.xcodeproj` in Xcode.
2. Choose **Product > Build**.
3. In Xcode's project navigator, open **Products**.
4. Right-click `AIUsageMenu.app` and choose **Show in Finder**.
5. Copy `AIUsageMenu.app` to `/Applications`.
6. Launch `AIUsageMenu` from `/Applications`; it appears in the menu bar as a chart icon.

To open it from Shortcuts, create a shortcut with the **Open App** action and choose `AIUsageMenu`. A local development build is fine for your own Mac; sharing it with other people should use a signed and notarized build.

The app appears in the menu bar only; it has no Dock icon. From a terminal with Xcode selected, build and test with:

```sh
xcodebuild -project AIUsageMenu.xcodeproj -scheme AIUsageMenu build
xcodebuild -project AIUsageMenu.xcodeproj -scheme AIUsageMenu test
```

## Claude setup

Copy the helper and make it executable:

```sh
cp Support/claude-statusline.sh ~/.claude/ai-usage-statusline.sh
chmod +x ~/.claude/ai-usage-statusline.sh
```

Then add the following to `~/.claude/settings.json` (merge it into an existing `statusLine` setup if you have one):

```json
{"statusLine":{"type":"command","command":"~/.claude/ai-usage-statusline.sh"}}
```

Send one Claude request to produce usage data. The helper writes only the raw status-line payload to `~/Library/Application Support/AIUsage/claude-status.json`; the app reads only `rate_limits` and its modification date.

## Troubleshooting and privacy

“Codex CLI not found” means `codex` is not on PATH or in Homebrew’s standard locations. “Codex is not logged in” means run `codex login`. Claude setup messages mean its helper has not yet received a status-line payload. Failed refreshes keep the last successful value.

The app makes no HTTP calls and never reads Keychain, credentials, browser data, prompts, or transcripts. It stores only the latest Claude status payload and a normalized Codex usage cache, both intended to be user-only readable.

## Non-goals

No API billing/costs, multiple accounts, history, charts, alerts, settings, background service, login item, automatic updates, browser scraping, or App Store packaging.
