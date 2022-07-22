//
//  Navigator.swift
//  Scratch Paper
//
//  Created by Bingyi Billy Li on 2021/6/12.
//

import Cocoa
import SwiftUI

/**
 View controller for the sidebar.
 
 1. Owns and manages the view controllers for the subordinate panes.
 2. Implements navigating between panes.
 3. Creates and populates error and outline entries in the outline and error pane respectively.
 */
class Sidebar: NSViewController {
    
    enum Pane: String, CaseIterable {
        case outline = "outline"
        case error = "error"
        case bookmarks = "bookmarks"
    }
    
    /// Panes are stored in this dictionary and can be accessed using the `Pane` enumeration key.
    var panes: [Pane : NSViewController] = [:]
    
    /// Current selected pane.
    var currentPane: Pane = .outline
    
    /// Custom subview for containing the panes.
    @IBOutlet weak var sidebarView: NSView!
    
    /**
     A weak reference to the associated document object.
     
     Implicitly unwrapped optional is used rather than creating a dummy document object to avoid redundant calls.
     It passes down the reference to the associated coument object down the hierarchy to its child view controllers by setting it to their `representedObject` property, which is readily available for any non-subclass view controllers.
     
     - Note: This is set by its superview `MainSplitViewController` when the document object creates a window controller via the `makeWindowControllers()` method.
     */
    weak var document: Document! {
        didSet {
            for child in self.children {
                child.representedObject = self.document
            }
        }
    }
    
    /**
     Reference to its coexisting `Editor` object.
     
     A computed property that gets editor object on-demand.
     */
    var editor: Editor {
        return self.document.editor
    }
    
    /**
     Custom behavior after the view is loaded.
     
     It does the following:
     1. Instantiates and stores the panes.
     
     - Note: Do things that do NOT require access to the `document` object or the `editor` view controller----operations at this point will not have access to these objects as the references are NOT yet available.
     */
    override func viewDidLoad() {
        super.viewDidLoad()
        for name in [Pane.outline, Pane.error] {
            let pane = mainStoryboard.instantiateController(withIdentifier: "\(name.rawValue)Pane") as! NSViewController
            self.addChild(pane)
            self.panes[name] = pane
        }
        self.navigate(to: .outline)
    }
    
    /**
     Custom behavior after the view finished drawing (initial appearance).
     
     It does the following:
     1. Instantiates and stores the "bookmarks" pane.
     
     - Note: Do things that DO require access to the `document` object or the `editor` view controller----operations at this point will have access to these objects.
     */
    override func viewDidAppear() {
        super.viewDidAppear()
        let bookmarksPane = BookmarksPane(fileObject: self.document.content)
        let bookmarksVC = BookmarksController(rootView: bookmarksPane)
        bookmarksVC.view.translatesAutoresizingMaskIntoConstraints = false
        self.panes[.bookmarks] = bookmarksVC
    }
    
    /**
     Updates the states of the buttons when user selects a pane, just like a tab view.
     
     It subsequently calls `navigate(to:)` to set `sidebarView` to the view of the appropriate pane.
     */
    @IBAction func navigate(_ sender: NSButton) {
        let name = sender.identifier!.rawValue
        let pane = Pane(rawValue: name)!
        
        sender.state = .on
        for view in self.view.subviews {
            guard let button = view as? NSButton,
                  button.identifier!.rawValue != name else {
                continue
            }
            button.state = .off
        }
        
        self.navigate(to: pane, updateButton: false)
        
        // deselecting selected bookmark
        self.document.content.selectedBookmark = nil
    }
    
    /**
     Sets `sidebarView` to the view of the appropriate pane, conditionally updates the buttons' states, and sets `currentPane` to the target pane.
     
     In most cases, this is invoked by `navigate(_:)` with the flag "`updateButton: false`," which prevents redundant calls to update the buttons.
     
     - Parameters:
        - pane: The enumeration key of the target pane.
        - updateButton: Whether or not the method updates the buttons depending on the target pane chosen. This flag should be left untouched when programmatically navigating to a pane to ensure that the buttons are updated.
     */
    func navigate(to pane: Pane, updateButton: Bool = true) {
        if updateButton {
            for view in self.view.subviews {
                guard let button = view as? NSButton else {
                    continue
                }
                button.state = (button.identifier!.rawValue == pane.rawValue) ? .on : .off
            }
        }
        
        let paneView = self.panes[pane]!.view
        self.sidebarView.subviews = []
        self.sidebarView.addSubview(paneView)
        paneView.setFrameSize(.init(width: self.sidebarView.frame.width, height: self.sidebarView.frame.height))
        
        paneView.topAnchor.constraint(equalTo: self.sidebarView.topAnchor).isActive = true
        paneView.bottomAnchor.constraint(equalTo: self.sidebarView.bottomAnchor).isActive = true
        
        paneView.leadingAnchor.constraint(equalTo: self.sidebarView.leadingAnchor).isActive = true
        paneView.trailingAnchor.constraint(equalTo: self.sidebarView.trailingAnchor).isActive = true
        
        self.currentPane = pane
    }
    
    /**
     Updates the outline.
     
     This method preprocesses the content and creates and populates the outline pane with newly-created outline entries for sidebar.
     
     - Parameter preprocessText: A flag indicating whether or not the method should invoke `preprocess()` to create line and range mappings before updating outline entries.
     
     - Warning: Calling this method with `preprocessText` flag set to `false` (default) without calling `renderText(updateOutline)` first may result in erroneous outline entries, because this method assumes by default that the method `renderText(updateOutline:)` has already been invoked and the line and range mappings have already been created. Make sure to set `preprocessText` to `true` when boldly calling this method.
     
     */
    func updateOutline(preprocessText: Bool = false) {
        let katexView = self.editor.katexView!
        if preprocessText {
            katexView.preprocess()
        }
        let outlinePane = self.panes[.outline] as! OutlinePane
        var entries: [OutlineEntry] = []
        for (index, (range, string)) in katexView.rangeMap.enumerated() {
            var content = string.trimmingCharacters(in: .whitespacesAndNewlines)
            if content == "" {
                content = "(EMPTY LINE)"
            }
            let outlineEntry = OutlineEntry(text: content, lineRange: katexView.lineRanges[index], selectableRange: range)
            entries.append(outlineEntry)
        }
        outlinePane.entries = entries
    }
    
    /**
     Creates and populates error entries with the given error messages outputted by the JavaScript console. It also conditionally navigates to the error pane and shows them.
     
     The error messages can be, in theory, successfully downcasted as implemented, for the WebKit handles the conversion between JavaScript objects (obtained through the completion handler callback) and their corresponding Swift objects.
     
     - Parameter errorMessages: The error messages (an JavaScript object) outputted by evaluating the JavaScript.
     */
    func showError(_ errorMessages: Any?) {
        if let content = errorMessages as? [String : [String : String]] {
            var entries: [ErrorEntry] = []
            
            for (line, errors) in content {
                for (group, message) in errors {
                    entries.append(ErrorEntry(line: line, group: group, message: message))
                }
            }
            defer {
                // navigate to error pane and set error entries
                (self.panes[.error] as! ErrorPane).entries = entries
            }
            guard !entries.isEmpty else {
                // return to outline view when no error if on error pane
                if self.currentPane == .error {
                    self.navigate(to: .outline)
                }
                return
            }
            entries.sort(by: { $0.lineNumber == $1.lineNumber ? ($0.groupNumber < $1.groupNumber) : ($0.lineNumber < $1.lineNumber) })
            
            if self.currentPane != .error {
                self.navigate(to: .error)
            }
        }
    }
    
    /**
     Presents a panel for editing the selected bookmark as a sheet.
     
     This method is marked Objective-C as it is used as the target for the "Edit Bookmark..." menu item in the main menu.
     */
    @objc func editBookmark() {
        global.editSelectedBookmark?()
    }
    
    /**
     Presents a warning before deleting the selected bookmark.
     
     This method is marked Objective-C as it is used as the target for the "Delete Bookmark" menu item in the main menu.
     */
    @objc func deleteBookmark() {
        global.deleteSelectedBookmark?()
    }
    
}
