import AppKit
import Foundation

@MainActor
final class AppActions: ObservableObject {
    weak var coordinator: AppCoordinator?

    func hideFloating() { coordinator?.hideFloating() }
    func openLibrary() { coordinator?.openLibrary() }
    func showFloating() { coordinator?.showFloating() }
    func showPreferences() { coordinator?.showPreferences() }
    func createStack() { coordinator?.promptForNewStack() }
    func deleteCurrentNote() { coordinator?.deleteCurrentNoteWithConfirmation() }
    func deleteStack(_ stack: NoteStack) { coordinator?.deleteStackWithConfirmation(stack) }
}
