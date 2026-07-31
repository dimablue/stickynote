# Sticky Notes App — Product and Interaction Design Specification

## 1. Product Summary

Build an extremely lightweight macOS sticky-notes app centered on one simple interaction:

> Keep a small stack of notes persistently visible above other windows, then expand it only when broader organization is needed.

The app has two surfaces:

1. **Floating Stack** — a small always-on-top note window for writing and switching between notes in one stack.
2. **Library View** — a larger window for switching between stacks and managing the notes inside them.

The product should feel closer to a physical pad of sticky notes than a full productivity suite. It should open quickly, save automatically, stay out of the way, and contain no decorative motion or unnecessary features.

---

## 2. Product Principles

### 2.1 Lightweight first

- Launch quickly.
- Use little memory and CPU while idle.
- Avoid background work beyond persistence and basic menu-bar behavior.
- Prefer native macOS controls and window behavior.
- No custom animations or transitions.

### 2.2 Always available, never demanding

- The floating stack stays above ordinary application windows.
- It must not block interaction with other apps outside its visible bounds.
- It should remain where the user placed it across launches.
- Hiding it should remove it completely from the desktop until reopened.

### 2.3 Minimal visible interface

- Keep controls compact and recognizable.
- Do not show permanent side tabs, floating launchers, badges, or extra desktop decorations.
- The menu-bar icon is the reliable home base when the floating stack is hidden.

### 2.4 Local and immediate

- Notes save automatically as the user types.
- No manual Save button.
- MVP data is stored locally.
- No account, sync, collaboration, or cloud dependency.

---

## 3. Terminology

Use the following terms consistently in the UI and codebase:

- **Note** — one editable plain-text page.
- **Stack** — a named collection of notes, such as “CS 162,” “Project Ideas,” or “Personal.”
- **Floating Stack** — the compact always-on-top window showing one active note from one stack.
- **Library** — the expanded management view containing the stack sidebar and large note editor.

Do not use “session” in the user-facing UI. “Stack” better communicates that the collection persists over time.

---

## 4. MVP Scope Decisions

The first version should make the following firm choices:

- macOS only.
- One floating stack visible at a time.
- Multiple saved stacks available through the menu bar and Library.
- Plain text only.
- No text-formatting toolbar.
- No custom animations.
- No persistent edge tab.
- Menu-bar app behavior is required.
- The app may be hidden from the Dock by default.
- Notes are ordered by creation order.
- Manual note reordering is not included.
- Stacks are ordered by most recently edited.

---

## 5. Floating Stack

### 5.1 Purpose

The Floating Stack is the primary everyday interface. It is used for quickly writing, reviewing, and moving between notes without opening a full application window.

### 5.2 Default appearance

Recommended default size:

- Width: approximately 300–340 px
- Height: approximately 300–360 px
- Minimum size: fixed for MVP
- Optional later enhancement: user resizing within a limited range

The window should resemble a simple sticky note, but it should not overcommit to skeuomorphism. Use a subtle paper-like background, restrained border or shadow, and compact controls.

A few slightly offset sheets may be visible behind the active note to communicate “stack,” but they are decorative only. Do not render one visible layer per note.

### 5.3 Layout

```text
┌─────────────────────────────────────┐
│ ×    ⤢    ⌕          Edited Jul 30  │
│                                     │
│ Note text begins here...            │
│                                     │
│                                     │
│ +                           ‹ 6/10 › │
└─────────────────────────────────────┘
```

### 5.4 Window behavior

- The window remains above normal application windows.
- Clicking another application does not hide or move it.
- The user can still interact normally with all uncovered portions of other windows.
- The user can drag the Floating Stack using empty space in the top bar.
- The app stores its position and restores it on relaunch.
- If the saved position is no longer visible because a monitor was disconnected, place it fully inside the current main display.
- Hiding the Floating Stack removes it completely from the desktop. No edge tab remains.

### 5.5 Top-left controls

The Floating Stack contains three controls:

#### Hide — `×`

- Hides the Floating Stack.
- Does not delete the stack or quit the app.
- The stack remains available through the menu-bar icon.
- Keyboard shortcut: `Command-W`.

#### Expand — `⤢`

- Opens the Library focused on the current stack and active note.
- The Floating Stack may remain visible or hide when Library opens. For MVP, hide it while Library is open to avoid duplicate editors for the same note.
- Keyboard shortcut: `Command-Shift-E`.

#### Search — `⌕`

- Opens search scoped to the current stack.
- Search should be keyboard-first.
- Keyboard shortcut: `Command-F`.

Do not include a separate minimize control. Hiding plus the menu-bar icon already covers the use case without introducing an unclear distinction between “close” and “minimize.”

### 5.6 Date display

The top-right displays:

`Edited Jul 30`

Behavior:

- It updates after edits are persisted.
- Clicking it opens a small popover containing:
  - `Created July 27, 2026`
  - `Last edited July 30, 2026`
- The app stores only creation time and latest edit time.
- Do not implement edit history or revision tracking.

### 5.7 Note editor

- Plain-text editing.
- Multiline input.
- Standard macOS text selection, undo, redo, copy, paste, and spelling behavior.
- Autosave shortly after typing stops, and immediately when changing notes, hiding the window, or quitting.
- The first nonempty line serves as the note’s generated preview title elsewhere in the app.
- There is no explicit title field.
- Preserve whitespace and line breaks.

### 5.8 Bottom-left new-note control

A compact `+` button creates a new note in the current stack.

Behavior:

- Create the note immediately and make it active.
- Append it to the end of the stack.
- Focus the editor.
- If the note remains completely empty and the user navigates away, closes the window, or quits, discard it automatically.

Keyboard shortcut: `Command-N` creates a note in the current stack.

### 5.9 Note navigation

The bottom-right contains:

`‹ 6/10 ›`

Behavior:

- `‹` moves to the previous note.
- `›` moves to the next note.
- Navigation stops at the first and last note; do not wrap in MVP.
- Disabled arrows should appear visibly inactive.
- Clicking `6/10` opens the Note Switcher.
- Left and right arrow shortcuts should work only when the editor is not actively using them for text navigation. Prefer `Command-Left Bracket` and `Command-Right Bracket` as reliable shortcuts.
- No slide, flip, fade, or page-turn animation. The content changes immediately.

The slightly visible sheets behind the active note may be clickable as a secondary affordance, but this is optional and should not be required for MVP usability.

### 5.10 Note Switcher

Clicking the page count opens a compact popover listing all notes in the current stack.

Each row shows:

- Note number
- First nonempty line, truncated
- Muted last-edited date when space permits

Example:

```text
1   Set up benchmark environment
2   Questions for James
3   Investor demo curve
4   Untitled note
```

Behavior:

- Selecting a row opens that note.
- The active note is visibly marked.
- The list is scrollable for large stacks.
- Empty notes display as `Untitled note`.

---

## 6. Search

### 6.1 Floating Stack search

Search is scoped to the current stack.

The search popover contains:

```text
Search this stack…
────────────────────────────
6   Investor demo curve…
2   RunPod setup commands…
9   Questions for James…
```

Requirements:

- Fuzzy-match against the full note text.
- Also match note number.
- Rank stronger and earlier matches higher.
- Show a short contextual excerpt or first line.
- Selecting a result closes search and opens that note.
- Search updates as the user types.
- Empty query may show the most recently edited notes.
- `Escape` closes the search popover.

### 6.2 Library search

In the Library, search covers all stacks.

Each result shows:

- Generated note title or excerpt
- Stack name
- Note number
- Optional last-edited date

Selecting a result opens the correct stack and note.

---

## 7. Menu-Bar App

### 7.1 Purpose

The menu-bar icon is the app’s persistent entry point when no floating window is visible. It replaces the need for a screen-edge tab or Dock-centric workflow.

### 7.2 Menu contents

Recommended menu:

```text
New Note
New Stack…
────────────────────
Project Ideas
CS 162
Personal
────────────────────
Open Library
Preferences…
Quit
```

### 7.3 Menu behavior

- `New Note` reopens the most recently used stack and creates a note.
- If no stack exists, create a default stack named `Notes`.
- `New Stack…` prompts for a name, creates the stack, and opens it in the Floating Stack.
- Saved stacks appear in most-recently-used order.
- Clicking a stack opens its last active note in the Floating Stack.
- If the Floating Stack is already showing another stack, replace its contents with the selected stack rather than opening a second floating window.
- `Open Library` opens the full Library.
- `Quit` flushes pending saves and exits.

The menu-bar icon should be simple and monochrome so it fits native macOS menu-bar styling.

---

## 8. Library View

### 8.1 Purpose

The Library is for broader organization and navigation. It should feel like the Floating Stack expanded into a workspace, not like a separate product.

### 8.2 Layout

```text
┌──────────────────────────────────────────────────────────────┐
│ Sticky Notes                                      ‹ 6/10 ›  │
├────────────────────┬─────────────────────────────────────────┤
│ Search             │ Project Ideas                           │
│                    │                                         │
│ Project Ideas   10 │ Current note text...                    │
│ CS 162          14 │                                         │
│ Personal         8 │                                         │
│                    │                                         │
│ + New Stack        │                          Edited Jul 30  │
└────────────────────┴─────────────────────────────────────────┘
```

### 8.3 Sidebar

The left sidebar lists stacks vertically.

Each stack row shows:

- Stack name
- Note count
- Optional muted last-edited date

Behavior:

- Clicking a stack opens its last active note.
- Selected stack is clearly highlighted.
- Stacks are sorted by most recent activity.
- `+ New Stack` creates and selects a new stack.
- Stack renaming is available through a context menu or double-click.
- Stack deletion is available through a context menu and requires confirmation.
- Deleting a stack deletes all notes inside it.
- The confirmation should state the note count.

Do not add nested folders, tags, pinning, or custom sorting in MVP.

### 8.4 Main editor

The right side shows one large note editor.

- Same underlying editor behavior as the Floating Stack.
- Same autosave rules.
- Current stack name appears near the top-left of the editor area.
- `‹ current/total ›` appears at the top-right.
- The edited date appears at the bottom-right or in a small metadata row.
- Clicking the count opens the same Note Switcher pattern, sized appropriately for the larger window.
- `+` creates a note in the selected stack.

Do not show a permanent middle column containing every note. The page-navigation model is central to the product. Search and the Note Switcher provide list-based navigation only when needed.

### 8.5 Closing Library

When the Library closes:

- Reopen the Floating Stack focused on the same stack and note, unless the user explicitly hid the Floating Stack before opening the Library.
- Restore the previous floating-window position.
- No custom transition.

---

## 9. Stack Management

### 9.1 Creating a stack

Required fields:

- Name only

Rules:

- Trim leading and trailing whitespace.
- Prevent an empty name.
- Duplicate names are allowed, though the UI may warn gently.
- A new stack begins with one empty active note.
- If the user never types anything and deletes or leaves the stack, the implementation may retain the empty stack but should discard its empty note.

### 9.2 Renaming a stack

- Available in Library.
- Changes save immediately.
- Renaming does not affect note order or timestamps.

### 9.3 Deleting a stack

Confirmation example:

`Delete “Project Ideas” and its 10 notes? This cannot be undone.`

MVP may use permanent deletion. An undoable soft-delete system is optional but not required.

---

## 10. Note Deletion

Deletion can be available through:

- A context menu in the Note Switcher
- A keyboard shortcut such as `Command-Delete`
- An unobtrusive editor context menu

Behavior:

- Deleting a nonempty note requires confirmation or a brief undo affordance.
- After deletion, show the nearest remaining note.
- A stack must always be able to display an editable note. If its last note is deleted, immediately create a new empty note.
- Note numbers update according to the remaining creation order.

Do not place a permanent trash icon in the compact Floating Stack header.

---

## 11. Persistence and Data Model

### 11.1 Suggested entities

#### Stack

```text
id: UUID
name: String
createdAt: Date
updatedAt: Date
lastActiveNoteId: UUID?
```

#### Note

```text
id: UUID
stackId: UUID
body: String
createdAt: Date
updatedAt: Date
sortIndex: Integer
```

#### App State

```text
lastActiveStackId: UUID?
floatingWindowX: Double
floatingWindowY: Double
floatingWindowWidth: Double
floatingWindowHeight: Double
floatingWindowWasVisible: Boolean
libraryWindowFrame: Rect?
```

### 11.2 Storage

For MVP, use a local embedded store suitable for macOS, such as:

- SwiftData/Core Data, or
- SQLite with a very small persistence layer

Prefer the simplest native option supported reliably by the target macOS version.

### 11.3 Save behavior

- Debounce ordinary typing saves by roughly 250–500 ms.
- Save immediately before navigation, hide, Library transition, app termination, and system sleep when possible.
- Update `updatedAt` only when the body actually changes.
- Update the containing stack’s `updatedAt` when one of its notes changes or when a note is added/deleted.
- Data should survive crashes as well as reasonably possible.

---

## 12. Recommended macOS Implementation Direction

A practical architecture is:

- **Swift** for the application.
- **SwiftUI** for most view composition.
- **AppKit bridging** where necessary for precise floating-window and menu-bar behavior.
- `NSStatusItem` for the menu-bar icon.
- A nonactivating or standard panel/window configured to float above normal windows, depending on text-input behavior and accessibility testing.
- Native `TextEditor` or an `NSTextView` wrapper if SwiftUI text editing proves limiting.

Important implementation requirement:

The floating note must accept normal keyboard input while remaining always on top, but it must not behave like a modal window. Test focus switching carefully across Finder, browsers, terminals, and full-screen apps.

Do not build the app in Electron for MVP unless there is a strong external constraint. A native implementation better matches the lightweight memory, startup, window-management, and menu-bar requirements.

---

## 13. Keyboard Shortcuts

Recommended shortcuts:

| Action | Shortcut |
|---|---|
| New note in current stack | `Command-N` |
| New stack | `Command-Shift-N` |
| Search current scope | `Command-F` |
| Hide Floating Stack / close current window | `Command-W` |
| Open Library | `Command-Shift-E` |
| Previous note | `Command-[` |
| Next note | `Command-]` |
| Delete note | `Command-Delete` |
| Close popover/search | `Escape` |
| Quit | `Command-Q` |

Shortcuts should not override standard text-editing behavior unexpectedly.

---

## 14. Visual Direction

### 14.1 Tone

- Quiet
- Warm
- Minimal
- Native
- Slightly tactile, but not cartoonish

### 14.2 Color

MVP can use one soft yellow note color. Avoid user-selectable themes initially.

The selected color should maintain sufficient contrast for text and controls in both light and dark macOS appearances. The note itself may remain yellow in both modes while chrome and popovers adapt to the system appearance.

### 14.3 Typography

- Use the macOS system font.
- Editor body text should be comfortable at approximately 14–16 pt.
- Metadata and counters should be smaller and muted.
- Controls should remain legible without dominating the note.

### 14.4 Motion

- No custom animations.
- No page-turn, fade, slide, bounce, or spring behavior.
- State changes occur immediately.
- System-provided menu and popover behavior is acceptable.

---

## 15. Accessibility

- All icon-only controls require accessibility labels and tooltips.
- Keyboard access must cover all core interactions.
- Respect system text scaling where practical.
- Maintain sufficient text contrast.
- Do not rely on color alone to indicate selection or disabled state.
- Search results, note counts, and stack rows should be VoiceOver-readable.
- The editor should use standard macOS text accessibility behavior.

Suggested labels:

- `Hide sticky note`
- `Open library`
- `Search current stack`
- `Create new note`
- `Previous note`
- `Next note`
- `Open note switcher`

---

## 16. Preferences

Keep Preferences minimal in MVP:

- Launch at login: on/off
- Show Dock icon: on/off
- Keep Floating Stack above full-screen apps: on/off, only if technically reliable
- Confirm before deleting nonempty notes: on/off

Avoid visual customization and advanced settings until there is demonstrated demand.

---

## 17. Explicit Non-Goals for MVP

Do not implement:

- Accounts
- Cloud sync
- Collaboration
- Rich text or Markdown rendering
- Images or file attachments
- Checklists as a special data type
- Reminders or notifications
- Tags
- Nested folders
- Note pinning
- Multiple floating stacks at once
- Multiple note colors
- Revision history
- AI features
- Templates
- Import/export beyond an optional plain-text backup
- Mobile or web clients
- Custom animations
- Screen-edge restore tabs

---

## 18. Core User Flows

### 18.1 First launch

1. App launches into the menu bar.
2. Create a default stack named `Notes`.
3. Open the Floating Stack with one empty note.
4. Focus the editor.
5. Persist the note as soon as the user enters text.

### 18.2 Capture a new thought

1. User clicks `+` or presses `Command-N`.
2. New note becomes active immediately.
3. Cursor is placed in the editor.
4. User types.
5. Content autosaves.

### 18.3 Switch notes

1. User clicks `‹` or `›`.
2. Current changes save.
3. Adjacent note content appears immediately.
4. Counter updates.
5. No animation occurs.

### 18.4 Hide and restore

1. User clicks `×`.
2. Floating Stack disappears completely.
3. App remains running in the menu bar.
4. User clicks the menu-bar icon and chooses a stack.
5. Floating Stack reopens at its previous valid position.

### 18.5 Organize stacks

1. User clicks Expand or chooses Open Library.
2. Library opens focused on the current stack and note.
3. User selects, creates, renames, or deletes stacks from the sidebar.
4. User closes Library.
5. Floating Stack returns to the same context.

### 18.6 Find an older note

1. User presses `Command-F`.
2. Search field receives focus.
3. Results update while typing.
4. User selects a result.
5. Matching note opens and search closes.

---

## 19. Edge Cases

The implementation should explicitly handle:

- No stacks exist.
- Stack contains only one note.
- Current note is empty.
- Empty note is created and abandoned.
- A note or stack is deleted while selected.
- Hundreds of notes exist in one stack.
- Very long note content.
- App quits during an autosave debounce.
- External display is disconnected.
- Floating window was previously positioned off-screen.
- User opens Library while a search popover is active.
- User invokes New Note when no Floating Stack is visible.
- System appearance changes between light and dark mode.
- App launches after an unclean shutdown.

---

## 20. MVP Acceptance Criteria

The MVP is complete when all of the following are true:

### Floating behavior

- The note remains above ordinary windows.
- Other apps remain usable.
- The window can be dragged and its position persists.
- Hiding removes it fully from the desktop.
- It can be restored from the menu bar.

### Notes

- User can create, edit, navigate, search, and delete notes.
- Notes autosave reliably.
- Created and latest-edited dates are correct.
- Counter displays the current note position and total.
- Note Switcher opens from the counter.

### Stacks

- User can create, select, rename, and delete stacks.
- Each stack preserves its last active note.
- Menu-bar stack selection opens the correct stack.

### Library

- Sidebar shows all stacks.
- Main editor shows one active note.
- Search can find notes across stacks.
- Closing Library returns to the Floating Stack context.

### Performance and feel

- App launches quickly on a typical modern Mac.
- Idle CPU usage is effectively negligible.
- No custom animations are present.
- Typing and navigation feel immediate.
- The app works without an internet connection.

---

## 21. Suggested Build Order

1. Define Stack, Note, and App State persistence models.
2. Build the plain-text editor with autosave.
3. Build note creation and previous/next navigation.
4. Build the Floating Stack window and position restoration.
5. Add the menu-bar app and hide/restore behavior.
6. Add multiple stacks and current-context persistence.
7. Build the Library sidebar and expanded editor.
8. Add Note Switcher.
9. Add fuzzy search for current stack, then global Library search.
10. Add deletion, confirmation, keyboard shortcuts, accessibility labels, and preferences.
11. Test focus behavior, multi-monitor behavior, sleep/relaunch persistence, and crash recovery.
12. Profile startup, idle CPU, and memory use before adding any optional features.

---

## 22. Final Product Definition

The finished MVP should be describable in one sentence:

> A tiny menu-bar macOS app that keeps one searchable stack of autosaving plain-text notes above your other windows and expands into a simple library when you need to switch projects.

Any feature that weakens that sentence or makes the app feel heavier should be deferred.


next steps:
add delete button
aesthetics
font size changing
maybe change font?
