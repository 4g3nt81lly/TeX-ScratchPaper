import Cocoa
import SwiftUI

/// Application's delegate object.
@main
class AppDelegate: NSObject, NSApplicationDelegate {
    
    /**
     The application's current document controller.
     
     This is a strong reference to the application's main document controller.
     */
    var documentController = DocumentController()
    
    var currentDocument: Document? {
        return documentController.currentDocument as? Document
    }
    
    /**
     The window controller for the current document.
     
     This computed property returns the first window controller of the `currentDocument` managed by
     the document controller.
     
     - Precondition: This value is non-`nil` if and only if the `currentDocument` is non-`nil`,
     which means that the application must be active and a valid opened document must have its
     window presented at the front.
     */
    var currentDocumentWindow: DocumentWindow? {
        return currentDocument?.windowControllers.first as? DocumentWindow
    }
    
    /**
     Inherited from `NSApplicationDelegate` - Custom behaviors after application did finish
     launching.
     
     Opens up an open panel if no document is opened or restored on launch.
     
     - Note: Note that this is invoked after `NSDocument`'s `makeWindowControllers()` method
     when the document controller restores an unsaved document from the previous session.
     */
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        NSApp.activate(ignoringOtherApps: true)
        if (documentController.documents.isEmpty) {
            documentController.openDocument(nil)
        }
    }

    /**
     Inherited from `NSApplicationDelegate` - Determines how and whether the application should
     terminate upon receiving a terminating signal.
     
     Saves the settings to file before the application terminates.
     
     - Note: This does not guarantee that the settings will be successfully saved to drive. It is
     merely a naive attempt.
     */
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        // print("[AppDelegate] Determining whether the application should terminate.")
        appSettings.save()
        return .terminateNow
    }
    
    /**
     Inherited from `NSApplicationDelegate` - Determines how and whether the application should
     open an untitled document on launch and when the application icon is activated from the Dock.
     
     This method is invoked whenever the application is activated by the user (requesting to bring
     forward an opened document) but no document is opened at the moment. It opens up an open panel
     rather than a new untitled document the same way when the application launches.
     
     Reference: [](https://gist.github.com/SDolha/0ab7d99b75109eb4c7548ba13da9f5f9).
     */
    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool {
        if (sender.keyWindow == nil) {
            documentController.closeAllDocuments(withDelegate: nil,
                                                 didCloseAllSelector: nil,
                                                 contextInfo: nil)
            documentController.openDocument(nil)
        }
        return false
    }
    
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
    
    // TODO: Feature - Open a new window with webpage https://katex.org/docs/supported.html .
    @IBAction func katexDocumentation(_ sender: Any) {
        
    }
    
}

// MARK: - Menu Setup

extension AppDelegate: NSMenuDelegate {
    
    /// Prepares the application's main menus before they are displayed.
    func menuNeedsUpdate(_ menu: NSMenu) {
        let menuIdentifier = menu.identifier!.rawValue
        switch menuIdentifier {
        case "file":
            configureFileMenu(menu)
        case "edit":
            configureEditMenu(menu)
        case "insert":
            configureInsertMenu(menu)
        case "insertBasics", "insertEnvironments", "insertAnnotations",
             "insertSymbolsCapitalized", "insertSymbolsLowercased":
            configureInsertTeXMenu(menu)
        default:
            break
        }
    }
    
    // MARK: File Menu
    
    private func configureFileMenu(_ menu: NSMenu) {
        let item = menu.item(withTitle: "Export…")!
        item.target = currentDocumentWindow
        item.action = Selector(("export"))
    }
    
    // MARK: Edit Menu
    
    private func configureEditMenu(_ menu: NSMenu) {
        let toggleModeItem = menu.item(withTitle: "Toggle Mode")!
        if let renderMode = currentDocument?.content.configuration.renderMode,
           renderMode == 0 {
            toggleModeItem.action = #selector(EditorVC.insertCommand(_:))
        } else {
            toggleModeItem.action = nil
        }
        
        for markdownCommand in ["Bold", "Italic", "Underlined", "Strikethrough"] {
            let commandItem = menu.item(withTitle: markdownCommand)!
            commandItem.action = #selector(EditorVC.insertCommand(_:))
        }
        
        configureBookmarkItems(in: menu)
    }
    
    private func configureBookmarkItems(in menu: NSMenu) {
        let createBookmarkItem = menu.item(withTitle: "Create Bookmark…")!
        if let editor = currentDocument?.editor,
           editor.canCreateBookmark {
            createBookmarkItem.action = #selector(EditorVC.createBookmark)
        } else {
            createBookmarkItem.action = nil
        }
        
        let editBookmarkItem = menu.item(withTitle: "Edit Bookmark…")!
        let deleteBookmarkItem = menu.item(withTitle: "Delete Bookmark")!
        editBookmarkItem.action = nil
        deleteBookmarkItem.action = nil
        if let editor = currentDocument?.editor,
           editor.sidebar.currentPane == .bookmarks {
            let selectedCount = editor.bookmarksPane.selectedBookmarks.count
            if (selectedCount == 1) {
                editBookmarkItem.action = #selector(SidebarVC.editSelectedBookmark)
            }
            if (selectedCount > 0) {
                deleteBookmarkItem.action = #selector(SidebarVC.deleteSelectedBookmarks)
            }
        }
    }
    
    // MARK: Insert Menu
    
    private func configureInsertMenu(_ menu: NSMenu) {
        let scanTexItem = menu.item(withTitle: "Scan TeX…")!
        if let editor = currentDocument?.editor,
           editor.canPresentImage2TeXDropZone {
            scanTexItem.action = Selector(("presentImage2TeXDropZone"))
        } else {
            scanTexItem.action = nil
        }
    }
    
    private func configureInsertTeXMenu(_ menu: NSMenu) {
        for item in menu.items {
            item.action = Selector(("insertCommand:"))
        }
    }
    
}
