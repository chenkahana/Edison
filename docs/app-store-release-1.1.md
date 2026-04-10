# Edison 1.1 App Store Release Packet

Use this document as the source of truth for App Store Connect submission notes, release text, and the reviewer screen-recording checklist for Edison 1.1.

## App Review Notes Template

Edison is a native macOS menu bar app for people who frequently copy text, files, and images and want to find and reuse them quickly. It combines clipboard history, screenshot capture, and lightweight image editing in a single keyboard-first utility. The core value is simple: capture or copy once, find it later instantly, and reuse it in seconds.

There is no account system, no login, no registration flow, no account deletion flow, no paid content, no subscriptions, and no in-app purchases. There is no user-generated content sharing, no reporting or blocking system, and no external backend, AI provider, payment processor, or authentication platform required for the app's core functionality.

### Reviewer Access and Main Feature Flow

1. Launch Edison.
2. Click the menu bar icon and choose `Open Hub`, or press `Cmd-Shift-V`.
3. Copy some text or an image in any other macOS app, then return to Edison and confirm it appears in the unified history.
4. Use search, favorites, collections, and keyboard navigation in the hub to browse items.
5. Select an item and use the copy/share/export actions.
6. Trigger screenshot capture from the menu bar or with the default shortcuts:
   - `Cmd-Shift-2` — Capture Area
   - `Cmd-Shift-3` — Capture Window
   - `Cmd-Shift-4` — Capture Full Screen
7. After capture, confirm the screenshot opens in the editor, then use copy, save, or share from the editor flow.

### Permissions and Capability Prompts

- Screen Recording:
  Edison may prompt for Screen Recording permission the first time a screenshot feature is used. This permission is required only for screenshot capture features.
- Accessibility:
  Edison may require Accessibility permission only for the optional "return/paste selected item back into the previously active app" workflow. If Accessibility permission is not granted, Edison still copies the selected item to the clipboard and the reviewer can paste it manually.

### External Services

Edison does not depend on external services, data providers, payment processors, authentication services, or AI platforms to deliver its core functionality.

### Regional Availability

Edison functions consistently across all regions. There are no regional feature differences, content differences, or country-specific service dependencies.

### Regulated Industry Status

Edison is not a regulated-industry app and does not provide financial, medical, legal, or other licensed services.

## Physical Mac Recording Checklist

Record on a physical Mac and begin at launch. Capture the full flow in one continuous recording if possible.

1. Launch Edison from the app bundle.
2. Show the menu bar icon and open the hub from the menu bar.
3. Close and reopen the hub with `Cmd-Shift-V`.
4. Copy text in another app, return to Edison, and show the new clipboard item in history.
5. Search for the copied item, select it, and show copy/share/export actions.
6. Favorite an item and, if useful, add it to a collection.
7. Trigger `Capture Area` from the menu bar and show the system Screen Recording permission prompt if it appears.
8. Complete a screenshot capture and show the editor opening immediately.
9. In the editor, demonstrate at least copy plus one of save/share.
10. If Accessibility permission is available, demonstrate the "paste selected item back" flow; otherwise, mention that manual paste remains available without the permission.

## What's New in 1.1

Edison 1.1 refines the menu bar workflow, improves release readiness, and makes the app easier to review and use out of the box. This update adds direct menu bar commands for area, window, and full-screen capture, improves About information, and packages Edison for App Store submission as a polished productivity release.
