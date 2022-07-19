//
//  AppDelegate.swift
//  Scratch Paper
//
//  Created by Bingyi Billy Li on 2021/6/14.
//

import Cocoa
import SwiftUI

/// Application's delegate object.
@main
class AppDelegate: NSObject, NSApplicationDelegate {
    
    /**
     Application's universally accessible settings object.
     
     Reads and decodes settings from application support directory within the current user domain.
     If the configuration file is not found under the target directory, it will attempt to create a new instance.
     
     - Note: This property is initialized as part of the delegate's instantiation process, which guarantees it to be readily available when one requests it.
     */
    var settings: AppSettings = {
        if let pathURL = Scratch_Paper.fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?.appendingPathComponent("config"),
           let data = try? Data(contentsOf: pathURL),
           let appSettings = try? NSKeyedUnarchiver.unarchivedObject(ofClass: AppSettings.self, from: data) {
            return appSettings
        }
        return AppSettings()
    }()
    
    /**
     The application's current document controller.
     
     This is a strong reference to the application's main document controller, which is a subclass of `NSDocumentController`.
     */
    @IBOutlet var documentController: DocumentController!
    
    /**
     The window controller for the current document.
     
     This computed property returns the first window controller of the `currentDocument` managed by the document controller.
     
     - Precondition: This value is non-`nil` if and only if the `currentDocument` is non-`nil`, which means that the application must be active and a valid opened document must have its window presented at the front.
     */
    var currentDocumentWindow: DocumentWindow? {
        if let document = self.documentController.currentDocument as? ScratchPaper,
           let windowController = document.windowControllers.first as? DocumentWindow {
            return windowController
        }
        return nil
    }

    /**
     Inherited from `NSApplicationDelegate` - Custom behaviors after application did finish launching.
     
     Opens up an open panel if no document is opened or restored on launch.
     
     - Note: Beware that this is invoked after `NSDocument`'s `makeWindowControllers()` method when the document controller restores an unsaved document from the previous session.
     */
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        NSApp.activate(ignoringOtherApps: true)
        if self.documentController.documents.count == 0 {
            self.documentController.openDocument(nil)
        }
    }

    /**
     Inherited from `NSApplicationDelegate` - Determines how and whether the application should terminate upon receiving a terminating signal.
     
     Saves the settings to file before the application terminates.
     
     - Note: This does not guarantee that the settings will be successfully saved to drive. It is merely a naive attempt.
     */
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        self.settings.save()
        return .terminateNow
    }
    
    /**
     Inherited from `NSApplicationDelegate` - Determines how and whether the application should open an untitled document on launch and when the application icon is activated from the Dock.
     
     This method is invoked whenever the application is activated by the user (requesting to bring forward an opened document) but no document is opened at the moment. It opens up an open panel rather than a new untitled document the same way when the application launches.
     
     Reference: [](https://gist.github.com/SDolha/0ab7d99b75109eb4c7548ba13da9f5f9).
     */
    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool {
        if sender.keyWindow == nil {
            self.documentController.openDocument(nil)
        }
        return false
    }
    
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
    
    // TODO: Open a new window with webpage to https://katex.org/docs/supported.html .
    @IBAction func katexDocumentation(_ sender: Any) {
        
    }
    
}

extension AppDelegate: NSMenuDelegate {
    
    func menuNeedsUpdate(_ menu: NSMenu) {
        let menuIdentifier = menu.identifier!.rawValue
        if menuIdentifier == "file" {
            let item = menu.item(withTitle: "Export...")!
            item.target = self.currentDocumentWindow
            item.action = Selector(("export"))
        }
        if menuIdentifier == "edit" {
            let toggleModeItem = menu.item(withTitle: "Toggle Mode")!
            toggleModeItem.action = Selector(("insertCommand:"))
            
            let addBookmarkItem = menu.item(withTitle: "Add Bookmark...")!
            if let selectedRanges = self.currentDocumentWindow?.editor.contentTextView.selectedRange(), selectedRanges.length > 0 {
                addBookmarkItem.action = Selector(("addBookmark"))
            } else {
                addBookmarkItem.action = nil
            }
            
            let editBookmarkItem = menu.item(withTitle: "Edit Bookmark...")!
            let deleteBookmarkItem = menu.item(withTitle: "Delete Bookmark")!
            if let sidebar = self.currentDocumentWindow?.editor.sidebar, sidebar.currentPane == .bookmarks,
               let _ = sidebar.document.content.selectedBookmark {
                editBookmarkItem.action = Selector(("editBookmark"))
                deleteBookmarkItem.action = Selector(("deleteBookmark"))
            } else {
                editBookmarkItem.action = nil
                deleteBookmarkItem.action = nil
            }
        }
        if ["insertBasics", "insertEnvironments", "insertAnnotations", "insertSymbolsCapitalized", "insertSymbolsLowercased"].contains(menuIdentifier) {
            for item in menu.items {
                item.action = Selector(("insertCommand:"))
            }
        }
    }
    
}
