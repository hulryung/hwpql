# HWPQuickLook

macOS Quick Look plugin for HWP (한글) documents. Press Space in Finder to preview `.hwp` and `.hwpx` files.

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
- Rust toolchain (for building `libhwp_ffi.a`)
- [hwpjs](https://github.com/ohah/hwpjs) repository cloned alongside this project

## Build

### 1. Build the Rust static library

```bash
./scripts/build-rust.sh
```

Or manually:

```bash
cd ../hwpjs
cargo build --release -p hwp-ffi
cp target/release/libhwp_ffi.a ../hwpql/libs/
```

### 2. Build the Xcode project

```bash
xcodebuild -project HWPQuickLook.xcodeproj -scheme HWPQuickLook -configuration Release build
```

### 3. Install

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

## License

MIT
