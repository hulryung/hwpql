#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
HWPJS_DIR="$(cd "$PROJECT_DIR/../hwpjs" && pwd)"
OUTPUT_DIR="$PROJECT_DIR/libs"
CARGO="${CARGO:-/opt/homebrew/bin/cargo}"

echo "Building hwp-ffi static library..."
echo "HWPJS_DIR: $HWPJS_DIR"
echo "OUTPUT_DIR: $OUTPUT_DIR"

mkdir -p "$OUTPUT_DIR"

cd "$HWPJS_DIR"

echo "Building for native architecture..."
$CARGO build --release -p hwp-ffi

cp target/release/libhwp_ffi.a "$OUTPUT_DIR/libhwp_ffi.a"

echo "Done!"
echo "Static library: $OUTPUT_DIR/libhwp_ffi.a"
ls -la "$OUTPUT_DIR/libhwp_ffi.a"
