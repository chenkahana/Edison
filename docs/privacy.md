# Edison Privacy Policy

Effective November 12, 2026.

Edison is a clipboard manager and screenshot tool for the Mac. It is built so that your data stays yours: the
developer does not collect, see or sell any of it.

## What Edison stores, and where

- **Clipboard history**: text (including its original formatting), images, links, colours and file references you
  copy, plus the name of the app each came from and when.
- **Screenshots** you capture, and the edits you make to them.
- **Collections, favourites, settings and shortcuts.**

All of it is stored on your Mac, inside Edison's sandboxed container
(`~/Library/Containers/<Edison's bundle ID>/Data/Library/Application Support/Edison`). Nothing is synced or
uploaded.

## On-device intelligence

Edison labels items (text, code, terminal output, links, colours) and, on a Mac with Apple Intelligence turned on,
adds a few topic tags to text, using Apple's on-device language model (Foundation Models). This runs entirely on
your Mac: no item, label or tag is sent to Apple, the developer or anyone else, and Edison has no network code for
it. The labels and tags are stored with your history and deleted with it. Items marked concealed or transient are
never stored, so they are never analysed either. Turn it off in Settings › Intelligence.

## What Edison does not store

- Items that password managers and other apps mark as concealed or transient on the pasteboard.
- Anything you copy while clipboard history is paused (menu bar › Pause Clipboard History).
- Copies of file contents: for a copied file, Edison stores only its location.

## What Edison does not do

- No accounts, sign-in, analytics, advertising, tracking or crash-reporting services.
- No network connections, except the update check below. The app itself has no network entitlement.

## Updates

Copies installed from the DMG use [Sparkle](https://sparkle-project.org) to stay up to date. Sparkle asks before it
checks automatically. When it checks (once a day, or when you choose Check for Updates…), its sandboxed downloader
fetches `appcast.xml` from Edison's GitHub Releases, and downloads the new DMG if you choose to install it. The
request carries Edison's version, like any download, and nothing about your clipboard, screenshots or Mac.
GitHub sees your IP address, as for any visit. To turn automatic checks off, choose No when Sparkle asks, or run
`defaults write com.chenkahana.Edison SUEnableAutomaticChecks -bool NO`.
- No sale or sharing of data with anyone.

## Permissions

- **Accessibility** is used only to paste the item you chose into the app you were using.
- **Screen Recording** is used only when you start a capture.

## Your control

- Delete any item from the Hub (⌘⌫), or clear your history in Settings; deleting an item removes its files.
- Set how many items to keep in Settings › Storage & Privacy.
- Removing Edison and its container removes everything it stored.

## Changes

Changes to this policy are published in this file and noted in the [changelog](../CHANGELOG.md).

## Contact

Questions: open an [issue](https://github.com/chenkahana/Edison/issues). Security concerns: see
[SECURITY.md](../SECURITY.md).
