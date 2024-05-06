import Cocoa
import SwiftUI

/**
 View controller for the sidebar.
 
 1. Owns and manages the view controllers for the subordinate panes.
 2. Implements navigating between panes.
 3. Creates and populates error and outline entries in the outline and error pane respectively.
 */
class SidebarVC: NSViewController, EditorControllable {
    
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
    
    var outline: Outline {
        return (self.panes[.outline] as! OutlinePaneVC).outline
    }
    
    /**
     Custom behavior after the view is loaded.
     
     It does the following:
     1. Instantiates and stores the panes.
     
     - Note: Do things that do NOT require access to the `document` object or the `editor` view
     controller----operations at this point will not have access to these objects as the references are NOT yet available.
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
     
     - Note: Do things that DO require access to the `document` object or the `editor` view
     controller----operations at this point will have access to these objects.
     */
    override func viewDidAppear() {
        super.viewDidAppear()
        if self.panes[.bookmarks] == nil {
            let bookmarksPane = BookmarksPane(fileObject: self.document.content)
            let bookmarksVC = BookmarksController(rootView: bookmarksPane)
            bookmarksVC.view.translatesAutoresizingMaskIntoConstraints = false
            self.panes[.bookmarks] = bookmarksVC
        }
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
     Sets `sidebarView` to the view of the appropriate pane, conditionally updates the buttons'
     states, and sets `currentPane` to the target pane.
     
     In most cases, this is invoked by `navigate(_:)` with the flag "`updateButton: false`," which
     prevents redundant calls to update the buttons.
     
     - Parameters:
        - pane: The enumeration key of the target pane.
        - updateButton: Whether or not the method updates the buttons depending on the target pane
     chosen. This flag should be left untouched when programmatically navigating to a pane to ensure
     that the buttons are updated.
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
        paneView.setFrameSize(NSSize(width: self.sidebarView.frame.width,
                                     height: self.sidebarView.frame.height))
        
        paneView.topAnchor.constraint(equalTo: self.sidebarView.topAnchor).isActive = true
        paneView.bottomAnchor.constraint(equalTo: self.sidebarView.bottomAnchor).isActive = true
        
        paneView.leadingAnchor.constraint(equalTo: self.sidebarView.leadingAnchor).isActive = true
        paneView.trailingAnchor.constraint(equalTo: self.sidebarView.trailingAnchor).isActive = true
        
        self.currentPane = pane
    }
    
    func updateOutline() {
        self.outline.update(with: self.document.content.contentString)
        let outlineView = (self.panes[.outline] as! OutlinePaneVC).outlineView!
        for index in 0..<self.outline.entries.count {
            outlineView.expandItem(outlineView.item(atRow: index), expandChildren: true)
        }
    }
    
    /**
     Creates and populates error entries with the given error messages outputted by the JavaScript
     console. It also conditionally navigates to the error pane and shows them.
     
     The error messages can be, in theory, successfully downcasted as implemented, for the WebKit
     handles the conversion between JavaScript objects (obtained through the completion handler
     callback) and their corresponding Swift objects.
     
     - Parameter errorMessages: The error messages (an JavaScript object) outputted by evaluating
     the JavaScript.
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
                (self.panes[.error] as! ErrorPaneVC).entries = entries
            }
            guard !entries.isEmpty else {
                // return to outline view when no error if on error pane
                if self.currentPane == .error {
                    self.navigate(to: .outline)
                }
                return
            }
            entries.sort(by: {
                $0.lineNumber == $1.lineNumber ? ($0.groupNumber < $1.groupNumber) : ($0.lineNumber < $1.lineNumber)
            })
            
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
