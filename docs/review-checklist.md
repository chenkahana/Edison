# Review Checklist

## Merge requirements
- [ ] CI is green (`swift build` + `swift test` on macOS)
- [ ] No compile/test regressions
- [ ] No dead placeholders/imports breaking build

## Core flow checks
- [ ] Hub opens from menu bar/hotkey
- [ ] Clipboard items appear, can be searched, favorited, and recopied
- [ ] Screenshot flow opens editor immediately with captured image

## Quality checks
- [ ] No crashes in normal flow
- [ ] No obvious UI blocking on large image history
- [ ] No scope creep beyond active task
- [ ] Docs/tasks updated when scope/status changes
