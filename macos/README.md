# TGSPlayer for macOS

Native macOS build plan:

- `TGSPlayer.app` uses AppKit + WKWebView and the same light UI as Windows.
- `.tgs` files are registered through `CFBundleDocumentTypes`.
- Opening a `.tgs` from Finder calls `application(_:open:)`.
- Drag and drop is handled inside the WKWebView with `DecompressionStream`.
- Finder thumbnail previews are handled by `TGSQuickLook`, a Quick Look Thumbnail Extension.

## Build on macOS

Install dependencies:

```bash
brew install xcodegen
```

Build:

```bash
cd macos
chmod +x scripts/build-macos.sh
./scripts/build-macos.sh
```

Output:

```text
macos/dist/TGSPlayer.app
macos/dist/TGSPlayer.dmg
```

## Manual Test Checklist

1. Open `TGSPlayer.dmg` and copy `TGSPlayer.app` to `/Applications`.
2. Launch `TGSPlayer.app`; the start window should show the same Russian drag and drop UI.
3. Drag a `.tgs` into the window; it should open and autoplay.
4. Double-click a `.tgs` in Finder and choose TGSPlayer as the app.
5. Test `Space`, `F`, arrow keys, mouse wheel zoom.
6. In Finder, switch to icon/gallery view and check that `.tgs` thumbnail preview shows the sticker frame.
7. If Finder caches old previews, run:

```bash
qlmanage -r cache && qlmanage -r
```

Then reopen Finder.

