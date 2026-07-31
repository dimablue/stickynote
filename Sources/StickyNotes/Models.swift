import Foundation

struct Note: Identifiable, Codable, Equatable {
    var id: UUID
    var body: String
    var createdAt: Date
    var updatedAt: Date
    var sortIndex: Int

    init(
        id: UUID = UUID(),
        body: String = "",
        createdAt: Date = .now,
        updatedAt: Date = .now,
        sortIndex: Int
    ) {
        self.id = id
        self.body = body
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.sortIndex = sortIndex
    }

    var title: String {
        body
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first(where: { !$0.isEmpty }) ?? "Untitled note"
    }

    var isEmpty: Bool {
        body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

struct NoteStack: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var createdAt: Date
    var updatedAt: Date
    var lastActiveNoteID: UUID?
    var notes: [Note]

    init(
        id: UUID = UUID(),
        name: String,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        lastActiveNoteID: UUID? = nil,
        notes: [Note] = []
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.lastActiveNoteID = lastActiveNoteID
        self.notes = notes
    }

    var orderedNotes: [Note] {
        notes.sorted {
            if $0.sortIndex == $1.sortIndex {
                return $0.createdAt < $1.createdAt
            }
            return $0.sortIndex < $1.sortIndex
        }
    }
}

struct WorkspaceData: Codable, Equatable {
    var stacks: [NoteStack]
    var lastActiveStackID: UUID?
}

struct NoteSearchResult: Identifiable, Equatable {
    let stackID: UUID
    let noteID: UUID
    let stackName: String
    let noteNumber: Int
    let title: String
    let excerpt: String
    let updatedAt: Date
    let score: Int

    var id: String { "\(stackID.uuidString)-\(noteID.uuidString)" }
}

enum FuzzyMatcher {
    static func score(query: String, text: String) -> Int? {
        let needle = normalized(query)
        let haystack = normalized(text)
        guard !needle.isEmpty else { return 0 }

        if let range = haystack.range(of: needle) {
            let position = haystack.distance(from: haystack.startIndex, to: range.lowerBound)
            let prefixBonus = position == 0 ? 160 : max(0, 80 - position)
            return 500 + prefixBonus - min(position, 120)
        }

        var queryIndex = needle.startIndex
        var textIndex = haystack.startIndex
        var firstMatch: Int?
        var lastMatch: Int?
        var consecutive = 0
        var total = 0

        while queryIndex < needle.endIndex, textIndex < haystack.endIndex {
            if needle[queryIndex] == haystack[textIndex] {
                let position = haystack.distance(from: haystack.startIndex, to: textIndex)
                firstMatch = firstMatch ?? position
                if let lastMatch, position == lastMatch + 1 {
                    consecutive += 1
                    total += 22 + consecutive * 4
                } else {
                    consecutive = 0
                    total += 12
                }
                lastMatch = position
                queryIndex = needle.index(after: queryIndex)
            }
            textIndex = haystack.index(after: textIndex)
        }

        guard queryIndex == needle.endIndex else { return nil }
        return total + max(0, 80 - (firstMatch ?? 80))
    }

    private static func normalized(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
    }
}
