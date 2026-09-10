<img src="docs/token-usage-logo.png" width="88" align="right" alt="">

# MacOS Token Usage Menu

A personal macOS menu-bar app that shows your Claude Code and Codex CLI **subscription usage** — percent used and reset time for each rate-limit window. It asks each CLI, using the login you already have. No API keys, no credential access, no HTTP calls of its own.

![Token Usage menu](docs/token-usage-menu.png)

## Requirements

| | |
|---|---|
| macOS | 13.0 or later |
| Xcode | 16.3 or later (the project uses `objectVersion = 71`) |
| Codex CLI | optional — needed for the Codex section, logged in via `codex login` |
| Claude Code | optional — needed for the Claude section, logged in to a Claude.ai subscription |

Both providers are optional. Turn either off in **Settings…** and it is never read or queried.

## Quick start

```sh
git clone <your-fork-url> && cd status-bar

# Codex section: log in once. Claude needs no setup beyond being logged in.
codex login
```

Then open `AIUsageMenu.xcodeproj` in Xcode and press **Run**. Click the chart icon in the menu bar. The built app is `Token Usage.app`; the Xcode target and the Swift module are still named `AIUsageMenu`.

The app refreshes on launch, on the interval set in Settings (15m, 1h, 5h, or 1d — default 1d), and whenever you choose **Refresh Now** (⌘R). Each row shows a bar, percent used, and the reset time. If a provider is unavailable, its rows stay put with the last successful reading and a line saying what went wrong.

It also refreshes on `NSWorkspace.didWakeNotification`, because the timer is a sleep loop rather than a wall clock and does not run through system sleep — without that, waking the Mac would leave stale numbers on screen until the next tick. The "Updated N ago" line under each provider is the tell if a reading is stale.

The click target is a menu, not a popover, because the HIG asks for one: *"Display a menu — not a popover — when people click your menu bar extra."* The usage rows are `NSHostingView`s inside that `NSMenu`, because a plain menu item is a string — it cannot draw a bar, and an item that does nothing is disabled and therefore gray.

## Claude setup

None. Being logged in is enough.

The app runs `claude -p /usage --output-format json` and reads the percentages out of the printed
text. `/usage` is a *local* slash command: it makes no model call, so this costs **no tokens** and
adds nothing to the usage it reports.

Two details worth knowing:

- The spawn passes `--settings '{"disableAllHooks":true}'`, so interval polling does not fire your
  `SessionStart` hooks on a timer.
- `USER` and `HOME` are set explicitly on the child. Without `USER` the CLI still exits 0 but
  prints session cost with no plan percentages at all — a silent empty reading.

An earlier version of this app used a `statusLine` helper instead. That never worked outside a
terminal: Claude Code executes the status-line command from the component that draws the terminal
footer, which the VS Code extension does not render. If you installed it, delete
`~/.claude/ai-usage-statusline.sh` and the `statusLine` key in `~/.claude/settings.json`.

## Codex setup

```sh
codex login
```

The app runs `codex app-server --stdio` and asks it for `account/rateLimits/read`. Requests time
out after 10 seconds.

Both providers resolve their binary the same way: `~/.local/bin`, `/opt/homebrew/bin`, and
`/usr/local/bin` first, then each `PATH` entry, and finally `zsh -ilc 'command -v …'`. The shell
fallback is interactive on purpose — `zsh -lc` does not read `.zshrc`, which is where most PATH
edits live. Both children also run with their working directory pinned to
`~/Library/Application Support/AIUsage`, because a Finder-launched app starts at `/` and both CLIs
walk up from the working directory hunting for git roots.

## Install a local app build

You do not need to launch from Xcode every time.

1. Open `AIUsageMenu.xcodeproj`.
2. **Product > Build**.
3. In the project navigator, open **Products**, right-click `AIUsageMenu.app`, choose **Show in Finder**.
4. Copy `AIUsageMenu.app` to `/Applications`.
5. Launch it. It appears in the menu bar as a chart icon — there is no Dock icon (`LSUIElement`). Its app icon, used by Control Center's menu bar list, is built from `docs/token-usage-logo.png`.

To launch it from Shortcuts, create a shortcut with the **Open App** action and choose `AIUsageMenu`.

### Signing

The project uses automatic signing with **no development team set**, so the first build on a new machine may ask you to pick one. In Xcode: select the `AIUsageMenu` target, open **Signing & Capabilities**, and choose your team — or "Sign to Run Locally" if you have no Apple developer account. You may also want to change `PRODUCT_BUNDLE_IDENTIFIER` from `com.zhuy9.AIUsageMenu` to your own reverse-DNS identifier.

The app is intentionally **not sandboxed**: it launches `claude` and `codex` and reads `~/Library/Application Support/`, neither of which a sandboxed app can do.

macOS may still ask to *"access files on a network volume"* on launch. Nothing here needs that — **Don't Allow** is the correct answer and the app works normally without it.

A local development build is fine for your own Mac. Sharing the binary with other people needs a signed and notarized build.

### Command line

```sh
xcodebuild -project AIUsageMenu.xcodeproj -scheme AIUsageMenu build
xcodebuild -project AIUsageMenu.xcodeproj -scheme AIUsageMenu test
```

## Troubleshooting

| Message | Cause | Fix |
|---|---|---|
| "Codex CLI not found." | `codex` is not on `PATH` or in the standard locations | Install Codex CLI, or symlink it into `/usr/local/bin` |
| "Codex is not logged in. Run codex login." | The app-server returned an error | `codex login` |
| "Codex usage request timed out." | `codex app-server` did not answer within 10s | Run `codex app-server --stdio` by hand to see what it does |
| "Claude Code CLI not found." | `claude` is not in `~/.local/bin`, Homebrew, `/usr/local/bin`, or on `PATH` | Install Claude Code, or symlink it into `/usr/local/bin` |
| "Claude usage request failed or timed out." | `claude` exited non-zero, or ran past 20s | Run `claude -p /usage` by hand to see what it says |
| "Send one Claude request to populate subscription usage." | `/usage` printed no plan lines — API-key auth, a third-party provider, or no completed turn yet | Confirm `claude -p /usage` shows "Current session:" in your terminal |
| "Claude usage could not be read." | `--output-format json` returned something unexpected | Check for a `claude` version change; the app parses the printed text |

A failed refresh never wipes a good reading — the last successful value stays on screen next to the message.

## Privacy and data

The app opens **no sockets of its own** and never touches Keychain, credentials, browser data,
prompts, or transcript contents. It does spawn `claude` and `codex`, which use their own logins and
may refresh their own usage data over the network — the app only reads what they print.

Everything it stores lives in `~/Library/Application Support/AIUsage/` (created `0700`):

| File | Written by | Contents |
|---|---|---|
| `claude-cache.json` | the app (`0600`) | Normalized Claude percentages and reset times only. |
| `codex-cache.json` | the app (`0600`) | Normalized Codex percentages and reset times only. |

Both files exist so the menu has something to show for the second or two before the first refresh
returns.

Provider on/off toggles are stored in `UserDefaults`.

To remove everything:

```sh
rm -rf "$HOME/Library/Application Support/AIUsage"
```

## Non-goals

No API billing or cost tracking, multiple accounts, history, charts, alerts, background service, login item, automatic updates, browser scraping, or App Store packaging.

## License

MIT — see [LICENSE](LICENSE).
