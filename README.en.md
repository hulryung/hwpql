# HWPQuickLook

![HWPQuickLook](assets/header.svg)

[한국어 버전](README.md)

A macOS **Quick Look plugin + standalone viewer app** for natively previewing Korean HWP documents. Select a `.hwp` or `.hwpx` file in Finder and press Space to render it instantly; double-click to open it in a dedicated window. Works without Hancom Office installed.

![Quick Look Preview](assets/screenshot.png)

## Features

- **Finder Quick Look preview** — Renders `.hwp` / `.hwpx` content instantly on Space (high-quality SVG output)
- **Finder thumbnails** — Shows preview images at icon size
- **Standalone viewer** — Double-click opens the file in a separate window, with Open Recent · Drag & Drop support
- **PDF export · printing** — Export (⇧⌘E) and print (⌘P) through rhwp's native PDF renderer
- **Zoom** — Trackpad pinch and ⌘+ / ⌘− / ⌘0 (0.25×–3.0×)
- **Hancom-native UTI** — Claims `LSHandlerRank=Owner`, so it takes priority even when Hancom Office is installed
- **Notarized Developer ID signing** — No Gatekeeper warnings on install or launch

## Relationship with rhwp

All HWP/HWPX parsing and page rendering is done by the Rust crate [rhwp](https://github.com/edwardkim/rhwp). This repository is a **native macOS frontend** layered on top of it:

- `rhwp-ffi/` — A thin Rust wrapper that exposes rhwp through a C ABI. rhwp is pinned to a specific commit for reproducible builds.
- The Swift side calls only three functions — `hwp_parse_to_html`, `hwp_get_preview_image`, and `hwp_render_pdf` — to receive SVG-based HTML, the embedded preview image, and PDF output.
- The Quick Look preview, the Finder thumbnail, and the standalone viewer all consume the same FFI output.

In other words, parsing quality and coverage are determined by the rhwp version, while HWPQuickLook integrates those results into Quick Look, Finder, and a viewer window on macOS.

## Install

### Homebrew (recommended)

```bash
brew install --cask hulryung/tap/hwpquicklook
```

### DMG (latest release)

1. Download `HWPQuickLook-vX.Y.Z.dmg` from the [Releases](https://github.com/hulryung/hwpql/releases) page
2. Open the DMG and drag `HWPQuickLook.app` into the `Applications` folder
3. Select a `.hwp` file in Finder and press Space to verify

The app is notarized, so it runs without the "unidentified developer" warning.

## Requirements

- macOS 12.0 (Monterey) or later
- Apple Silicon and Intel are both supported

## Development / Building

For build instructions, the release pipeline (sign + notarize + DMG), rhwp version updates, the project layout, and troubleshooting, see [DEVELOPMENT.md](DEVELOPMENT.md). (Korean only for now.)

## License

MIT
