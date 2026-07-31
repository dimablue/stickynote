import SwiftUI

struct LibraryView: View {
    @ObservedObject var store: AppStore
    @ObservedObject var actions: AppActions

    @State private var searchQuery = ""
    @State private var showsSwitcher = false
    @State private var stackBeingRenamed: NoteStack?
    @State private var renameText = ""
    @FocusState private var searchFocused: Bool

    @AppStorage(SettingsKeys.editorFontSize) private var fontSize = EditorFont.standard

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 220, ideal: 245, max: 300)
        } detail: {
            editorArea
        }
        .frame(minWidth: 760, minHeight: 500)
        .onChange(of: store.librarySearchRequest) { _, _ in
            searchFocused = true
        }
        .sheet(item: $stackBeingRenamed) { stack in
            RenameStackSheet(
                originalName: stack.name,
                name: $renameText,
                onCancel: { stackBeingRenamed = nil },
                onRename: {
                    store.renameStack(stack.id, to: renameText)
                    stackBeingRenamed = nil
                }
            )
        }
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search all stacks", text: $searchQuery)
                    .textFieldStyle(.plain)
                    .focused($searchFocused)
                if !searchQuery.isEmpty {
                    Button {
                        searchQuery = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Clear search")
                }
            }
            .padding(.horizontal, 10)
            .frame(height: 32)
            .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 8))
            .padding(12)

            Divider()

            if searchQuery.isEmpty {
                stackList
            } else {
                librarySearchResults
            }

            Divider()

            Button {
                actions.createStack()
            } label: {
                Label("New Stack", systemImage: "plus")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
            }
            .buttonStyle(.plain)
            .help("Create a new stack")
        }
        .background(.ultraThinMaterial)
    }

    private var stackList: some View {
        ScrollView {
            LazyVStack(spacing: 3) {
                ForEach(store.orderedStacks) { stack in
                    StackRow(
                        stack: stack,
                        isSelected: stack.id == store.activeStackID,
                        onSelect: { store.selectStack(stack.id) },
                        onRename: { beginRenaming(stack) },
                        onDelete: { actions.deleteStack(stack) }
                    )
                }
            }
            .padding(8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var librarySearchResults: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 3) {
                let results = store.searchAll(searchQuery)
                if results.isEmpty {
                    ContentUnavailableView.search(text: searchQuery)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 45)
                } else {
                    ForEach(results.prefix(80)) { result in
                        Button {
                            searchQuery = ""
                            store.selectStack(result.stackID)
                            store.selectNote(result.noteID)
                        } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(result.title)
                                    .font(.system(size: 13, weight: .medium))
                                    .lineLimit(1)
                                Text(result.excerpt)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                                HStack {
                                    Text(result.stackName)
                                    Text("Note \(result.noteNumber)")
                                    Spacer()
                                    Text(result.updatedAt.shortListLabel)
                                }
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(9)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(
                            "\(result.title), \(result.stackName), note \(result.noteNumber)"
                        )
                    }
                }
            }
            .padding(8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var editorArea: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(store.activeStack?.name ?? "Notes")
                        .font(.system(size: 18, weight: .semibold))
                    Text("\(store.activeOrderedNotes.count) \(store.activeOrderedNotes.count == 1 ? "note" : "notes")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                FontSizeControls()

                IconButton(systemName: "plus", label: "Create new note") {
                    store.createNote()
                }

                NoteNavigator(
                    store: store,
                    showsSwitcher: $showsSwitcher,
                    actions: actions,
                    compact: false
                )
            }
            .padding(.horizontal, 20)
            .frame(height: 60)

            Divider()

            NativeTextEditor(
                text: Binding(
                    get: { store.activeNote?.body ?? "" },
                    set: { store.updateActiveNoteBody($0) }
                ),
                fontSize: CGFloat(fontSize),
                focusRequest: store.editorFocusRequest
            )
            .padding(.horizontal, 15)
            .padding(.vertical, 12)
            .accessibilityLabel("Note text")

            Divider()

            HStack {
                Text(store.activeNote?.createdAt.fullCreatedLabel ?? "")
                Spacer()
                Text(store.activeNote?.updatedAt.compactEditedLabel ?? "")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 20)
            .frame(height: 36)
        }
        .background(Color(nsColor: .textBackgroundColor))
    }

    private func beginRenaming(_ stack: NoteStack) {
        renameText = stack.name
        stackBeingRenamed = stack
    }
}

private struct StackRow: View {
    let stack: NoteStack
    let isSelected: Bool
    let onSelect: () -> Void
    let onRename: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 9) {
                Image(systemName: "square.stack.3d.up")
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                    .frame(width: 18)

                VStack(alignment: .leading, spacing: 2) {
                    Text(stack.name)
                        .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                        .lineLimit(1)
                    Text(stack.updatedAt.shortListLabel)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text("\(stack.notes.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                isSelected ? Color.accentColor.opacity(0.15) : Color.clear,
                in: RoundedRectangle(cornerRadius: 8)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            TapGesture(count: 2).onEnded(onRename)
        )
        .contextMenu {
            Button("Rename…", action: onRename)
            Divider()
            Button("Delete Stack…", role: .destructive, action: onDelete)
        }
        .accessibilityLabel("\(stack.name), \(stack.notes.count) notes")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct RenameStackSheet: View {
    let originalName: String
    @Binding var name: String
    let onCancel: () -> Void
    let onRename: () -> Void

    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Rename Stack")
                .font(.title2.bold())
            TextField("Stack name", text: $name)
                .textFieldStyle(.roundedBorder)
                .focused($focused)
                .onSubmit {
                    if isValid { onRename() }
                }
            HStack {
                Spacer()
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button("Rename", action: onRename)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!isValid)
            }
        }
        .padding(22)
        .frame(width: 360)
        .onAppear {
            focused = true
        }
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
