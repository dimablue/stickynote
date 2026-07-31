import SwiftUI

struct FloatingStackView: View {
    @ObservedObject var store: AppStore
    @ObservedObject var actions: AppActions

    @State private var showsSwitcher = false
    @State private var showsSearch = false
    @State private var isHovering = false

    @AppStorage(SettingsKeys.editorFontSize) private var fontSize = EditorFont.standard

    /// Controls are actions, and an action cannot be clicked without first
    /// moving the pointer onto the note — so they stay out of sight until then.
    /// A presented popover keeps them visible, otherwise it would hang off a
    /// button that had faded away.
    private var revealsControls: Bool {
        isHovering || showsSearch || showsSwitcher
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            editor
            footer
        }
        .stickySurface()
        .onHover { isHovering = $0 }
        .onChange(of: store.floatingSearchRequest) { _, _ in
            showsSearch = true
        }
    }

    private var header: some View {
        HStack(spacing: 2) {
            IconButton(systemName: "xmark", label: "Hide sticky note") {
                actions.hideFloating()
            }
            IconButton(
                systemName: "arrow.up.left.and.arrow.down.right",
                label: "Open library"
            ) {
                actions.openLibrary()
            }
            IconButton(
                systemName: "magnifyingglass",
                label: "Search current stack"
            ) {
                showsSearch.toggle()
            }
            .popover(isPresented: $showsSearch, arrowEdge: .top) {
                SearchPopover(
                    store: store,
                    scope: .currentStack,
                    onSelect: { result in
                        store.selectNote(result.noteID)
                        showsSearch = false
                    }
                )
            }

            Spacer(minLength: 8)

            FontSizeControls()
        }
        .opacity(revealsControls ? 1 : 0)
        .padding(.horizontal, 5)
        .frame(height: 24)
        .contentShape(Rectangle())
    }

    private var editor: some View {
        NativeTextEditor(
            text: Binding(
                get: { store.activeNote?.body ?? "" },
                set: { store.updateActiveNoteBody($0) }
            ),
            fontSize: CGFloat(fontSize),
            focusRequest: store.editorFocusRequest
        )
        .background(.clear)
        .padding(.horizontal, 2)
        .accessibilityLabel("Note text")
    }

    private var footer: some View {
        HStack {
            HStack(spacing: 2) {
                IconButton(systemName: "plus", label: "Create new note") {
                    store.createNote()
                }
                ConfirmingDeleteButton(
                    systemName: "trash",
                    label: "Delete current note",
                    resetKey: store.activeNoteID
                ) {
                    store.deleteActiveNote()
                }
            }
            .opacity(revealsControls ? 1 : 0)

            Spacer()

            NoteNavigator(
                store: store,
                showsSwitcher: $showsSwitcher,
                actions: actions,
                compact: true,
                arrowsVisible: revealsControls
            )
        }
        .padding(.horizontal, 5)
        .frame(height: 26)
    }
}
