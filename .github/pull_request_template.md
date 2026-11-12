## What and why

<!-- What does this change, and what problem does it solve? Link the issue: "Fixes #123". -->

## How it was tested

- [ ] `swift build && swift test` pass
- [ ] Release build in Xcode passes (warnings are errors)
- [ ] Ran the app and exercised the change (Hub layouts, paste-back, editor, as relevant)
- [ ] Checked a second display, if windows, capture or the shelf changed

## Screenshots

<!-- Before and after, for UI changes. Don't include real clipboard content. -->

## Checklist

- [ ] One concern per pull request; no unrelated changes
- [ ] Stored clipboard text is never altered (display-only transforms stay in `UI`)
- [ ] Nothing new is logged, stored or sent that could contain clipboard or screenshot content
- [ ] VoiceOver labels, keyboard access, Reduce Transparency and Reduce Motion handled for new UI
- [ ] CHANGELOG.md updated under "unreleased" for user-visible changes
