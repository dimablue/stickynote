#!/bin/zsh
set -euo pipefail

PROJECT_DIR="${0:A:h:h}"
APP_DIR="$PROJECT_DIR/dist/Sticky Notes.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"

cd "$PROJECT_DIR"
swift build -c release

mkdir -p "$MACOS_DIR"
cp "$PROJECT_DIR/.build/release/StickyNotes" "$MACOS_DIR/StickyNotes"
cp "$PROJECT_DIR/Resources/Info.plist" "$CONTENTS_DIR/Info.plist"
chmod +x "$MACOS_DIR/StickyNotes"
codesign --force --deep --sign - "$APP_DIR"

echo "$APP_DIR"
