# HWPQuickLook

macOS Quick Look plugin for HWP (한글) documents. Press Space in Finder to preview `.hwp` and `.hwpx` files.

![Quick Look Preview](assets/screenshot.png)

## How It Works

HWP files are parsed and rendered as HTML using the [hwp-core](https://github.com/ohah/hwpjs) Rust library via C FFI. The Quick Look extension receives the file data, calls `hwp_parse_to_html()`, and returns the resulting HTML to the system for display.

## Project Structure

```
HWPQuickLook/          # Host app (registers UTI types for .hwp/.hwpx)
HWPPreviewer/          # Quick Look preview extension (.appex)
HWPThumbnailer/        # Thumbnail extension (.appex)
Shared/BridgingHeader.h  # C FFI declarations
libs/                  # Pre-built static library (libhwp_ffi.a)
scripts/build-rust.sh  # Script to rebuild the static library
```

## Requirements

- macOS 13.0+
- Xcode 15+

## Build

```bash
xcodebuild -project HWPQuickLook.xcodeproj -scheme HWPQuickLook -configuration Release build
```

Pre-built `libhwp_ffi.a` is included in `libs/`. To rebuild it from source, see [Rebuilding the Rust library](#rebuilding-the-rust-library).

### Install

Copy the built app to `/Applications`:

```bash
cp -R ~/Library/Developer/Xcode/DerivedData/HWPQuickLook-*/Build/Products/Release/HWPQuickLook.app /Applications/
```

Then reset Quick Look caches:

```bash
qlmanage -r
qlmanage -r cache
```

## Testing

```bash
qlmanage -p ~/path/to/file.hwp
```

## Rebuilding the Rust library

Requires Rust toolchain and [hwpjs](https://github.com/ohah/hwpjs) cloned alongside this project.

```bash
./scripts/build-rust.sh
```

## License

MIT
