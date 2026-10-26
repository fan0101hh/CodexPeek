# CodexPeek

A compact native macOS floating window for viewing remaining Codex subscription quotas for all accounts with usable sign-in credentials, with the current account first. Built with SwiftUI, AppKit and Foundation; no third-party dependencies or background Codex processes.

Requires macOS 13+ and a Swift 6.0+ toolchain.

To install, open `CodexPeek.dmg` and drag the complete app into the Applications shortcut. Quit the older version and launch the installed app from Finder. Preferences remain outside the app bundle. Build the DMG with `bash scripts/build-dmg.sh`; this does not automatically install or launch the app.

```bash
swift run CodexPeekChecks
bash scripts/build-app.sh
open dist/CodexPeek.app
```

Use `swift run CodexPeek --demo` for synthetic data or `swift run CodexPeek --diagnose` for an opt-in, redacted live check.

The app reads `~/.cc-switch/codex-login-stash.json` for saved subscriptions and `~/.codex/auth.json` for the current account. Both paths are configurable. It never changes source credentials or refreshes shared refresh tokens. Expired or confirmed unauthorized accounts are hidden until credentials are updated through the original tool. Network failures and rate limits do not hide accounts. Keychain-only authentication is not supported in v1.

The default 300 pt wide window shows two square quota bars per account: solid remaining portions and dotted used portions, with remaining percentages and local reset labels. It grows with the account count and scrolls when content exceeds its height. At widths of 500 pt or more, reset labels appear inline; narrow layouts put them below the bars. Its background is 85% transparent by default and can be made fully transparent in settings. Drag the small bar at the top to move the window, or the bottom-right grip to resize it. Dimensions persist; the details panel can restore automatic sizing. Account rows are display-only. Open Account & Settings from the menu bar to edit aliases and preferences. The panel opens below the menu bar icon and does not reveal a hidden floating window. Default polling is five seconds, with failure backoff and sleep suspension. Source metadata is checked once per second. Server-side usage may update less frequently.

Queries use an internal Codex HTTPS usage endpoint, isolated behind a replaceable provider. Compatibility is not guaranteed. Requests use an ephemeral URLSession, reject redirects and never write credentials or response bodies to logs or disk. All displayed accounts are queried with at most three concurrent requests, ordered by due time. Large account lists can take longer than the configured refresh interval.

Builds are locally ad-hoc signed, not notarized. The default build merges arm64 and x86_64 into one universal executable. `CODEXPEEK_ARCH=arm64` or `x86_64` selects a single architecture. Public source visibility does not grant a license; no LICENSE is included.

See the [Chinese README](README.md), [architecture](docs/architecture.md), [development notes](docs/development.md) and [security](docs/security.md).
