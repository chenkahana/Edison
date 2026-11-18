# R0 Baseline

Base: `origin/main` `f59abfe` (7 commits after tag `v2.1`, none touching app UI code: README, CI, Sparkle exclusion
for the App Store build, agent-file ignores). Raw logs live outside git in `~/tmp/codex/edison-craft/`.

## R0.1 Build and run

| Check | Result | Evidence |
|---|---|---|
| `swift build` (debug) | Pass, 22 s, 0 warnings | `~/tmp/codex/edison-craft/swift-build.log` |
| `swift test` | Pass, 44 tests in 10 suites | `~/tmp/codex/edison-craft/swift-test.log` |
| Installed copy | `/Applications/Edison - Clipboard Manager.app`, `com.chenkahana.Edison`, `CFBundleShortVersionString` 2.0, build 4, dated 2026-11-12, running (pid 27866) | `defaults read .../Info`, `pgrep` |
| Live run of a fresh build | **Not run: needs Chen session** (see below) | |

The installed build 4 matches the `v2.1` UI code, so observations of the installed app are representative of
`origin/main`. Its marketing version still reads 2.0 although `CHANGELOG.md` and the tag say 2.1
(`Edison.xcodeproj/project.pbxproj` `MARKETING_VERSION = 2.0`): an About/Settings version mismatch to check in R2.

### Why no live run in this pass

Chen's copy is running. A second Edison would register the same Carbon hotkeys (⇧⌘V and the capture keys), poll
the same pasteboard into a second history, and need its own Screen Recording and Accessibility grants. Driving the
Hub means sending global keystrokes into Chen's active session, which `~/.codex/memories/lessons.md` (2026-11-14)
forbids without checking the frontmost window. Every runtime step below is therefore written as an exact script for
a Chen session, and R2 findings from this pass carry code evidence (`file:line`) plus a "verify live" note.

### Needs Chen session: runtime capture script

Prereqs: a quiet desktop, Light then Dark appearance, ProMotion built-in display plus one external display.

1. Quit nothing. Use the installed app (build 4 = `v2.1` UI). Record with ⇧⌘5 → Record Entire Screen (or
   QuickTime at 120 Hz on the built-in display). Save to `~/tmp/codex/edison-craft/rec/<flow>-<light|dark>-<display>.mov`.
2. Flows, one recording each (see R0.3 table for the exact steps per flow).
3. Instruments: `xcrun xctrace record --template 'Animation Hitches' --attach 'Edison - Clipboard Manager' --time-limit 20s --output ~/tmp/codex/edison-craft/trace/hub-summon.trace`
   while pressing ⇧⌘V / Esc ten times; repeat with `Time Profiler` for search (type 20 characters) and
   `Allocations` for scrolling 250 items, and for one area capture.
