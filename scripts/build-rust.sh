#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
RHWP_DIR="$(cd "$PROJECT_DIR/../rhwp" && pwd)"
OUTPUT_DIR="$PROJECT_DIR/libs"
CARGO="${CARGO:-/opt/homebrew/bin/cargo}"

echo "Building rhwp-ffi static library..."
echo "RHWP_DIR: $RHWP_DIR"
echo "OUTPUT_DIR: $OUTPUT_DIR"

mkdir -p "$OUTPUT_DIR"

cd "$RHWP_DIR"

echo "Building for native architecture..."
$CARGO build --release -p rhwp-ffi

cp target/release/librhwp_ffi.a "$OUTPUT_DIR/libhwp_ffi.a"

echo "Done!"
echo "Static library: $OUTPUT_DIR/libhwp_ffi.a"
ls -la "$OUTPUT_DIR/libhwp_ffi.a"
