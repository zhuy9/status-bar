# Implementation notes

Follow the MVP design in [README.md](README.md). Do not expand scope: SwiftUI and Foundation only, plus `Process` calls to the provider CLIs. No API client, credential access, browser scraping, database, daemon, file watcher, charts, notifications, or third-party packages.

After each implementation step, compile and run the focused tests:

```sh
xcodebuild -project AIUsageMenu.xcodeproj -scheme AIUsageMenu build
xcodebuild -project AIUsageMenu.xcodeproj -scheme AIUsageMenu test
```

Keep `AGENTS.md` as a relative symlink to this file.
