import AppKit
import SwiftUI

/// Floating Stack geometry. It opens small and can be dragged out to a much
/// larger size. `layoutVersion` is bumped whenever these defaults change so a
/// stale saved frame does not mask the new size.
enum FloatingLayout {
    static let defaultSize = NSSize(width: 300, height: 360)
    static let minimumSize = NSSize(width: 240, height: 200)
    static let maximumSize = NSSize(width: 680, height: 840)
    static let layoutVersion = 4
}

@MainActor
final class AppCoordinator: NSObject {
    let store: AppStore
    let actions: AppActions

    private var statusItem: NSStatusItem!
    private var floatingPanel: FloatingPanel?
    private var libraryWindow: NSWindow?
    private var preferencesWindow: NSWindow?
    private var restoreFloatingAfterLibrary = false
    private var floatingSearchObserver: NSObjectProtocol?
    private var settingsObserver: NSObjectProtocol?

    init(store: AppStore, actions: AppActions) {
        self.store = store
        self.actions = actions
        super.init()
        actions.coordinator = self
    }

    func start() {
        migrateFloatingLayoutIfNeeded()
        configureStatusItem()
        configureMainMenu()
        observeSystemEvents()

        let hasVisibilityPreference = UserDefaults.standard.object(
            forKey: SettingsKeys.floatingWasVisible
        ) != nil
        let shouldShow = hasVisibilityPreference
            ? UserDefaults.standard.bool(forKey: SettingsKeys.floatingWasVisible)
            : true

        if shouldShow {
            showFloating()
        }
    }

    func showFloating() {
        closeLibraryWithoutRestoring()
        let panel = floatingPanel ?? makeFloatingPanel()
        updatePanelSpaceBehavior()
        restoreOrCenter(panel)
        panel.orderFrontRegardless()
        panel.makeKey()
        UserDefaults.standard.set(true, forKey: SettingsKeys.floatingWasVisible)
        store.requestEditorFocus()
    }

    func hideFloating() {
        store.discardActiveEmptyNoteIfNeeded()
        store.saveImmediately()
        saveFloatingFrame()
        floatingPanel?.orderOut(nil)
        UserDefaults.standard.set(false, forKey: SettingsKeys.floatingWasVisible)
    }

    func openLibrary() {
        store.saveImmediately()
        restoreFloatingAfterLibrary = floatingPanel?.isVisible == true
        saveFloatingFrame()
        floatingPanel?.orderOut(nil)

        let window = libraryWindow ?? makeLibraryWindow()
        libraryWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        store.requestEditorFocus()
    }

    func showPreferences() {
        let window = preferencesWindow ?? makePreferencesWindow()
        preferencesWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func promptForNewStack() {
        let alert = NSAlert()
        alert.messageText = "New Stack"
        alert.informativeText = "Give this stack a name."
        alert.addButton(withTitle: "Create")
        alert.addButton(withTitle: "Cancel")

        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 290, height: 24))
        field.placeholderString = "Stack name"
        field.stringValue = ""
        alert.accessoryView = field
        alert.window.initialFirstResponder = field

        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else { return }
        let name = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        store.createStack(named: name)

        if libraryWindow?.isVisible != true {
            showFloating()
        }
    }

    func deleteCurrentNoteWithConfirmation() {
        guard let note = store.activeNote else { return }
        let confirms = UserDefaults.standard.object(forKey: SettingsKeys.confirmNoteDeletion) == nil
            || UserDefaults.standard.bool(forKey: SettingsKeys.confirmNoteDeletion)

        if note.isEmpty || !confirms {
            store.deleteActiveNote()
            return
        }

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Delete this note?"
        alert.informativeText = "“\(note.title)” will be permanently deleted."
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")
        alert.buttons.first?.hasDestructiveAction = true
        if alert.runModal() == .alertFirstButtonReturn {
            store.deleteActiveNote()
        }
    }

    func deleteStackWithConfirmation(_ stack: NoteStack) {
        let count = stack.notes.count
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Delete “\(stack.name)” and its \(count) \(count == 1 ? "note" : "notes")?"
        alert.informativeText = "This cannot be undone."
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")
        alert.buttons.first?.hasDestructiveAction = true
        if alert.runModal() == .alertFirstButtonReturn {
            store.deleteStack(stack.id)
        }
    }

    func applicationWillTerminate() {
        store.discardActiveEmptyNoteIfNeeded()
        store.saveImmediately()
        saveFloatingFrame()
    }

    private func makeFloatingPanel() -> FloatingPanel {
        let panel = FloatingPanel(
            contentRect: NSRect(origin: .zero, size: FloatingLayout.defaultSize),
            styleMask: [.borderless, .resizable],
            backing: .buffered,
            defer: false
        )
        panel.isMovableByWindowBackground = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.contentMinSize = FloatingLayout.minimumSize
        panel.contentMaxSize = FloatingLayout.maximumSize
        panel.minSize = FloatingLayout.minimumSize
        panel.maxSize = FloatingLayout.maximumSize
        panel.delegate = self

        let view = FloatingStackView(store: store, actions: actions)
        panel.contentViewController = NSHostingController(rootView: view)
        floatingPanel = panel
        return panel
    }

    private func makeLibraryWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 940, height: 620),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Sticky Notes"
        window.titlebarSeparatorStyle = .line
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 760, height: 500)
        window.center()
        window.setFrameAutosaveName("StickyNotesLibraryWindow")
        window.delegate = self
        window.contentViewController = NSHostingController(
            rootView: LibraryView(store: store, actions: actions)
        )
        return window
    }

    private func makePreferencesWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 470, height: 260),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Sticky Notes Settings"
        window.isReleasedWhenClosed = false
        window.center()
        window.contentViewController = NSHostingController(rootView: PreferencesView())
        return window
    }

    private func restoreOrCenter(_ panel: NSWindow) {
        guard !panel.isVisible else { return }

        if let frameString = UserDefaults.standard.string(forKey: SettingsKeys.floatingFrame) {
            let saved = NSRectFromString(frameString)
            if let visibleFrame = bestVisibleFrame(for: saved) {
                let adjusted = adjustedFrame(saved, inside: visibleFrame)
                panel.setFrame(adjusted, display: true)
                return
            }
        }

        guard let screen = NSScreen.main else {
            panel.center()
            return
        }
        let visible = screen.visibleFrame
        let origin = NSPoint(
            x: visible.maxX - panel.frame.width - 34,
            y: visible.maxY - panel.frame.height - 34
        )
        panel.setFrameOrigin(origin)
    }

    private func bestVisibleFrame(for saved: NSRect) -> NSRect? {
        if let screen = NSScreen.screens.first(where: { $0.visibleFrame.intersects(saved) }) {
            return screen.visibleFrame
        }
        return NSScreen.main?.visibleFrame
    }

    private func adjustedFrame(_ frame: NSRect, inside visible: NSRect) -> NSRect {
        var result = frame
        let minimum = FloatingLayout.minimumSize
        let maximum = FloatingLayout.maximumSize
        result.size.width = min(max(result.size.width, minimum.width), maximum.width)
        result.size.height = min(max(result.size.height, minimum.height), maximum.height)
        result.size.width = min(result.size.width, visible.width)
        result.size.height = min(result.size.height, visible.height)
        result.origin.x = min(max(result.origin.x, visible.minX), visible.maxX - result.width)
        result.origin.y = min(max(result.origin.y, visible.minY), visible.maxY - result.height)
        return result
    }

    private func migrateFloatingLayoutIfNeeded() {
        let savedVersion = UserDefaults.standard.integer(
            forKey: SettingsKeys.floatingLayoutVersion
        )
        guard savedVersion < FloatingLayout.layoutVersion else { return }
        UserDefaults.standard.removeObject(forKey: SettingsKeys.floatingFrame)
        UserDefaults.standard.set(
            FloatingLayout.layoutVersion,
            forKey: SettingsKeys.floatingLayoutVersion
        )
    }

    private func saveFloatingFrame() {
        guard let panel = floatingPanel else { return }
        UserDefaults.standard.set(
            NSStringFromRect(panel.frame),
            forKey: SettingsKeys.floatingFrame
        )
    }

    private func updatePanelSpaceBehavior() {
        let aboveFullScreen = UserDefaults.standard.object(forKey: SettingsKeys.keepAboveFullScreen) == nil
            || UserDefaults.standard.bool(forKey: SettingsKeys.keepAboveFullScreen)
        floatingPanel?.collectionBehavior = aboveFullScreen
            ? [.canJoinAllSpaces, .fullScreenAuxiliary]
            : [.moveToActiveSpace]
    }

    private func closeLibraryWithoutRestoring() {
        restoreFloatingAfterLibrary = false
        libraryWindow?.orderOut(nil)
    }

    private func configureStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(
                systemSymbolName: "note.text",
                accessibilityDescription: "Sticky Notes"
            )
            button.image?.isTemplate = true
        }
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
    }

    private func rebuildStatusMenu(_ menu: NSMenu) {
        menu.removeAllItems()
        menu.addItem(menuItem("New Note", action: #selector(newNote), key: "n"))
        menu.addItem(menuItem("New Stack…", action: #selector(newStack), key: "n", modifiers: [.command, .shift]))
        menu.addItem(.separator())

        for stack in store.orderedStacks {
            let item = NSMenuItem(
                title: stack.name,
                action: #selector(openStackFromMenu(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = stack.id
            item.state = stack.id == store.activeStackID ? .on : .off
            menu.addItem(item)
        }

        menu.addItem(.separator())
        menu.addItem(menuItem("Open Library", action: #selector(openLibraryAction), key: "e", modifiers: [.command, .shift]))
        menu.addItem(menuItem("Settings…", action: #selector(showPreferencesAction), key: ","))
        menu.addItem(.separator())
        menu.addItem(menuItem("Quit Sticky Notes", action: #selector(quit), key: "q"))
    }

    private func configureMainMenu() {
        let mainMenu = NSMenu()

        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "About Sticky Notes", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(menuItem("Settings…", action: #selector(showPreferencesAction), key: ","))
        appMenu.addItem(.separator())
        appMenu.addItem(menuItem("Quit Sticky Notes", action: #selector(quit), key: "q"))
        appItem.submenu = appMenu
        mainMenu.addItem(appItem)

        let fileItem = NSMenuItem()
        let fileMenu = NSMenu(title: "File")
        fileMenu.addItem(menuItem("New Note", action: #selector(newNote), key: "n"))
        fileMenu.addItem(menuItem("New Stack…", action: #selector(newStack), key: "n", modifiers: [.command, .shift]))
        fileMenu.addItem(.separator())
        fileMenu.addItem(menuItem("Open Library", action: #selector(openLibraryAction), key: "e", modifiers: [.command, .shift]))
        fileMenu.addItem(menuItem("Close", action: #selector(closeCurrentWindow), key: "w"))
        fileItem.submenu = fileMenu
        mainMenu.addItem(fileItem)

        let editItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = editMenu
        mainMenu.addItem(editItem)

        let viewItem = NSMenuItem()
        let viewMenu = NSMenu(title: "View")
        viewMenu.addItem(menuItem("Bigger Text", action: #selector(increaseFontSize), key: "+"))
        viewMenu.addItem(menuItem("Smaller Text", action: #selector(decreaseFontSize), key: "-"))
        viewMenu.addItem(menuItem("Actual Size", action: #selector(resetFontSize), key: "0"))
        viewItem.submenu = viewMenu
        mainMenu.addItem(viewItem)

        let noteItem = NSMenuItem()
        let noteMenu = NSMenu(title: "Note")
        noteMenu.addItem(menuItem("Search", action: #selector(search), key: "f"))
        noteMenu.addItem(.separator())
        noteMenu.addItem(menuItem("Previous Note", action: #selector(previousNote), key: "["))
        noteMenu.addItem(menuItem("Next Note", action: #selector(nextNote), key: "]"))
        noteMenu.addItem(.separator())
        noteMenu.addItem(menuItem("Delete Note…", action: #selector(deleteNote), key: "\u{8}"))
        noteItem.submenu = noteMenu
        mainMenu.addItem(noteItem)

        NSApp.mainMenu = mainMenu
    }

    private func menuItem(
        _ title: String,
        action: Selector,
        key: String,
        modifiers: NSEvent.ModifierFlags = [.command]
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        item.keyEquivalentModifierMask = modifiers
        return item
    }

    private func observeSystemEvents() {
        NotificationCenter.default.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.store.saveImmediately()
            }
        }

        settingsObserver = NotificationCenter.default.addObserver(
            forName: .stickySettingsDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.updatePanelSpaceBehavior()
            }
        }
    }

    @objc private func newNote() {
        if store.activeStack == nil {
            store.createStack(named: "Notes")
        } else {
            store.createNote()
        }
        if libraryWindow?.isVisible != true {
            showFloating()
        }
    }

    @objc private func newStack() { promptForNewStack() }
    @objc private func openLibraryAction() { openLibrary() }
    @objc private func showPreferencesAction() { showPreferences() }
    @objc private func previousNote() { store.navigate(by: -1) }
    @objc private func nextNote() { store.navigate(by: 1) }
    @objc private func deleteNote() { deleteCurrentNoteWithConfirmation() }

    @objc private func increaseFontSize() { adjustFontSize(by: EditorFont.step) }
    @objc private func decreaseFontSize() { adjustFontSize(by: -EditorFont.step) }
    @objc private func resetFontSize() { setFontSize(EditorFont.standard) }

    private func adjustFontSize(by delta: Double) {
        let stored = UserDefaults.standard.object(forKey: SettingsKeys.editorFontSize) as? Double
        setFontSize((stored ?? EditorFont.standard) + delta)
    }

    private func setFontSize(_ size: Double) {
        UserDefaults.standard.set(
            EditorFont.clamped(size),
            forKey: SettingsKeys.editorFontSize
        )
    }

    @objc private func search() {
        if libraryWindow?.isKeyWindow == true {
            store.requestLibrarySearch()
        } else {
            showFloating()
            store.requestFloatingSearch()
        }
    }

    @objc private func closeCurrentWindow() {
        if libraryWindow?.isKeyWindow == true {
            libraryWindow?.performClose(nil)
        } else if preferencesWindow?.isKeyWindow == true {
            preferencesWindow?.performClose(nil)
        } else {
            hideFloating()
        }
    }

    @objc private func openStackFromMenu(_ sender: NSMenuItem) {
        guard let stackID = sender.representedObject as? UUID else { return }
        store.selectStack(stackID)
        showFloating()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

extension AppCoordinator: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        rebuildStatusMenu(menu)
    }
}

extension AppCoordinator: NSWindowDelegate {
    func windowDidMove(_ notification: Notification) {
        guard let window = notification.object as? NSWindow, window === floatingPanel else { return }
        saveFloatingFrame()
    }

    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        if window === libraryWindow {
            store.saveImmediately()
            if restoreFloatingAfterLibrary {
                restoreFloatingAfterLibrary = false
                DispatchQueue.main.async { [weak self] in
                    self?.showFloating()
                }
            }
        }
    }
}

final class FloatingPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
