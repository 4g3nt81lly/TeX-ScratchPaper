import Cocoa
import SwiftUI
import WebKit

/**
 View controller for the main editor that manages behaviors associated with the main text view and the output
 view, serving as a mediator between the model and the UI.
 
 Operations involving the main text view, the output view, and the sidebar view should be done at this level by
 this class. Interactions between these subviews (e.g. text view, output view, etc.) should ideally be managed
 and mediated by this class, direct messages that do not involve this class should be avoided. This class also
 initializes all of the subviews.
 */
class EditorVC: NSViewController, ObservableObject {
    
    /**
     A weak reference to the document object.
     
     A weak reference is preferred since the document object gets deallocated _before_ the view controller
     does, making this property `nil` for a split second after the window is dismissed.
     */
    @objc dynamic weak var document: Document!
    
    /**
     The main text view of this editor.
     */
    @IBOutlet weak var mainTextView: MainTextView!
    
    /**
     The output view of this editor.
     */
    @IBOutlet weak var outputView: OutputView!
    
    /**
     A weak reference to the sidebar view controller.
     */
    weak var sidebar: SidebarVC!
    
    /**
     A computed reference to the document content's structure object.
     */
    var structure: Structure {
        return document.content.structure
    }
    
    /**
     A computed list of contextual menu items used for the main text view.
     */
    var contextualMenuItems: [NSMenuItem] {
        var items: [NSMenuItem] = []
        if (canPresentImage2TeXDropZone) {
            items.append(NSMenuItem(title: "Scan TeX from image…",
                                    action: #selector(presentImage2TeXDropZone),
                                    keyEquivalent: ""))
        }
        if (CameraManager.isSupported) {
            items.append(NSMenuItem(title: "Scan TeX from camera…",
                                    action: #selector(presentTeXScannerView),
                                    keyEquivalent: ""))
        }
        if (canCreateBookmark) {
            items.append(NSMenuItem(title: "Create Bookmark…",
                                    action:  #selector(createBookmark),
                                    keyEquivalent: ""))
        }
        return items
    }
    
    /**
     Initializes the document's editor.
     
     This is called by ``Document.makeWindowControllers()`` and should never be called more than once.
     */
    func initialize() {
        // initialize output view
        outputView.initialize()
        
        // initialize text view
        mainTextView.string = document.content.contentString
        
        // NOTE: must render placeholders first before highlighting syntax
        mainTextView.renderPlaceholders()
        mainTextView.initializeSyntaxHighlighting()
        mainTextView.highlightSyntaxInVisibleRange()
        
        // initialize bookmarks
        mainTextView.initializeBookmarking()
        initializeBookmarks()
    }
    
    /**
     Custom behavior after the view is loaded.
     
     - Note: None of the references are available at this point.
     */
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    /**
     Custom behavior after the view is redrawn.
     */
    override func viewDidAppear() {
        super.viewDidAppear()
        view.window!.makeFirstResponder(mainTextView)
        sidebar.updateOutlineView()
    }
    
    /**
     Custom behavior after the view disappeared.
     */
    override func viewDidDisappear() {
        super.viewDidDisappear()
        outputView.configuration.websiteDataStore
            .fetchDataRecords(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes()) { records in
                records.forEach { record in
                    self.outputView.configuration.websiteDataStore
                        .removeData(ofTypes: record.dataTypes, for: [record]) {
                            NSLog("[Web Cache] Record \(record) purged.")
                        }
                }
            }
    }
    
    // MARK: - Image-to-TeX
    
    /**
     The view controller for the Image-to-TeX converter drag-and-drop popover.
     
     This view controller will be presented as a popover and is initialized lazily. Since the view requires no
     state information, it does not need to be initialized again.
     */
    private lazy var image2TeXDropZone: NSViewController = {
        TeXScannerDropZone { [unowned self] image in
            dismiss(image2TeXDropZone)
            presentImage2TeXView(with: image)
        } .viewController
    }()
    
    /**
     A boolean value indicating whether Image-to-TeX converter is available for the current text selection.
     
     This property is `true` _if and only if_ the main text view has exactly one selected range.
     */
    var canPresentImage2TeXDropZone: Bool {
        return mainTextView.selectedRanges.count == 1
    }
    
    /**
     Presents the Image-to-TeX converter drag-and-drop popover anchored to the current text selection
     rectangle.
     
     When the text selection has zero length, the selection rectangle is adjusted to ensure a valid
     positioning rectangle.
     
     - Note: This is marked `@objc` because it is invoked by the menu item action in the main text
     view's contextual menu.
     */
    @objc func presentImage2TeXDropZone() {
        var selectionRect = mainTextView.rectForRange(mainTextView.selectedRange())
        if (selectionRect.width == 0) {
            // zero rect is not a valid positioning rectangle.
            selectionRect.size.width = 1
        }
        present(image2TeXDropZone, asPopoverRelativeTo: selectionRect, of: mainTextView,
                preferredEdge: .maxY, behavior: .semitransient)
    }
    
    /**
     A strong reference to the Image-to-TeX converter view controller.
     
     This property will always be `nil` when it is not installed and presented.
     */
    private var image2TeXView: NSViewController!
    
    /**
     Presents the Image-to-TeX converter view controller as sheet with a given image as input.
     
     - Parameter image: An input image instance to be converted.
     
     Upon dismissal, the TeX string returned, if any, will be inserted to the current text selection range.
     */
    func presentImage2TeXView(with image: NSImage) {
        image2TeXView = Image2TeXView(image: image) { [unowned self] texString in
            dismiss(image2TeXView!)
            if var texString {
                if (document.content.configuration.renderMode == 0) {
                    // Markdown mode, add delimiter
                    texString = "$\(texString)$"
                }
                mainTextView.breakUndoCoalescing()
                mainTextView.insertText(texString, replacementRange: mainTextView.selectedRange())
            }
            image2TeXView = nil
        } .viewController
        presentAsSheet(image2TeXView)
    }
    
    // MARK: - TeX Scanner
    
    /**
     A strong reference to the TeX Scanner view controller.
     
     This property will always be `nil` when it is not installed and presented.
     */
    private var texScannerView: NSViewController!
    
    /**
     Presents the TeX Scanner view controller as sheet.
     
     Upon dismissal, if an image captured by the scanner is returned, the Image-to-TeX view is presented.
     
     - Note: This is marked `@objc` because it is invoked by the menu item action in the main text
     view's contextual menu.
     */
    @objc func presentTeXScannerView() {
        texScannerView = TeXScannerView { [unowned self] image in
            dismiss(texScannerView!)
            if let image {
                presentImage2TeXView(with: image)
            }
            texScannerView = nil
        } .viewController
        presentAsSheet(texScannerView)
    }
    
    // MARK: - Configuration
    
    /**
     The new and temporary configuration object to be modified by the configuration view.
     
     This is a discardable copy of the document's current configuration object and it is dismissed/ignored
     when the user cancels changing the configuration, otherwise the document's current configuration
     object is replaced by this modified copy.
     
     This property will always be `nil` when the configuration view is not installed and presented.
     */
    private var newConfiguration: Configuration!
    
    /**
     The configuration view controller.
     
     This property will always be `nil` when it is not installed and presented.
     */
    private var configurationView: NSViewController!
    
    /**
     Presents the configuration view controller as sheet.
     
     This methods first makes a copy of the document's current configuration object and use the copy as a
     temporary discardable configuration object. Depending on user action, this temporary configuration
     object is discarded or used to replace the document's current configuration object.
     
     - Note: This is marked `@objc` because it is invoked by the menu item action in the current document
     window's toolbar dropdown menu.
     */
    @objc func presentConfigurationView() {
        newConfiguration = document.content.configuration.copy()
        configurationView = ConfigurationView(config: newConfiguration) { [unowned self] save in
            dismiss(configurationView!)
            if (save && !newConfiguration.isEqual(to: document.content.configuration)) {
                document.content.configuration = newConfiguration
                renderText()
            }
            configurationView = nil
            newConfiguration = nil
        } .viewController
        presentAsSheet(configurationView)
    }
    
    // MARK: - Bookmark
    
    // TODO: Support bookmark user interaction in text view (e.g. hover, click, etc.)
    
    /**
     A computed reference to the bookmarks pane's view controller.
     
     This reference is used to send action to or access state information from the bookmarks pane, which is
     a SwiftUI view installed in its hosting controller ``BookmarksController``.
     */
    var bookmarksPane: BookmarksController {
        return sidebar.panes[.bookmarks] as! BookmarksController
    }
    
    // TODO: Support toggling on/off highlight bookmarks
    
    /**
     A boolean value indicating whether bookmarks should be highlighted in the main text view.
     */
    @objc dynamic var highlightBookmarks = true
    
    /**
     Initializes all bookmarks from the document content object.
     
     This method is invoked by ``initialize()`` and should not be invoked more than once.
     */
    private func initializeBookmarks() {
        mainTextView.addBookmarks(document.content.bookmarks)
    }
    
    /**
     A boolean value indicating whether a bookmark can be created with the current text selection.
     
     This property is true _if and only if_ the main text view's selection ranges have a positive combined length.
     */
    var canCreateBookmark: Bool {
        return (mainTextView.selectedRanges as! [NSRange]).totalLength > 0
    }
    
    func fetchBookmarkRanges(for bookmarks: Bookmarks) -> [UUID : [NSRange]] {
        return mainTextView.fetchBookmarkRanges(with: bookmarks.map { $0.id })
    }
    
    /**
     Presents a panel for adding a bookmark as sheet.
     
     - Precondition: ``canCreateBookmark`` must evaluate to `true`.
     
     - Note: This is marked `@objc` because it is invoked by the menu item action in the main text
     view's contextual menu and the app's main menu.
     */
    @objc func createBookmark() {
        // create a new bookmark at the selected ranges,
        //   which are non-overlapping, non-contiguous, and already sorted by location
        let newBookmark = Bookmark(at: mainTextView.selectedRanges)
        
        bookmarksPane.createBookmark(newBookmark) { [unowned self] newBookmarks in
            mainTextView.breakUndoCoalescing()
            document.content.addBookmarks(newBookmarks) { [unowned self] _ in
                mainTextView.addBookmarks(newBookmarks)
                sidebar.navigate(to: .bookmarks)
            } undoAction: { [unowned self] _ in
                mainTextView.deleteBookmarks(newBookmarks)
            }
        }
    }
    
    /**
     Presents a panel for editing the selected bookmark as sheet.
     
     - Precondition: The bookmarks pane has at exactly one selected bookmark, that is,
     ``bookmarksPane.selectedBookmark`` must be non-`nil` and ``bookmarksPane.selectedBookmarks.count``
     must evaluate to `1`.
     
     This is invoked by ``sidebar.editSelectedBookmark()`` and ``bookmarksPane``'s edit button action.
     */
    func editSelectedBookmark() {
        bookmarksPane.editSelectedBookmark { [unowned self] bookmarks in
            mainTextView.breakUndoCoalescing()
            document.content.editBookmark(with: bookmarks.first!)
        }
    }
    
    /**
     Presents a model alert for deleting an existing bookmark as sheet.
     
     - Precondition: The bookmarks pane has at least one selected bookmark, that is,
     ``bookmarksPane.selectedBookmark`` must be non-`nil`.
     
     - Note: This is invoked by ``sidebar.deleteSelectedBookmarks()`` and ``BookmarksPane``'s delete button action.
     */
    func deleteSelectedBookmarks() {
        bookmarksPane.deleteSelectedBookmarks { [unowned self] deletedBookmarks in
            mainTextView.breakUndoCoalescing()
            document.content.deleteBookmarks(deletedBookmarks) { [unowned self] _ in
                mainTextView.deleteBookmarks(deletedBookmarks)
            } undoAction: { [unowned self] _ in
                mainTextView.addBookmarks(deletedBookmarks)
            }
        }
    }
    
    /**
     Reveals the selected bookmark in the main text view.
     
     - Precondition: The bookmarks pane has at least one selected bookmark, that is,
     ``bookmarksPane.selectedBookmark`` must be non-`nil`.
     
     This is invoked by ``bookmarksPane``'s reveal button action.
     */
    func revealSelectedBookmark() {
        mainTextView.revealBookmark(bookmarksPane.selectedBookmark!)
    }
    
    /**
     Selects the selected bookmark in the main text view.
     
     - Precondition: The bookmarks pane has at exactly one selected bookmark, that is,
     ``bookmarksPane.selectedBookmark`` must be non-`nil` and ``bookmarksPane.selectedBookmarks.count``
     must evaluate to `1`.
     
     This is invoked by ``bookmarksPane``'s select button action.
     */
    func selectBookmarkRanges() {
        mainTextView.selectBookmarks(bookmarksPane.selectedBookmarks)
    }
    
    // MARK: - Smart Insertion
    
    /**
     Action invoked by menu items to insert certain Markdown/TeX command/syntax.
     
     The method inserts the requested command/syntax in-place when no texts is selected by the user, and
     encapsulates the selected texts with the requested command/syntax if the user selected one or multiple.
     */
    @objc func insertCommand(_ sender: Any) {
        guard let command = (sender as? NSPopUpButton)?.titleOfSelectedItem ?? (sender as? NSMenuItem)?.title else {
            return
        }
        mainTextView.breakUndoCoalescing()
        
        // get selected ranges sorted by their location (descending order)
        let selectedRanges = (mainTextView.selectedRanges as! [NSRange])
            .sorted { $0.location > $1.location }
        
        // MARK: TeX Symbols
        
        // greek alphabet items
        if let menuItem = sender as? NSMenuItem, menuItem.tag == 24 {
            let greekLetterCommand = "\\\(menuItem.identifier!.rawValue) "
            for selectedRange in selectedRanges {
                insertItem(greekLetterCommand, in: selectedRange)
            }
            return
        }
        
        // let commandSequence = (sender as? NSMenuItem)?.identifier?.rawValue ?? ""
        
        let singleSelection = (selectedRanges.count == 1)
        
        // perform text insertion/wrapping for selected ranges starting at the furthest
        for selectedRange in selectedRanges {
            switch command {
                
            // MARK: Markdown Commands
            
            case "Bold":
                smartInsertCommand("**!<@bold@>!**",
                                   range: selectedRange, shouldSelect: singleSelection)
                
            case "Italic":
                smartInsertCommand("_!<@italic@>!_",
                                   range: selectedRange, shouldSelect: singleSelection)
                
            case "Underlined":
                smartInsertCommand("<u>!<@underlined@>!</u>",
                                   range: selectedRange, shouldSelect: singleSelection)
                
            case "Strikethrough":
                smartInsertCommand("~~!<@text@>!~~", 
                                   range: selectedRange, shouldSelect: singleSelection)
                
            case "Toggle Mode":
                smartInsertCommand("$!<@a+b=c@>!$",
                                   range: selectedRange, shouldSelect: singleSelection)
            
            // MARK: TeX Basic Commands
            
            case "Fraction":
                smartInsertCommand(#"\frac{!<@a@>!}{<@b@>}"#,
                                   range: selectedRange, shouldSelect: singleSelection)
            case "Exponent":
                smartInsertCommand("", range: selectedRange,
                                   splitPattern: (insert: "^{<@n@>}", wrap: "{!!}^{<@n@>}"),
                                   shouldSelect: singleSelection)
            case "Square Root":
                smartInsertCommand(#"\sqrt{!<@n@>!}"#,
                                   range: selectedRange, shouldSelect: singleSelection)
            case "Root":
                smartInsertCommand(#"\sqrt[<@n@>]{!<@m@>!}"#,
                                   range: selectedRange, shouldSelect: singleSelection)
            case "Smart Parentheses":
                smartInsertCommand(#"\left(!<@a@>!\right)"#,
                                   range: selectedRange, shouldSelect: singleSelection)
            case "Indefinite Integral":
                smartInsertCommand(#"\int{!<@f(x)@>!\ d<@x@>}"#,
                                   range: selectedRange, shouldSelect: singleSelection)
            case "Definite Integral":
                smartInsertCommand(#"\int_{<@a@>}^{<@b@>}{!<@f(x)@>!\ d<@x@>}"#,
                                   range: selectedRange, shouldSelect: singleSelection)
            case "Sum":
                smartInsertCommand(#"\sum_{<@i@>=<@0@>}^{<@n@>}{!<@expression@>!}"#,
                                   range: selectedRange, shouldSelect: singleSelection)
            case "Product":
                smartInsertCommand(#"\prod_{<@i@>=<@0@>}^{<@n@>}{!<@expression@>!}"#,
                                   range: selectedRange, shouldSelect: singleSelection)
            case "Limit":
                smartInsertCommand(#"\lim_{<@x@>\to<@a@>}{!<@f(x)@>!}"#,
                                   range: selectedRange, shouldSelect: singleSelection)
            case "Binomial":
                smartInsertCommand(#"\binom{!<@n@>!}{<@r@>}"#,
                                   range: selectedRange, shouldSelect: singleSelection)
            
            // MARK: TeX Environments
            
            case "Aligned":
                smartInsertCommand("\\begin{aligned}\n\t!<@a+b=c@>!\n\\end{aligned}",
                                   range: selectedRange, shouldSelect: singleSelection)
            case "Array":
                smartInsertCommand("", range: selectedRange,
                                   splitPattern: (insert: "\\begin{array}{cc}\n\t<@a@> & <@b@> \\\\\n\t<@c@> & <@d@>\n\\end{array}",
                                                  wrap: "\\begin{array}{c}\n\t!!\n\\end{array}"),
                                   shouldSelect: singleSelection)
            case "Matrix":
                smartInsertCommand("", range: selectedRange,
                                   splitPattern: (insert: "\\begin{matrix}\n\t<@a@> & <@b@> \\\\\n\t<@c@> & <@d@>\n\\end{matrix}",
                                                  wrap: "\\begin{matrix}\n\t!!\n\\end{matrix}"),
                                   shouldSelect: singleSelection)
            case "Parenthesis Matrix":
                smartInsertCommand("", range: selectedRange,
                                   splitPattern: (insert: "\\begin{pmatrix}\n\t<@a@> & <@b@> \\\\\n\t<@c@> & <@d@>\n\\end{pmatrix}",
                                                  wrap: "\\begin{pmatrix}\n\t!!\n\\end{pmatrix}"),
                                   shouldSelect: singleSelection)
            case "Bracket Matrix":
                smartInsertCommand("", range: selectedRange,
                                   splitPattern: (insert: "\\begin{bmatrix}\n\t<@a@> & <@b@> \\\\\n\t<@c@> & <@d@>\n\\end{bmatrix}",
                                                  wrap: "\\begin{bmatrix}\n\t!!\n\\end{bmatrix}"),
                                   shouldSelect: singleSelection)
            case "Braces Matrix":
                smartInsertCommand("", range: selectedRange,
                                   splitPattern: (insert: "\\begin{Bmatrix}\n\t<@a@> & <@b@> \\\\\n\t<@c@> & <@d@>\n\\end{Bmatrix}",
                                                  wrap: "\\begin{Bmatrix}\n\t!!\n\\end{Bmatrix}"),
                                   shouldSelect: singleSelection)
            case "Vertical Matrix":
                smartInsertCommand("", range: selectedRange,
                                   splitPattern: (insert: "\\begin{vmatrix}\n\t<@a@> & <@b@> \\\\\n\t<@c@> & <@d@>\n\\end{vmatrix}",
                                                  wrap: "\\begin{vmatrix}\n\t!!\n\\end{vmatrix}"),
                                   shouldSelect: singleSelection)
            case "Double-Vertical Matrix":
                smartInsertCommand("", range: selectedRange,
                                   splitPattern: (insert: "\\begin{Vmatrix}\n\t<@a@> & <@b@> \\\\\n\t<@c@> & <@d@>\n\\end{Vmatrix}",
                                                  wrap: "\\begin{Vmatrix}\n\t!!\n\\end{Vmatrix}"),
                                   shouldSelect: singleSelection)
            case "Cases":
                smartInsertCommand("\\begin{cases}\n\t!<@a@>! & \\text{if } <@b@> \\\\\n\t<@c@> & \\text{if } <@d@>\n\\end{cases}",
                                   range: selectedRange, shouldSelect: singleSelection)
            case "Table":
                smartInsertCommand("", range: selectedRange,
                                   splitPattern: (insert: "\\def\\arraystretch{1.5}\n\\begin{array}{c|c|c}\n\t<@a@> & <@b@> & <@c@> \\\\ \\hline\n\t<@d@> & <@e@> & <@f@> \\\\ \\hdashline\n\t<@g@> & <@h@> & <@i@>\n\\end{array}",
                                                  wrap: "\\def\\arraystretch{1.5}\n\\begin{array}{c}\n\t!!\n\\end{array}"),
                                   shouldSelect: singleSelection)
            
            // MARK: TeX Annotations
            
            case "Cancel (Left)":
                smartInsertCommand(#"\cancel{!<@a@>!}"#,
                                   range: selectedRange, shouldSelect: singleSelection)
            case "Cancel (Right)":
                smartInsertCommand(#"\bcancel{!<@a@>!}"#,
                                   range: selectedRange, shouldSelect: singleSelection)
            case "Cancel (X)":
                smartInsertCommand(#"\xcancel{!<@a@>!}"#,
                                   range: selectedRange, shouldSelect: singleSelection)
            case "Strike Through":
                smartInsertCommand(#"\sout{!<@a@>!}"#,
                                   range: selectedRange, shouldSelect: singleSelection)
            case "Overline":
                smartInsertCommand(#"\overline{!<@A@>!}"#,
                                   range: selectedRange, shouldSelect: singleSelection)
            case "Underline":
                smartInsertCommand(#"\underline{!<@a@>!}"#,
                                   range: selectedRange, shouldSelect: singleSelection)
            case "Overbrace":
                smartInsertCommand(#"\overbrace{!<@a@>!}^{<@b@>}"#,
                                   range: selectedRange, shouldSelect: singleSelection)
            case "Underbrace":
                smartInsertCommand(#"\underbrace{!<@a@>!}_{<@b@>}"#,
                                   range: selectedRange, shouldSelect: singleSelection)
            case "Over Left Arrow":
                smartInsertCommand(#"\overleftarrow{!<@A@>!}"#,
                                   range: selectedRange, shouldSelect: singleSelection)
            case "Over Right Arrow":
                smartInsertCommand(#"\overrightarrow{!<@A@>!}"#,
                                   range: selectedRange, shouldSelect: singleSelection)
            case "Vector":
                smartInsertCommand(#"\vec{!<@v@>!}"#,
                                   range: selectedRange, shouldSelect: singleSelection)
            case "Hat":
                smartInsertCommand(#"\hat{!<@i@>!}"#,
                                   range: selectedRange, shouldSelect: singleSelection)
            case "Bar":
                smartInsertCommand(#"\bar{!<@h@>!}"#,
                                   range: selectedRange, shouldSelect: singleSelection)
            case "Box":
                smartInsertCommand(#"\boxed{!<@a@>!}"#,
                                   range: selectedRange, shouldSelect: singleSelection)
            default:
                NSLog("Unknown command.")
                return
            }
        }
        
        // live render if enabled
        if (document.content.configuration.liveRender) {
            renderText()
        } else {
            // otherwise, just update the outline
            sidebar.updateOutlineView()
        }
    }
    
    private func insertItem(_ item: String, in range: NSRange, shouldSelect: Bool = false) {
        let text = NSMutableAttributedString(string: item,
                                             attributes: EditorTheme.templateStyle.attributes)
        let placeholderCount = mainTextView.renderPlaceholders(text)
        mainTextView.insertText(text, replacementRange: range)
        
        guard (shouldSelect) else { return }
        
        var selectionRange = range
        if (placeholderCount > 0) {
            selectionRange.length = 0
            mainTextView.setSelectedRange(selectionRange)
            mainTextView.insertTab(nil)
        }
    }
    
    private func wrapItem(_ left: String, _ right: String, in range: NSRange, shouldSelect: Bool = false) {
        let textStorage = mainTextView.textStorage!
        let selectedText = textStorage.attributedSubstring(from: range)
        
        let leftRange = NSRange(location: range.location - left.nsString.length,
                                length: left.nsString.length)
        let rightRange = NSRange(location: range.upperBound, length: right.nsString.length)
        
        // check for unwrapping iff the selected range allows
        if ((leftRange.location >= 0) && (rightRange.upperBound <= textStorage.range.upperBound)) {
            // check if the selected text is already wrapped with the pattern
            let leftPrefixText = textStorage.attributedSubstring(from: leftRange).string
            let rightPrefixText = textStorage.attributedSubstring(from: rightRange).string
            if (left == leftPrefixText) && (right == rightPrefixText) {
                // unwrap the item
                let unwrapRange = NSRange(location: leftRange.location,
                                          length: leftRange.length + selectedText.length + rightRange.length)
                mainTextView.insertText(selectedText, replacementRange: unwrapRange)
                if (shouldSelect) {
                    // restore the selected range
                    var selectionRange = range
                    selectionRange.location -= leftRange.length
                    mainTextView.setSelectedRange(selectionRange)
                }
                return
            }
        }
        
        let text = NSMutableAttributedString(attributedString: selectedText)
        
        // render placeholders for left and right texts
        let leftText = NSMutableAttributedString(string: left)
        let rightText = NSMutableAttributedString(string: right)
        let leftPlaceholderCount = mainTextView.renderPlaceholders(leftText)
        let rightPlaceholderCount = mainTextView.renderPlaceholders(rightText)
        
        // insert left string to the left
        text.insert(leftText, at: 0)
        // insert right string to the right
        text.append(rightText)
        
        mainTextView.insertText(text, replacementRange: range)
        
        guard (shouldSelect) else { return }
        
        var selectionRange = range
        if (leftPlaceholderCount + rightPlaceholderCount > 0) {
            selectionRange.length = 0
            mainTextView.setSelectedRange(selectionRange)
            mainTextView.insertTab(nil)
        } else {
            // no placeholder in left/right text
            selectionRange.location += leftRange.length
            mainTextView.setSelectedRange(selectionRange)
        }
    }
    
    private func smartInsertCommand(_ pattern: String, range: NSRange, wrappable: Bool = true,
                                    splitPattern: (insert: String, wrap: String)? = nil, shouldSelect: Bool = false) {
        let components = pattern.components(separatedBy: "!")
        
        // if splitPattern is provided, apply separate patterns to insert and wrap
        let splitComponents = splitPattern?.wrap.components(separatedBy: "!")
        let left = splitComponents?[0] ?? components[0]
        let right = splitComponents?[2] ?? components[2]
        
        if (wrappable && range.length > 0) {
            // a range of text is selected, wrap the selected text
            return wrapItem(left, right, in: range, shouldSelect: shouldSelect)
        }
        // the command can only be inserted or no text is selected to be wrapped
        insertItem(splitPattern?.insert ?? components.joined(), in: range, shouldSelect: shouldSelect)
    }
    
    // MARK: - Utilities
    
    /**
     A flag to keep track of the previously revealed line.
     
     This property is used to determine if the currently selected line should be revealed. If this is `false`,
     then the currently selected line will be revealed in the main text view upon user interaction.
     */
    private var previouslyRevealedLine = 0
    
    /**
     Preprocesses and renders the text content in the output view.
     
     Since rendering uses the content structure object, one has to make sure the structure is update to date
     before calling this method.
     */
    func renderText() {
        outputView.preprocess(with: structure)
        outputView.render()
    }
    
    /**
     Action sent when the user interacts with the controls in the output view toolbar.
     
     Marks the document as "edited" and renders the content text.
     */
    @IBAction func barConfigChanged(_ sender: Any) {
        document.updateChangeCount(.changeDone)
        renderText()
    }
    
    /**
     Highlights the text in the main text view and its corresponding rendered content in the output view at
     the given section number.
     
     This method first scrolls the main text view's scroll view to where the section is in the text view,
     ensuring the range is visible, and then triggers the temporary highlighting effect on the desired portion
     of the text. It then highlights the corresponding rendered content in the output view by calling a
     JavaScript function in the output view.
     
     - Parameter section: The section number to be revealed.
     
     - Note: The function for highlighting content in the output view is not implemented here but in the
     template HTML file. For more details regarding how the JavaScript function is defined, visit the template
     HTML file.
     */
    func reveal(at section: Int) {
        let range = structure.sectionRanges[section]
        
        mainTextView.scrollRangeToCenter(range, animated: true) {
            self.mainTextView.showFindIndicator(for: range)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            self.outputView.evaluateJavaScript("reveal(\(section));")
        }
    }
    
}

extension EditorVC: WKNavigationDelegate {
    
    /**
     Custom behavior upon the output view loading for the first time.
     
     As soon as the web view finishes loading its content from the HTML file for the first time, this handler...
     1. moves cursor to the last cursor position saved in file.
     2. simulates user interaction by directly invoking `textView(_:didInteract:)` to select matching section
     node and conditionally scroll to corresponding section if line-to-line mode is enabled. _(which also
     redundantly updates cursor position.)_
     3. enables the main text view for editing and renders the text content.
     4. finalizes loading the web view by adjusting the layout.
     */
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        let cursorPosition = document.content.configuration.cursorPosition
        let cursorRange = NSRange(location: cursorPosition, length: 0)
        mainTextView.setSelectedRange(cursorRange)
        
        // simulate user interaction: select matching outline entry
        // and scroll to corresponding section if line-to-line is enabled
        (mainTextView.delegate as? MainTextViewDelegate)?
            .textView(mainTextView, didInteract: cursorRange)
        
        // enable the text view's editability
        mainTextView.isEditable = true
        
        // render for the first time
        renderText()
        
        webView.evaluateJavaScript("document.readyState", completionHandler: { (complete, _) in
            if (complete != nil) {
                webView.evaluateJavaScript("document.body.scrollHeight", completionHandler: { (height, _) in
                    webView.frame.size.height = height as! CGFloat
                    webView.layoutSubtreeIfNeeded()
                    
                    webView.evaluateJavaScript("isDarkMode = \(NSApp.isInDarkMode);")
                })
            }
        })
    }
    
}

extension EditorVC: MainTextViewDelegate {
    
    /**
     Custom behavior upon text change in the main text view.
     
     Updates the document content and structure, updates the outline view, and renders text conditionally.
     */
    func textDidChange(_ notification: Notification) {
        document.content.contentString = mainTextView.sourceString
        
        // update outline
        sidebar.updateOutlineView()
        
        // live render
        if (document.content.configuration.liveRender) {
            renderText()
        }
    }
    
    /**
     Custom behavior upon user interaction with the text view.
     
     It does the following:
     1. Selects (without highlighting) section that matches the current editing range from the content structure.
     2. Updates file's cursor position.
     3. Line-to-line mode: live scrolls the rendered content to section that matches the current editing range.
     
     - Note: The function for scrolling content in the web view is not implemented here but in the template
     HTML file. For more details regarding how the JavaScript function is defined, visit the template HTML file.
     */
    func textView(_ textView: MainTextView, didInteract selectedRange: NSRange) {
        var matchingIndex: Int?
        for (index, range) in structure.sectionRanges.enumerated() {
            if (range.contains(selectedRange.location) || selectedRange.location == range.upperBound) {
                // within the current line range
                matchingIndex = index
            } else if (selectedRange.location > range.upperBound) {
                // beyong the current line range
                continue
            } else if (selectedRange.location < range.location) {
                // not in the next line range, set to the previous range
                matchingIndex = index - 1
            }
            break
        }
        guard let index = matchingIndex else { return }
        // select row without highlighting
        let outlinePane = sidebar.panes[.outline] as! OutlinePaneVC
        outlinePane.bypassRevealOnSelectionChange = true
        outlinePane.outlineView.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
        outlinePane.outlineView.scrollRowToVisible(index)
        
        let documentConfig = document.content.configuration
        
        // update cursor position
        documentConfig.cursorPosition = selectedRange.location
        
        // line to line enabled
        if (documentConfig.lineToLine) {
            outputView.evaluateJavaScript(
                (index == previouslyRevealedLine) ? "scrollLineToVisible(\(index));" : "reveal(\(index));"
            )
            previouslyRevealedLine = index
        }
    }
    
}
