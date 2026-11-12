# Third-party notices

Edison is built on Apple's macOS SDK frameworks (SwiftUI, AppKit, ScreenCaptureKit, Core Graphics, Core Image,
Quartz, Carbon and OSLog), which are licensed to developers under the Apple Developer Agreement and are not
redistributed in this repository. Its one third-party dependency is listed below.

Interface icons are [SF Symbols](https://developer.apple.com/sf-symbols/), used under Apple's SF Symbols license
terms; they are rendered by the system at run time and are not included as files.

## Sparkle

- Use: installing updates for copies downloaded from GitHub Releases (linked by the "Edison DMG" target only; the App
  Store build and `swift build` don't include it)
- Source: https://github.com/sparkle-project/Sparkle
- License: MIT. Sparkle also contains bsdiff 4.3 (Colin Percival), sais-lite (Yuta Mori), Ed25519 (Orson Peters)
  and SUSignatureVerifier (Mark Hamlin) under their own permissive licenses, whose full texts are in
  [Sparkle's LICENSE](https://github.com/sparkle-project/Sparkle/blob/2.10.1/LICENSE).

```
Copyright (c) 2006-2013 Andy Matuschak.
Copyright (c) 2009-2013 Elgato Systems GmbH.
Copyright (c) 2011-2014 Kornel Lesiński.
Copyright (c) 2015-2017 Mayur Pawashe.
Copyright (c) 2014 C.W. Betts.
Copyright (c) 2014 Petroules Corporation.
Copyright (c) 2014 Big Nerd Ranch.
All rights reserved.

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated
documentation files (the "Software"), to deal in the Software without restriction, including without limitation the
rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit
persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the
Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE
WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR
OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
```

If you add a dependency, list it here with its use, source, license and copyright notice, and get it agreed in an
issue first (see [CONTRIBUTING.md](CONTRIBUTING.md)).
