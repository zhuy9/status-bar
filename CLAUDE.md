# Implementation notes

Follow `/Users/darren/Downloads/AI_Usage_Menu_MVP_Design.md`. Do not expand scope: use SwiftUI and Foundation only; no API client, credential access, browser scraping, database, daemon, file watcher, settings, charts, notifications, or third-party packages.

After each implementation step, compile and run the focused tests:

```sh
xcodebuild -project AIUsageMenu.xcodeproj -scheme AIUsageMenu build
xcodebuild -project AIUsageMenu.xcodeproj -scheme AIUsageMenu test
```

Keep `AGENTS.md` as a relative symlink to this file.
