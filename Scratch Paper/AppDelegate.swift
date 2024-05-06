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
    
    /**
     The window controller for the current document.
     
     This computed property returns the first window controller of the `currentDocument` managed by
     the document controller.
     
     - Precondition: This value is non-`nil` if and only if the `currentDocument` is non-`nil`,
     which means that the application must be active and a valid opened document must have its
     window presented at the front.
     */
    var currentDocumentWindow: DocumentWindow? {
        return (self.documentController.currentDocument as? Document)?
            .windowControllers.first as? DocumentWindow
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
        if self.documentController.documents.isEmpty {
            self.documentController.openDocument(nil)
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
        if sender.keyWindow == nil {
            self.documentController.closeAllDocuments(withDelegate: nil,
                                                      didCloseAllSelector: nil,
                                                      contextInfo: nil)
            self.documentController.openDocument(nil)
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

extension AppDelegate: NSMenuDelegate {
    
    private func keyTextView() -> MainTextView? {
        return self.currentDocumentWindow?.window?.firstResponder as? MainTextView
    }
    
    private func configureFileMenu(_ menu: NSMenu) {
        let item = menu.item(withTitle: "Export…")!
        item.target = self.currentDocumentWindow
        item.action = Selector(("export"))
    }
    
    private func configureEditMenu(_ menu: NSMenu) {
        let toggleModeItem = menu.item(withTitle: "Toggle Mode")!
        if let renderMode = self.currentDocumentWindow?.editor.document.content.configuration.renderMode,
           renderMode == 0 {
            toggleModeItem.action = Selector(("insertCommand:"))
        } else {
            toggleModeItem.action = nil
        }
        
        for markdownCommand in ["Bold", "Italic", "Underlined", "Strikethrough"] {
            let commandItem = menu.item(withTitle: markdownCommand)!
            commandItem.action = (self.keyTextView() != nil) ? Selector(("insertCommand:")) : nil
        }
        
        let addBookmarkItem = menu.item(withTitle: "Add Bookmark…")!
        if let mainTextView = self.keyTextView(),
           mainTextView.selectedRanges.count == 1, mainTextView.selectedRange().length > 0 {
            addBookmarkItem.action = Selector(("addBookmark"))
        } else {
            addBookmarkItem.action = nil
        }
        
        let editBookmarkItem = menu.item(withTitle: "Edit Bookmark…")!
        let deleteBookmarkItem = menu.item(withTitle: "Delete Bookmark")!
        if let sidebar = self.currentDocumentWindow?.editor.sidebar,
           sidebar.currentPane == .bookmarks,
           let _ = sidebar.document.content.selectedBookmark {
            editBookmarkItem.action = Selector(("editBookmark"))
            deleteBookmarkItem.action = Selector(("deleteBookmark"))
        } else {
            editBookmarkItem.action = nil
            deleteBookmarkItem.action = nil
        }
    }
    
    private func configureInsertMenu(_ menu: NSMenu) {
        let scanTexItem = menu.item(withTitle: "Scan TeX…")!
        if let mainTextView = self.keyTextView(),
           mainTextView.selectedRanges.count == 1 {
            scanTexItem.action = Selector(("showTeXScannerDropZone"))
        } else {
            scanTexItem.action = nil
        }
    }
    
    private func configureInsertTeXMenu(_ menu: NSMenu) {
        for item in menu.items {
            item.action = (self.keyTextView() != nil) ? Selector(("insertCommand:")) : nil
        }
    }
    
    /// Prepares the application's main menus before they are displayed.
    func menuNeedsUpdate(_ menu: NSMenu) {
        let menuIdentifier = menu.identifier!.rawValue
        switch menuIdentifier {
        case "file":
            self.configureFileMenu(menu)
        case "edit":
            self.configureEditMenu(menu)
        case "insert":
            self.configureInsertMenu(menu)
        case "insertBasics", "insertEnvironments", "insertAnnotations",
             "insertSymbolsCapitalized", "insertSymbolsLowercased":
            self.configureInsertTeXMenu(menu)
        default:
            break
        }
    }
    
}
