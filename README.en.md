# CodexPeek

A compact native macOS floating window for viewing remaining Codex subscription quotas for up to two accounts. Built with SwiftUI, AppKit and Foundation; no third-party dependencies or background Codex processes.

Requires macOS 13+ and a Swift 6.0+ toolchain.

```bash
swift run CodexPeekChecks
bash scripts/build-app.sh
open dist/CodexPeek.app
```

Use `swift run CodexPeek --demo` for synthetic data or `swift run CodexPeek --diagnose` for an opt-in, redacted live check.

The app reads `~/.cc-switch/codex-login-stash.json` for saved subscriptions and `~/.codex/auth.json` for the current account. Both paths are configurable. It never changes source credentials or refreshes shared refresh tokens. Expired accounts require sign-in through the original tool. Keychain-only authentication is not supported in v1.

The 212 × 64 pt capsule shows remaining five-hour and weekly percentages. Click for account selection, aliases, reset times and settings. Default polling is five seconds, with failure backoff and sleep suspension. Source metadata is checked once per second. Server-side usage may update less frequently.

Queries use an internal Codex HTTPS usage endpoint, isolated behind a replaceable provider. Compatibility is not guaranteed. Requests use an ephemeral URLSession, reject redirects and never write credentials or response bodies to logs or disk. Only selected accounts are queried.

Builds are locally ad-hoc signed, not notarized. The default build merges arm64 and x86_64 into one universal executable. `CODEXPEEK_ARCH=arm64` or `x86_64` selects a single architecture. Public source visibility does not grant a license; no LICENSE is included.

See the [Chinese README](README.md), [architecture](docs/architecture.md), [development notes](docs/development.md) and [security](docs/security.md).
