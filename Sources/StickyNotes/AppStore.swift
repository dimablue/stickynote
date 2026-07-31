import AppKit
import Combine
import Foundation

@MainActor
final class AppStore: ObservableObject {
    @Published private(set) var stacks: [NoteStack] = []
    @Published private(set) var activeStackID: UUID?
    @Published private(set) var activeNoteID: UUID?
    @Published var editorFocusRequest = UUID()
    @Published var floatingSearchRequest = UUID()
    @Published var librarySearchRequest = UUID()

    private let fileURL: URL
    private var saveTask: Task<Void, Never>?

    init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? Self.defaultFileURL
        load()
    }

    deinit {
        saveTask?.cancel()
    }

    static var defaultFileURL: URL {
        let base = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        return base
            .appendingPathComponent("Sticky Notes", isDirectory: true)
            .appendingPathComponent("notes.json")
    }

    var orderedStacks: [NoteStack] {
        stacks.sorted {
            if $0.updatedAt == $1.updatedAt {
                return $0.createdAt > $1.createdAt
            }
            return $0.updatedAt > $1.updatedAt
        }
    }

    var activeStack: NoteStack? {
        guard let activeStackID else { return nil }
        return stacks.first(where: { $0.id == activeStackID })
    }

    var activeNote: Note? {
        guard let stack = activeStack, let activeNoteID else { return nil }
        return stack.notes.first(where: { $0.id == activeNoteID })
    }

    var activeOrderedNotes: [Note] {
        activeStack?.orderedNotes ?? []
    }

    var activeNoteIndex: Int? {
        guard let activeNoteID else { return nil }
        return activeOrderedNotes.firstIndex(where: { $0.id == activeNoteID })
    }

    var canGoPrevious: Bool {
        guard let index = activeNoteIndex else { return false }
        return index > 0
    }

    var canGoNext: Bool {
        guard let index = activeNoteIndex else { return false }
        return index < activeOrderedNotes.count - 1
    }

    func selectStack(_ stackID: UUID, focusEditor: Bool = false) {
        discardActiveEmptyNoteIfNeeded()
        guard let index = stacks.firstIndex(where: { $0.id == stackID }) else { return }
        ensureStackHasNote(at: index)
        activeStackID = stackID

        let requested = stacks[index].lastActiveNoteID
        let note = stacks[index].orderedNotes.first(where: { $0.id == requested })
            ?? stacks[index].orderedNotes.first
        activeNoteID = note?.id
        stacks[index].lastActiveNoteID = activeNoteID
        touchStack(at: index)
        scheduleSave()
        if focusEditor { requestEditorFocus() }
    }

    func selectNote(_ noteID: UUID, focusEditor: Bool = true) {
        guard let stackID = activeStackID,
              let stackIndex = stacks.firstIndex(where: { $0.id == stackID }),
              stacks[stackIndex].notes.contains(where: { $0.id == noteID })
        else { return }

        if noteID != activeNoteID {
            discardActiveEmptyNoteIfNeeded()
        }
        guard let refreshedIndex = stacks.firstIndex(where: { $0.id == stackID }),
              stacks[refreshedIndex].notes.contains(where: { $0.id == noteID })
        else { return }

        activeNoteID = noteID
        stacks[refreshedIndex].lastActiveNoteID = noteID
        touchStack(at: refreshedIndex)
        saveImmediately()
        if focusEditor { requestEditorFocus() }
    }

    func updateActiveNoteBody(_ body: String) {
        guard let stackID = activeStackID,
              let noteID = activeNoteID,
              let stackIndex = stacks.firstIndex(where: { $0.id == stackID }),
              let noteIndex = stacks[stackIndex].notes.firstIndex(where: { $0.id == noteID }),
              stacks[stackIndex].notes[noteIndex].body != body
        else { return }

        let now = Date.now
        stacks[stackIndex].notes[noteIndex].body = body
        stacks[stackIndex].notes[noteIndex].updatedAt = now
        stacks[stackIndex].updatedAt = now
        objectWillChange.send()
        scheduleSave()
    }

    @discardableResult
    func createNote(focusEditor: Bool = true) -> UUID? {
        guard let stackID = activeStackID,
              stacks.contains(where: { $0.id == stackID })
        else {
            let stackID = createStack(named: "Notes", focusEditor: focusEditor)
            return stacks
                .first(where: { $0.id == stackID })?
                .lastActiveNoteID
        }

        discardActiveEmptyNoteIfNeeded()
        guard let refreshedIndex = stacks.firstIndex(where: { $0.id == stackID }) else { return nil }

        let nextIndex = (stacks[refreshedIndex].notes.map(\.sortIndex).max() ?? -1) + 1
        let note = Note(sortIndex: nextIndex)
        stacks[refreshedIndex].notes.append(note)
        stacks[refreshedIndex].lastActiveNoteID = note.id
        activeNoteID = note.id
        touchStack(at: refreshedIndex)
        saveImmediately()
        if focusEditor { requestEditorFocus() }
        return note.id
    }

    @discardableResult
    func createStack(named rawName: String, focusEditor: Bool = true) -> UUID {
        let trimmed = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = trimmed.isEmpty ? "Notes" : trimmed
        let note = Note(sortIndex: 0)
        let stack = NoteStack(
            name: name,
            lastActiveNoteID: note.id,
            notes: [note]
        )
        stacks.append(stack)
        activeStackID = stack.id
        activeNoteID = note.id
        saveImmediately()
        if focusEditor { requestEditorFocus() }
        return stack.id
    }

    func renameStack(_ stackID: UUID, to rawName: String) {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty,
              let index = stacks.firstIndex(where: { $0.id == stackID }),
              stacks[index].name != name
        else { return }

        stacks[index].name = name
        saveImmediately()
    }

    func deleteStack(_ stackID: UUID) {
        guard let index = stacks.firstIndex(where: { $0.id == stackID }) else { return }
        let wasActive = activeStackID == stackID
        stacks.remove(at: index)

        if stacks.isEmpty {
            _ = createStack(named: "Notes")
            return
        }

        if wasActive {
            let next = orderedStacks.first!
            activeStackID = next.id
            activeNoteID = next.lastActiveNoteID ?? next.orderedNotes.first?.id
            if let activeIndex = stacks.firstIndex(where: { $0.id == next.id }) {
                ensureStackHasNote(at: activeIndex)
                activeNoteID = stacks[activeIndex].lastActiveNoteID
                    ?? stacks[activeIndex].orderedNotes.first?.id
            }
        }
        saveImmediately()
    }

    func deleteActiveNote() {
        guard let stackID = activeStackID,
              let noteID = activeNoteID,
              let stackIndex = stacks.firstIndex(where: { $0.id == stackID })
        else { return }

        let ordered = stacks[stackIndex].orderedNotes
        let oldIndex = ordered.firstIndex(where: { $0.id == noteID }) ?? 0
        stacks[stackIndex].notes.removeAll(where: { $0.id == noteID })

        if stacks[stackIndex].notes.isEmpty {
            let replacement = Note(sortIndex: 0)
            stacks[stackIndex].notes = [replacement]
            activeNoteID = replacement.id
        } else {
            let remaining = stacks[stackIndex].orderedNotes
            activeNoteID = remaining[min(oldIndex, remaining.count - 1)].id
        }

        normalizeSortIndexes(stackIndex: stackIndex)
        stacks[stackIndex].lastActiveNoteID = activeNoteID
        touchStack(at: stackIndex)
        saveImmediately()
        requestEditorFocus()
    }

    func navigate(by offset: Int) {
        guard let currentIndex = activeNoteIndex else { return }
        let targetIndex = currentIndex + offset
        guard activeOrderedNotes.indices.contains(targetIndex) else { return }
        selectNote(activeOrderedNotes[targetIndex].id)
    }

    func searchCurrentStack(_ query: String) -> [NoteSearchResult] {
        guard let stack = activeStack else { return [] }
        return search(stacks: [stack], query: query)
    }

    func searchAll(_ query: String) -> [NoteSearchResult] {
        search(stacks: stacks, query: query)
    }

    func requestEditorFocus() {
        editorFocusRequest = UUID()
    }

    func requestFloatingSearch() {
        floatingSearchRequest = UUID()
    }

    func requestLibrarySearch() {
        librarySearchRequest = UUID()
    }

    func discardActiveEmptyNoteIfNeeded() {
        guard let stackID = activeStackID,
              let noteID = activeNoteID,
              let stackIndex = stacks.firstIndex(where: { $0.id == stackID }),
              let note = stacks[stackIndex].notes.first(where: { $0.id == noteID }),
              note.isEmpty,
              stacks[stackIndex].notes.count > 1
        else { return }

        stacks[stackIndex].notes.removeAll(where: { $0.id == noteID })
        normalizeSortIndexes(stackIndex: stackIndex)
        let fallback = stacks[stackIndex].orderedNotes.last
        stacks[stackIndex].lastActiveNoteID = fallback?.id
        activeNoteID = fallback?.id
        touchStack(at: stackIndex)
    }

    func saveImmediately() {
        saveTask?.cancel()
        saveTask = nil
        persist()
    }

    private func load() {
        do {
            let data = try Data(contentsOf: fileURL)
            let workspace = try JSONDecoder().decode(WorkspaceData.self, from: data)
            stacks = workspace.stacks
            activeStackID = workspace.lastActiveStackID
        } catch {
            stacks = []
        }

        if stacks.isEmpty {
            _ = createStack(named: "Notes", focusEditor: false)
            return
        }

        let selectedStack = stacks.first(where: { $0.id == activeStackID }) ?? orderedStacks.first!
        activeStackID = selectedStack.id
        if let index = stacks.firstIndex(where: { $0.id == selectedStack.id }) {
            ensureStackHasNote(at: index)
            activeNoteID = stacks[index].notes.first(where: {
                $0.id == stacks[index].lastActiveNoteID
            })?.id ?? stacks[index].orderedNotes.first?.id
            stacks[index].lastActiveNoteID = activeNoteID
        }
    }

    private func ensureStackHasNote(at index: Int) {
        guard stacks[index].notes.isEmpty else { return }
        let note = Note(sortIndex: 0)
        stacks[index].notes = [note]
        stacks[index].lastActiveNoteID = note.id
    }

    private func touchStack(at index: Int) {
        stacks[index].updatedAt = .now
        objectWillChange.send()
    }

    private func normalizeSortIndexes(stackIndex: Int) {
        let orderedIDs = stacks[stackIndex].orderedNotes.map(\.id)
        for (position, id) in orderedIDs.enumerated() {
            if let index = stacks[stackIndex].notes.firstIndex(where: { $0.id == id }) {
                stacks[stackIndex].notes[index].sortIndex = position
            }
        }
    }

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            self?.persist()
        }
    }

    private func persist() {
        let workspace = WorkspaceData(
            stacks: stacks,
            lastActiveStackID: activeStackID
        )
        do {
            let directory = fileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(workspace)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            NSLog("Sticky Notes could not save: \(error.localizedDescription)")
        }
    }

    private func search(stacks selectedStacks: [NoteStack], query: String) -> [NoteSearchResult] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        var results: [NoteSearchResult] = []

        for stack in selectedStacks {
            for (index, note) in stack.orderedNotes.enumerated() {
                let number = index + 1
                let searchable = "\(number) \(note.body)"
                let score: Int
                if trimmed.isEmpty {
                    score = 0
                } else if let match = FuzzyMatcher.score(query: trimmed, text: searchable) {
                    score = match
                } else {
                    continue
                }

                results.append(
                    NoteSearchResult(
                        stackID: stack.id,
                        noteID: note.id,
                        stackName: stack.name,
                        noteNumber: number,
                        title: note.title,
                        excerpt: excerpt(for: note.body, matching: trimmed),
                        updatedAt: note.updatedAt,
                        score: score
                    )
                )
            }
        }

        return results.sorted {
            if $0.score == $1.score {
                return $0.updatedAt > $1.updatedAt
            }
            return $0.score > $1.score
        }
    }

    private func excerpt(for body: String, matching query: String) -> String {
        let flattened = body
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !flattened.isEmpty else { return "Untitled note" }
        guard !query.isEmpty,
              let range = flattened.range(
                of: query,
                options: [.caseInsensitive, .diacriticInsensitive]
              )
        else {
            return String(flattened.prefix(100))
        }

        let matchOffset = flattened.distance(from: flattened.startIndex, to: range.lowerBound)
        let startOffset = max(0, matchOffset - 28)
        let start = flattened.index(flattened.startIndex, offsetBy: startOffset)
        let suffix = String(flattened[start...].prefix(112))
        return startOffset > 0 ? "…\(suffix)" : suffix
    }
}
