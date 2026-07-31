# Sticky Notes

A native, local-first macOS sticky-notes app built from the product specification in
[`sticky-notes-app-design.md`](sticky-notes-app-design.md).

## Requirements

- macOS 14 or newer
- Xcode 15.3 or newer

## Run while developing

```sh
swift run StickyNotes
```

## Build an app bundle

```sh
./scripts/build-app.sh
open "dist/Sticky Notes.app"
```

The build script creates an ad-hoc signed app at `dist/Sticky Notes.app`.

## Data

Notes are autosaved locally at:

```text
~/Library/Application Support/Sticky Notes/notes.json
```

Window positions and preferences use macOS `UserDefaults`. No account or network
connection is used.

## Implemented MVP

- Always-on-top floating note stack with persistent position
- Menu-bar entry point and stack switcher
- Plain-text autosave with empty-note cleanup
- Note creation, deletion, navigation, and note switcher
- Fuzzy search within one stack and across the Library
- Library stack creation, renaming, deletion, and most-recent sorting
- Keyboard shortcuts from the specification
- Minimal preferences for login, Dock visibility, full-screen behavior, and deletion confirmation
