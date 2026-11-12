# Scripts

| Script | What it does |
|---|---|
| [`ci-local-macos.sh`](ci-local-macos.sh) | Runs the same `swift build` and `swift test` steps as CI, on your Mac |
| [`release-dmg.sh`](release-dmg.sh) | Builds, notarizes and publishes `Edison.dmg` and its update feed on GitHub Releases. See [docs/release.md](../docs/release.md) |
| [`inspect-pasteboard.swift`](inspect-pasteboard.swift) | Prints metadata (type order, byte counts, SHA-256) for whatever is on the pasteboard, never its content. See [the fixture workflow](../docs/pasteboard-fixture-workflow.md) |

```bash
./scripts/ci-local-macos.sh
```

```bash
swift scripts/inspect-pasteboard.swift --help
```
