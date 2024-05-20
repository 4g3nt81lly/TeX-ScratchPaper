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
        case outline
        case errors
        case bookmarks
    }
    
    /// Panes are stored in this dictionary and can be accessed using the `Pane` enumeration key.
    var panes: [Pane : NSViewController] = [:]
    
    /// Current selected pane.
    var currentPane: Pane = .outline
    
    /// Custom subview for containing the panes.
    @IBOutlet weak var contentView: NSView!
    
    func initialize() {
        initializeOutlinePane()
        initializeErrorsPane()
        initializeBookmarksPane()
        
        for paneVC in panes.values {
            let paneView = paneVC.view
            contentView.addSubview(paneView)
            paneView.setFrameSize(contentView.frame.size)
            paneView.topAnchor.constraint(equalTo: contentView.topAnchor)
                .isActive = true
            paneView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
                .isActive = true
            paneView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor)
                .isActive = true
            paneView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor)
                .isActive = true
        }
        
        navigate(to: .outline, updateButton: false)
    }
    
    /**
     Custom behavior after the view is loaded.
     
     - Note: None of the references are available at this point.
     */
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    // MARK: - Navigation
    
    /**
     Updates the states of the buttons when user selects a pane, just like a tab view.
     
     It subsequently calls `navigate(to:)` to set `contentView` to the view of the appropriate pane.
     */
    @IBAction func navigate(_ sender: NSButton) {
        let name = sender.identifier!.rawValue
        let pane = Pane(rawValue: name)!
        
        sender.state = .on
        for subview in view.subviews {
            guard let button = subview as? NSButton,
                  button.identifier!.rawValue != name else {
                continue
            }
            button.state = .off
        }
        
        navigate(to: pane, updateButton: false)
        
        // deselecting selected bookmarks
        editor.bookmarksPane.selectedBookmarks = []
    }
    
    /**
     Sets `contentView` to the view of the appropriate pane, conditionally updates the buttons'
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
        defer {
            for (p, paneVC) in panes {
                paneVC.view.isHidden = (p != pane)
            }
            currentPane = pane
        }
        guard (updateButton) else { return }
        for subview in view.subviews {
            guard let button = subview as? NSButton else { continue }
            button.state = (button.identifier!.rawValue == pane.rawValue) ? .on : .off
        }
    }
    
    // MARK: - Outline Pane
    
    private func initializeOutlinePane() {
        let identifier = "outlinePane"
        let paneVC = mainStoryboard.instantiateController(withIdentifier: identifier) as! OutlinePaneVC
        paneVC.structure = document.content.structure
        addChild(paneVC)
        panes[.outline] = paneVC
    }
    
    // TODO: Redesign outline pane - stop refreshing the entire outline
    
    func updateOutlineView() {
        let outlineView = (panes[.outline] as! OutlinePaneVC).outlineView!
        for row in 0..<structure.outline.count {
            outlineView.expandItem(outlineView.item(atRow: row), expandChildren: true)
        }
    }
    
    // MARK: - Error Pane
    
    private func initializeErrorsPane() {
        let identifier = "errorsPane"
        let paneVC = mainStoryboard.instantiateController(withIdentifier: identifier) as! ErrorPaneVC
        addChild(paneVC)
        panes[.errors] = paneVC
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
                (panes[.errors] as! ErrorPaneVC).entries = entries
            }
            guard !entries.isEmpty else {
                // return to outline view when no error if on error pane
                if (currentPane == .errors) {
                    navigate(to: .outline)
                }
                return
            }
            entries.sort(by: {
                $0.lineNumber == $1.lineNumber ? ($0.groupNumber < $1.groupNumber) : ($0.lineNumber < $1.lineNumber)
            })
            
            if (currentPane != .errors) {
                navigate(to: .errors)
            }
        }
    }
    
    // MARK: - Bookmark Pane
    
    private func initializeBookmarksPane() {
        let bookmarksPaneVC = BookmarksPane(documentContent: document.content).viewController
        addChild(bookmarksPaneVC)
        panes[.bookmarks] = bookmarksPaneVC
    }
    
    @objc func editSelectedBookmark() {
        editor.editSelectedBookmark()
    }
    
    @objc func deleteSelectedBookmarks() {
        editor.deleteSelectedBookmarks()
    }
    
}
