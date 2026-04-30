#!/bin/sh
set -eu

ROOT_DIR="${SRCROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
CONFIG_FILE="$ROOT_DIR/.swift-format"

xcrun swift-format lint \
    --configuration "$CONFIG_FILE" \
    --recursive \
    --strict \
    "$ROOT_DIR/Apps/Probe/Sources" \
    "$ROOT_DIR/Apps/ProbeTests" \
    "$ROOT_DIR/Packages/ProbeCore/Sources" \
    "$ROOT_DIR/Packages/ProbeCore/Tests"
