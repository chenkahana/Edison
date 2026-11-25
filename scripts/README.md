# Scripts

| Script | What it does |
|---|---|
| [`ci-local-macos.sh`](ci-local-macos.sh) | Runs the same `swift build` and `swift test` steps as CI, on your Mac |
| [`release-dmg.sh`](release-dmg.sh) | Builds, notarizes and publishes `Edison.dmg` and its update feed from a maintainer's Mac, the fallback to the release workflow. See [docs/release.md](../docs/release.md) |
| [`set-release-secrets.sh`](set-release-secrets.sh) | Gives the release workflow its signing secrets, from the maintainer's Mac. See [docs/release.md](../docs/release.md) |
| [`developer-id.py`](developer-id.py) | Finds, installs or creates the Developer ID certificate through the App Store Connect API, for the release workflow and `set-release-secrets.sh` |
| [`inspect-pasteboard.swift`](inspect-pasteboard.swift) | Prints metadata (type order, byte counts, SHA-256) for whatever is on the pasteboard, never its content. See [the fixture workflow](../docs/pasteboard-fixture-workflow.md) |

```bash
./scripts/ci-local-macos.sh
```

```bash
swift scripts/inspect-pasteboard.swift --help
```
