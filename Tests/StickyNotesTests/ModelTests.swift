import XCTest
@testable import StickyNotes

final class ModelTests: XCTestCase {
    func testTitleUsesFirstNonemptyLine() {
        let note = Note(body: "\n   \n  Benchmark setup  \nnext", sortIndex: 0)
        XCTAssertEqual(note.title, "Benchmark setup")
    }

    func testEmptyNoteTitle() {
        let note = Note(body: " \n\t", sortIndex: 0)
        XCTAssertEqual(note.title, "Untitled note")
        XCTAssertTrue(note.isEmpty)
    }

    func testFuzzyMatcherRanksExactPhraseAboveLooseCharacters() {
        let exact = FuzzyMatcher.score(query: "demo", text: "Investor demo curve")
        let loose = FuzzyMatcher.score(query: "demo", text: "Discuss every market outcome")
        XCTAssertNotNil(exact)
        XCTAssertNotNil(loose)
        XCTAssertGreaterThan(exact!, loose!)
    }

    func testFuzzyMatcherIsCaseInsensitive() {
        XCTAssertNotNil(FuzzyMatcher.score(query: "RUNPOD", text: "RunPod setup commands"))
    }

    func testEditorFontClampsToSupportedRange() {
        XCTAssertEqual(EditorFont.clamped(4), EditorFont.minimum)
        XCTAssertEqual(EditorFont.clamped(400), EditorFont.maximum)
        XCTAssertEqual(EditorFont.clamped(15), 15)
    }

    func testEditorFontRecoversFromInvalidStoredValue() {
        XCTAssertEqual(EditorFont.clamped(.nan), EditorFont.standard)
        XCTAssertEqual(EditorFont.clamped(.infinity), EditorFont.standard)
    }
}
