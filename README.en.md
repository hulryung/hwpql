# HWPQuickLook

[한국어 버전](README.md)

A macOS **Quick Look plugin + standalone viewer app** for natively previewing Korean HWP documents. Select a `.hwp` or `.hwpx` file in Finder and press Space to render it instantly; double-click to open it in a dedicated window. Works without Hancom Office installed.

![Quick Look Preview](assets/screenshot.png)

## Features

- **Finder Quick Look preview** — Renders `.hwp` / `.hwpx` content instantly on Space (high-quality SVG output)
- **Finder thumbnails** — Shows preview images at icon size (uses the HWP's embedded preview)
- **Standalone viewer** — Double-click opens the file in a separate WebView window
- **Hancom-native UTI support** — Uses `com.haansoft.hancomofficeviewer.mac.hwp/hwpx` with `LSHandlerRank=Owner` for priority
- **Notarized Developer ID signing** — No Gatekeeper warnings on install or launch

## How It Works

HWP and HWPX files are parsed by the Rust-based [rhwp](https://github.com/edwardkim/rhwp) crate. The Swift side calls the following functions via C FFI:

- `hwp_parse_to_html(data)` → Returns HTML wrapping page-level SVG renderings (preview + standalone viewer)
- `hwp_get_preview_image(data)` → Extracts the embedded preview image (Finder thumbnail)

The preview extension (`HWPPreviewer.appex`) returns HTML in a `QLPreviewReply` for the system Quick Look panel. The thumbnail extension (`HWPThumbnailer.appex`) returns the image in a `QLThumbnailReply`. The standalone viewer (`HWPQuickLook.app`) receives the open-file event and loads the HTML into a `WKWebView`.

> **Note (v0.3.0+)**: The parsing engine switched from `hwpjs` to `rhwp`. FFI signatures are compatible, so there is no behavior change for users. The standalone viewer was also rewritten using a SwiftUI + AppKit hybrid structure for more reliable file routing.

## Install

### Homebrew (recommended)

```bash
brew install hulryung/tap/hwpquicklook
```

(There may be a small delay before the tap picks up a new release. For the absolute latest, use the DMG below.)

### DMG (latest release)

1. Download `HWPQuickLook-vX.Y.Z.dmg` from the [Releases](https://github.com/hulryung/hwpql/releases) page
2. Open the DMG and drag `HWPQuickLook.app` into the `Applications` folder
3. Select a `.hwp` file in Finder and press Space to verify

The app is notarized, so it runs without the "unidentified developer" warning.

## Requirements

- macOS 12.0 (Monterey) or later
- Apple Silicon and Intel are both supported

## Build from Source

Xcode 15 or later is required.

```bash
xcodebuild -project HWPQuickLook.xcodeproj -scheme HWPQuickLook -configuration Release build
```

To reflect changes in the system, copy the built app to `/Applications` and reset the Quick Look caches.

```bash
cp -R ~/Library/Developer/Xcode/DerivedData/HWPQuickLook-*/Build/Products/Release/HWPQuickLook.app /Applications/
qlmanage -r && qlmanage -r cache
```

A pre-built `libhwp_ffi.a` is included in `libs/`, so rebuilding the Rust library is usually not needed.

## Release Build (sign + notarize + DMG)

The full release pipeline is automated in `scripts/release.sh`.

```bash
bash scripts/release.sh
```

Steps performed:
1. Xcode Release build
2. Submit `.app` for notarization → Accepted → staple
3. Create DMG with `hdiutil` (includes an `/Applications` symlink)
4. Sign the DMG with Developer ID (secure timestamp)
5. Notarize the DMG → staple → verify with `spctl`

Output: `build/HWPQuickLook-vX.Y.Z.dmg`

### First-time setup

You must pre-store a `notarytool` keychain profile:

```bash
xcrun notarytool store-credentials "HWPQuickLook" \
  --apple-id <your-apple-id> \
  --team-id <your-team-id> \
  --password <app-specific-password>
```

Override the profile name with the `NOTARY_PROFILE` environment variable (default: `HWPQuickLook`).

## Rebuilding the Rust Library

Required only when modifying the [rhwp](https://github.com/edwardkim/rhwp) repository or updating to a newer version.

### Requirements

- [Rust toolchain](https://rustup.rs/)
- [rhwp](https://github.com/edwardkim/rhwp) cloned into the same parent directory as this project

### Using the script

```bash
git clone https://github.com/edwardkim/rhwp.git ../rhwp
./scripts/build-rust.sh
```

### Manual build

```bash
cd ../rhwp
cargo build --release -p rhwp-ffi
cp target/release/librhwp_ffi.a ../hwpql/libs/libhwp_ffi.a
```

## Project Structure

```
HWPQuickLook/              # Standalone viewer app (SwiftUI + AppKit, UTI registration host)
├── Assets.xcassets/       # AppIcon and other resources
├── AppDelegate.swift      # SwiftUI App + NSApplicationDelegate
└── Info.plist             # UTI declarations and Document Types

HWPPreviewer/              # Quick Look preview extension (.appex)
├── PreviewProvider.swift  # QLPreviewProvider implementation
└── Info.plist             # QLSupportedContentTypes

HWPThumbnailer/            # Finder thumbnail extension (.appex)
├── ThumbnailProvider.swift
└── Info.plist

Shared/BridgingHeader.h    # Rust FFI declarations (hwp_parse_to_html, etc.)
libs/libhwp_ffi.a          # rhwp static library (pre-built, arm64 + x86_64)

scripts/
├── build-rust.sh          # Build the rhwp-ffi crate
├── make-icon.swift        # Programmatic app icon generation (CoreGraphics)
└── release.sh             # Release pipeline (sign + notarize + DMG)
```

## Testing & Troubleshooting

### Manual preview / thumbnail check

```bash
# Quick Look preview
qlmanage -p ~/path/to/file.hwp

# Thumbnail (the -x flag is required to force the modern QLThumbnailProvider extension)
qlmanage -t -x -s 512 -o /tmp ~/path/to/file.hwp
```

Finder invokes the extension automatically — no `-x` flag needed.

### Changes not visible in Finder after install

Rebuild the Launch Services / Quick Look caches and restart Finder.

```bash
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
  -kill -r -domain local -domain system -domain user
qlmanage -r && qlmanage -r cache
killall Finder
```

### UTI conflict with Hancom Office

If Hancom Office is installed, it may compete for the same UTI. HWPQuickLook claims `LSHandlerRank=Owner`, but if you removed Hancom Office and it still takes effect, empty the Trash and rebuild the Launch Services database.

## License

MIT
