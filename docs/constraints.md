# Constraints

## Hard product constraints
- Private by default
- Local-first storage
- Keyboard-first UX
- Instant invoke from menu bar/hotkey
- Speed over completeness
- Native-first macOS app
- No backend/cloud in MVP

## Engineering rules
- SwiftUI first; AppKit only where needed
- Keep current module boundaries unless blocked
- No new architecture layers without clear need
- Prefer simple persistence over heavy data tech
- Avoid over-engineering

## Product boundaries
- Accessibility permission is optional and only for optional direct-paste behavior
- Permissions must be explicit and minimal
- Clipboard + screenshots must live in one unified history

## Do not build (MVP)
- Accounts/payments
- Sync/upload links
- Collaboration
- AI/OCR
