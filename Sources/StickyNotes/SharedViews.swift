import SwiftUI

struct NoteNavigator: View {
    @ObservedObject var store: AppStore
    @Binding var showsSwitcher: Bool
    @ObservedObject var actions: AppActions
    var compact: Bool

    var body: some View {
        HStack(spacing: compact ? 0 : 4) {
            IconButton(
                systemName: "chevron.left",
                label: "Previous note",
                isEnabled: store.canGoPrevious
            ) {
                store.navigate(by: -1)
            }

            Button {
                showsSwitcher.toggle()
            } label: {
                Text(countLabel)
                    .font(.system(size: compact ? 10 : 11.5, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .frame(minWidth: compact ? 30 : 40)
            }
            .buttonStyle(.borderless)
            .controlSize(.mini)
            .foregroundStyle(.secondary)
            .help("Open note switcher")
            .accessibilityLabel("Open note switcher, \(countLabel)")
            .popover(isPresented: $showsSwitcher, arrowEdge: .bottom) {
                NoteSwitcherPopover(
                    store: store,
                    actions: actions,
                    isPresented: $showsSwitcher
                )
            }

            IconButton(
                systemName: "chevron.right",
                label: "Next note",
                isEnabled: store.canGoNext
            ) {
                store.navigate(by: 1)
            }
        }
    }

    private var countLabel: String {
        guard let index = store.activeNoteIndex else { return "0/0" }
        return "\(index + 1)/\(store.activeOrderedNotes.count)"
    }
}

/// Decrease / increase buttons for the editor text size. Both surfaces read the
/// same stored value, so a change in one is reflected in the other.
struct FontSizeControls: View {
    @AppStorage(SettingsKeys.editorFontSize) private var fontSize = EditorFont.standard

    var body: some View {
        HStack(spacing: 2) {
            IconButton(
                systemName: "textformat.size.smaller",
                label: "Decrease text size",
                isEnabled: fontSize > EditorFont.minimum
            ) {
                fontSize = EditorFont.clamped(fontSize - EditorFont.step)
            }

            IconButton(
                systemName: "textformat.size.larger",
                label: "Increase text size",
                isEnabled: fontSize < EditorFont.maximum
            ) {
                fontSize = EditorFont.clamped(fontSize + EditorFont.step)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Text size, \(Int(fontSize)) point")
    }
}

struct NoteSwitcherPopover: View {
    @ObservedObject var store: AppStore
    @ObservedObject var actions: AppActions
    @Binding var isPresented: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(store.activeStack?.name ?? "Notes")
                .font(.headline)
                .padding(.horizontal, 14)
                .padding(.top, 13)
                .padding(.bottom, 8)

            Divider()

            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(Array(store.activeOrderedNotes.enumerated()), id: \.element.id) { index, note in
                        Button {
                            store.selectNote(note.id)
                            isPresented = false
                        } label: {
                            HStack(spacing: 10) {
                                Text("\(index + 1)")
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                                    .frame(width: 22, alignment: .trailing)

                                Text(note.title)
                                    .lineLimit(1)
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                Text(note.updatedAt.shortListLabel)
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)

                                if note.id == store.activeNoteID {
                                    Image(systemName: "checkmark")
                                        .font(.caption.bold())
                                        .accessibilityLabel("Current note")
                                }
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button("Delete Note…", role: .destructive) {
                                store.selectNote(note.id, focusEditor: false)
                                isPresented = false
                                actions.deleteCurrentNote()
                            }
                        }
                    }
                }
                .padding(6)
            }
            .frame(maxHeight: 310)
        }
        .frame(width: 330)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Notes in current stack")
    }
}

enum SearchScope {
    case currentStack
    case allStacks
}

struct SearchPopover: View {
    @ObservedObject var store: AppStore
    let scope: SearchScope
    let onSelect: (NoteSearchResult) -> Void

    @State private var query = ""
    @FocusState private var searchFocused: Bool

    var results: [NoteSearchResult] {
        switch scope {
        case .currentStack:
            return Array(store.searchCurrentStack(query).prefix(30))
        case .allStacks:
            return Array(store.searchAll(query).prefix(40))
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField(
                    scope == .currentStack ? "Search this stack…" : "Search all stacks…",
                    text: $query
                )
                .textFieldStyle(.plain)
                .focused($searchFocused)
            }
            .padding(12)

            Divider()

            if results.isEmpty {
                ContentUnavailableView.search(text: query)
                    .frame(height: 150)
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(results) { result in
                            Button {
                                onSelect(result)
                            } label: {
                                HStack(alignment: .top, spacing: 10) {
                                    Text("\(result.noteNumber)")
                                        .font(.caption.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                        .frame(width: 22, alignment: .trailing)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(result.title)
                                            .font(.system(size: 13, weight: .medium))
                                            .lineLimit(1)
                                        Text(result.excerpt)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                        if scope == .allStacks {
                                            Text(result.stackName)
                                                .font(.caption2)
                                                .foregroundStyle(.tertiary)
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .padding(.horizontal, 9)
                                .padding(.vertical, 7)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(
                                "Note \(result.noteNumber), \(result.title), in \(result.stackName)"
                            )
                        }
                    }
                    .padding(6)
                }
                .frame(maxHeight: 300)
            }
        }
        .frame(width: 370)
        .onAppear { searchFocused = true }
    }
}
