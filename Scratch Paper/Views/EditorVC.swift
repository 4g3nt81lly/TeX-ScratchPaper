import Cocoa
import SwiftUI
import WebKit

/**
 View controller for the main editor.
 
 1. Manages behaviors associated with the main text view and the KaTeX view.
 2. Implements features: changing configuration, adding/modifying bookmarks.
 3. Creates and populates outline entries.
 */
class EditorVC: NSViewController {
    
    @objc dynamic var document: Document! {
        return self.view.window?.windowController!.document as? Document
    }
    
    /// Main text view.
    @IBOutlet weak var contentTextView: MainTextView!
    
    /// Webview for displaying rendered content.
    @IBOutlet weak var outputView: OutputView!
    
    /**
     View controller for configuration.
     
     This property is always `nil` except when the user invokes `presentConfigView()` via clicking
     the "Render > Configuration" menu item.
     */
    var configView: NSViewController!
    
    var texScannerDropZone: NSViewController!
    
    var texScannerView: NSViewController!
    
    /**
     A temporary, cancellable copy of the document's current configuration object.
     
     A temporary copy of the document's current configuration is created as the model for the
     configuration panel.
     It is ignored/discarded when the user cancels modifying the configuration.
     
     This property is always `nil` except when the user invokes `presentConfigView()` via clicking
     the "Configuration" menu item from the render button.
     */
    var newConfig: Configuration!
    
    /**
     View controller for bookmark editor.
     
     This property is always `nil` except when the user invokes `addBookmark()` via clicking the
     "Add Bookmark..." menu item from the `contentTextView`'s contextual menu.
     */
    var bookmarkEditor: NSViewController!
    
    /**
     Reference to its coexisting `SidebarVC` object.
     
     A computed property that gets sidebar object on-demand.
     */
    var sidebar: SidebarVC {
        return self.document.sidebar
    }
    
    var outline: Outline {
        return self.sidebar.outline
    }
    
    /// A flag to keep track of whether the output view has been initialized.
    var isInitialized = false
    
    /**
     A flag to keep track of the previously revealed line.
     
     Use this in comparison to determine if the current line has been previously revealed.
     */
    private var currentLine = 0
    
    private var timer: Timer?
    
    /**
     Custom behavior after the view is loaded.
     
     - Note: Do things that do NOT require access to the `document` object or the `editor` view
     controller----operations at this point will not have access to these objects as the references
     are NOT yet available.
     */
    override func viewDidLoad() {
        super.viewDidLoad()
        // initialize the drop-and-drop popover for TeX scanner
        let dropZoneView = TeXScannerDropZone(editor: self)
        let dropZoneVC = NSHostingController(rootView: dropZoneView)
        dropZoneVC.view.setFrameSize(NSSize(width: 300, height: 200))
        self.texScannerDropZone = dropZoneVC
    }
    
    /**
     Custom behavior after the view is redrawn.
     
     - Note: Do things that DO require access to the `document` object or the `editor` view
     controller----operations at this point will have access to these objects.
     */
    override func viewDidAppear() {
        super.viewDidAppear()
        // initialize output view, if not already initialized
        if !self.isInitialized {
            self.outputView.initializeView()
            self.isInitialized = true
        }
        self.view.window!.makeFirstResponder(self.contentTextView)
        self.contentTextView.string = self.document.content.contentString
        self.contentTextView.renderPlaceholders()
    }
    
    override func viewDidDisappear() {
        super.viewDidDisappear()
        self.outputView.configuration.websiteDataStore
            .fetchDataRecords(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes()) { records in
                records.forEach { record in
                    self.outputView.configuration.websiteDataStore
                        .removeData(ofTypes: record.dataTypes, for: [record]) {
                            NSLog("[Web Cache] Record \(record) purged.")
                        }
                }
            }
    }
    
    private func insertItem(_ item: String, in range: NSRange, select: Bool = false) {
        let text = NSMutableAttributedString(string: item, attributes: [
            .font : AppSettings.editorFont,
            .foregroundColor : NSColor.controlTextColor
        ])
        let placeholderCount = self.contentTextView.renderPlaceholders(text)
        self.contentTextView.insertText(text, replacementRange: range)
        
        guard select else { return }
        
        var selectionRange = range
        if placeholderCount > 0 {
            selectionRange.length = 0
            self.contentTextView.setSelectedRange(selectionRange)
            self.contentTextView.insertTab(nil)
        }
    }
    
    private func wrapItem(_ left: String, _ right: String, in range: NSRange, select: Bool = false) {
        let textStorage = self.contentTextView.textStorage!
        let selectedText = textStorage.attributedSubstring(from: range)
        
        let leftRange = NSRange(location: range.location - left.nsString.length,
                                length: left.nsString.length)
        let rightRange = NSRange(location: range.upperBound, length: right.nsString.length)
        
        // check for unwrapping iff the selected range allows
        if (leftRange.location >= 0) && (rightRange.upperBound <= textStorage.range.upperBound) {
            // check if the selected text is already wrapped with the pattern
            let leftPrefixText = textStorage.attributedSubstring(from: leftRange).string
            let rightPrefixText = textStorage.attributedSubstring(from: rightRange).string
            if (left == leftPrefixText) && (right == rightPrefixText) {
                // unwrap the item
                let unwrapRange = NSRange(location: leftRange.location,
                                          length: leftRange.length + selectedText.length + rightRange.length)
                self.contentTextView.insertText(selectedText, replacementRange: unwrapRange)
                if select {
                    // restore the selected range
                    var selectionRange = range
                    selectionRange.location -= leftRange.length
                    self.contentTextView.setSelectedRange(selectionRange)
                }
                return
            }
        }
        
        let text = NSMutableAttributedString(attributedString: selectedText)
        
        // render placeholders for left and right texts
        let leftText = NSMutableAttributedString(string: left)
        let rightText = NSMutableAttributedString(string: right)
        let leftPlaceholderCount = self.contentTextView.renderPlaceholders(leftText)
        let rightPlaceholderCount = self.contentTextView.renderPlaceholders(rightText)
        
        // insert left string to the left
        text.insert(leftText, at: 0)
        // insert right string to the right
        text.append(rightText)
        
        self.contentTextView.insertText(text, replacementRange: range)
        
        guard select else { return }
        
        var selectionRange = range
        if leftPlaceholderCount + rightPlaceholderCount > 0 {
            selectionRange.length = 0
            self.contentTextView.setSelectedRange(selectionRange)
            self.contentTextView.insertTab(nil)
        } else {
            // no placeholder in left/right text
            selectionRange.location += leftRange.length
            self.contentTextView.setSelectedRange(selectionRange)
        }
    }
    
    private func smartInsertCommand(_ pattern: String, range: NSRange, wrappable: Bool = true,
                                    splitPattern: (insert: String, wrap: String)? = nil, select: Bool = false) {
        let components = pattern.components(separatedBy: "!")
        
        // if splitPattern is provided, apply separate patterns to insert and wrap
        let splitComponents = splitPattern?.wrap.components(separatedBy: "!")
        let left = splitComponents?[0] ?? components[0]
        let right = splitComponents?[2] ?? components[2]
        
        if wrappable && range.length > 0 {
            // a range of text is selected, wrap the selected text
            return self.wrapItem(left, right, in: range, select: select)
        }
        // the command can only be inserted or no text is selected to be wrapped
        self.insertItem(splitPattern?.insert ?? components.joined(), in: range, select: select)
    }
    
    /**
     Action invoked by menu items to insert certain TeX command/syntax.
     
     The method inserts the requested command/syntax in-place when no texts is selected by the user,
     and encapsulates the selected texts with the requested command/syntax if the user selected one
     or multiple.
     
     - Note: Custom insertion/encapsulation logic are specified in this method.
     */
    @objc func insertCommand(_ sender: Any) {
        guard let command = (sender as? NSPopUpButton)?.titleOfSelectedItem ?? (sender as? NSMenuItem)?.title else {
            return
        }
        if self.contentTextView.isCoalescingUndo {
            self.contentTextView.breakUndoCoalescing()
        }
        
        // get selected ranges sorted by their location (descending order)
        let selectedRanges = (self.contentTextView.selectedRanges as! [NSRange])
            .sorted { $0.location > $1.location }
        
        // MARK: TeX Symbols
        
        // greek alphabet items
        if let menuItem = sender as? NSMenuItem, menuItem.tag == 24 {
            let greekLetterCommand = "\\\(menuItem.identifier!.rawValue) "
            for selectedRange in selectedRanges {
                self.insertItem(greekLetterCommand, in: selectedRange)
            }
            return
        }
        
        // let commandSequence = (sender as? NSMenuItem)?.identifier?.rawValue ?? ""
        
        let singleSelection = selectedRanges.count == 1
        
        // perform text insertion/wrapping for selected ranges starting at the furthest
        for selectedRange in selectedRanges {
            switch command {
                
            // MARK: Markdown Commands
            
            case "Bold":
                smartInsertCommand("**!<#bold#>!**",
                                   range: selectedRange, select: singleSelection)
                
            case "Italic":
                smartInsertCommand("_!<#italic#>!_",
                                   range: selectedRange, select: singleSelection)
                
            case "Underlined":
                smartInsertCommand("<u>!<#underlined#>!</u>",
                                   range: selectedRange, select: singleSelection)
                
            case "Strikethrough":
                smartInsertCommand("~~!<#text#>!~~", 
                                   range: selectedRange, select: singleSelection)
                
            case "Toggle Mode":
                smartInsertCommand("$!<#a+b=c#>!$",
                                   range: selectedRange, select: singleSelection)
                
            // MARK: TeX Basic Commands
                
            case "Fraction":
                smartInsertCommand(#"\frac{!<#a#>!}{<#b#>}"#,
                                   range: selectedRange, select: singleSelection)
            case "Exponent":
                smartInsertCommand("", range: selectedRange,
                                   splitPattern: (insert: "^{<#n#>}", wrap: "{!!}^{<#n#>}"),
                                   select: singleSelection)
            case "Square Root":
                smartInsertCommand(#"\sqrt{!<#n#>!}"#,
                                   range: selectedRange, select: singleSelection)
            case "Root":
                smartInsertCommand(#"\sqrt[<#n#>]{!<#m#>!}"#,
                                   range: selectedRange, select: singleSelection)
            case "Smart Parentheses":
                smartInsertCommand(#"\left(!<#a#>!\right)"#,
                                   range: selectedRange, select: singleSelection)
            case "Indefinite Integral":
                smartInsertCommand(#"\int{!<#f(x)#>!\ d<#x#>}"#,
                                   range: selectedRange, select: singleSelection)
            case "Definite Integral":
                smartInsertCommand(#"\int_{<#a#>}^{<#b#>}{!<#f(x)#>!\ d<#x#>}"#,
                                   range: selectedRange, select: singleSelection)
            case "Sum":
                smartInsertCommand(#"\sum_{<#i#>=<#0#>}^{<#n#>}{!<#expression#>!}"#,
                                   range: selectedRange, select: singleSelection)
            case "Product":
                smartInsertCommand(#"\prod_{<#i#>=<#0#>}^{<#n#>}{!<#expression#>!}"#,
                                   range: selectedRange, select: singleSelection)
            case "Limit":
                smartInsertCommand(#"\lim_{<#x#>\to<#a#>}{!<#f(x)#>!}"#,
                                   range: selectedRange, select: singleSelection)
            case "Binomial":
                smartInsertCommand(#"\binom{!<#n#>!}{<#r#>}"#,
                                   range: selectedRange, select: singleSelection)
            
            // MARK: TeX Environments
            
            case "Aligned":
                smartInsertCommand("\\begin{aligned}\n\t!<#a+b=c#>!\n\\end{aligned}",
                                   range: selectedRange, select: singleSelection)
            case "Array":
                smartInsertCommand("", range: selectedRange,
                                   splitPattern: (insert: "\\begin{array}{cc}\n\t<#a#> & <#b#> \\\\\n\t<#c#> & <#d#>\n\\end{array}",
                                                  wrap: "\\begin{array}{c}\n\t!!\n\\end{array}"),
                                   select: singleSelection)
            case "Matrix":
                smartInsertCommand("", range: selectedRange,
                                   splitPattern: (insert: "\\begin{matrix}\n\t<#a#> & <#b#> \\\\\n\t<#c#> & <#d#>\n\\end{matrix}",
                                                  wrap: "\\begin{matrix}\n\t!!\n\\end{matrix}"),
                                   select: singleSelection)
            case "Parenthesis Matrix":
                smartInsertCommand("", range: selectedRange,
                                   splitPattern: (insert: "\\begin{pmatrix}\n\t<#a#> & <#b#> \\\\\n\t<#c#> & <#d#>\n\\end{pmatrix}",
                                                  wrap: "\\begin{pmatrix}\n\t!!\n\\end{pmatrix}"),
                                   select: singleSelection)
            case "Bracket Matrix":
                smartInsertCommand("", range: selectedRange,
                                   splitPattern: (insert: "\\begin{bmatrix}\n\t<#a#> & <#b#> \\\\\n\t<#c#> & <#d#>\n\\end{bmatrix}",
                                                  wrap: "\\begin{bmatrix}\n\t!!\n\\end{bmatrix}"),
                                   select: singleSelection)
            case "Braces Matrix":
                smartInsertCommand("", range: selectedRange,
                                   splitPattern: (insert: "\\begin{Bmatrix}\n\t<#a#> & <#b#> \\\\\n\t<#c#> & <#d#>\n\\end{Bmatrix}",
                                                  wrap: "\\begin{Bmatrix}\n\t!!\n\\end{Bmatrix}"),
                                   select: singleSelection)
            case "Vertical Matrix":
                smartInsertCommand("", range: selectedRange,
                                   splitPattern: (insert: "\\begin{vmatrix}\n\t<#a#> & <#b#> \\\\\n\t<#c#> & <#d#>\n\\end{vmatrix}",
                                                  wrap: "\\begin{vmatrix}\n\t!!\n\\end{vmatrix}"),
                                   select: singleSelection)
            case "Double-Vertical Matrix":
                smartInsertCommand("", range: selectedRange,
                                   splitPattern: (insert: "\\begin{Vmatrix}\n\t<#a#> & <#b#> \\\\\n\t<#c#> & <#d#>\n\\end{Vmatrix}",
                                                  wrap: "\\begin{Vmatrix}\n\t!!\n\\end{Vmatrix}"),
                                   select: singleSelection)
            case "Cases":
                smartInsertCommand("\\begin{cases}\n\t!<#a#>! & \\text{if } <#b#> \\\\\n\t<#c#> & \\text{if } <#d#>\n\\end{cases}",
                                   range: selectedRange, select: singleSelection)
            case "Table":
                smartInsertCommand("", range: selectedRange,
                                   splitPattern: (insert: "\\def\\arraystretch{1.5}\n\\begin{array}{c|c|c}\n\t<#a#> & <#b#> & <#c#> \\\\ \\hline\n\t<#d#> & <#e#> & <#f#> \\\\ \\hdashline\n\t<#g#> & <#h#> & <#i#>\n\\end{array}",
                                                  wrap: "\\def\\arraystretch{1.5}\n\\begin{array}{c}\n\t!!\n\\end{array}"),
                                   select: singleSelection)
            
            // MARK: TeX Annotations
            
            case "Cancel (Left)":
                smartInsertCommand(#"\cancel{!<#a#>!}"#,
                                   range: selectedRange, select: singleSelection)
            case "Cancel (Right)":
                smartInsertCommand(#"\bcancel{!<#a#>!}"#,
                                   range: selectedRange, select: singleSelection)
            case "Cancel (X)":
                smartInsertCommand(#"\xcancel{!<#a#>!}"#,
                                   range: selectedRange, select: singleSelection)
            case "Strike Through":
                smartInsertCommand(#"\sout{!<#a#>!}"#,
                                   range: selectedRange, select: singleSelection)
            case "Overline":
                smartInsertCommand(#"\overline{!<#A#>!}"#,
                                   range: selectedRange, select: singleSelection)
            case "Underline":
                smartInsertCommand(#"\underline{!<#a#>!}"#,
                                   range: selectedRange, select: singleSelection)
            case "Overbrace":
                smartInsertCommand(#"\overbrace{!<#a#>!}^{<#b#>}"#,
                                   range: selectedRange, select: singleSelection)
            case "Underbrace":
                smartInsertCommand(#"\underbrace{!<#a#>!}_{<#b#>}"#,
                                   range: selectedRange, select: singleSelection)
            case "Over Left Arrow":
                smartInsertCommand(#"\overleftarrow{!<#A#>!}"#,
                                   range: selectedRange, select: singleSelection)
            case "Over Right Arrow":
                smartInsertCommand(#"\overrightarrow{!<#A#>!}"#,
                                   range: selectedRange, select: singleSelection)
            case "Vector":
                smartInsertCommand(#"\vec{!<#v#>!}"#,
                                   range: selectedRange, select: singleSelection)
            case "Hat":
                smartInsertCommand(#"\hat{!<#i#>!}"#,
                                   range: selectedRange, select: singleSelection)
            case "Bar":
                smartInsertCommand(#"\bar{!<#h#>!}"#,
                                   range: selectedRange, select: singleSelection)
            case "Box":
                smartInsertCommand(#"\boxed{!<#a#>!}"#,
                                   range: selectedRange, select: singleSelection)
            default:
                NSLog("Unknown command.")
                return
            }
        }
        
        // live render if enabled
        if self.document.content.configuration.liveRender {
            self.renderText()
        } else {
            // otherwise, just update the outline
            self.sidebar.updateOutline()
        }
        
    }
    
    /**
     Action sent when the user interacts with the controls in the bar.
     
     Marks the document as "edited" (change done) and renders the content. The content is rendered
     regardless of the live render option.
     */
    @IBAction func barConfigChanged(_ sender: Any) {
        self.document.updateChangeCount(.changeDone)
        self.renderText()
    }
    
    /**
     Presents a panel for the document's current configuration as a sheet.
     
     This method is marked Objective-C as it is used as the target for the "Render > Configuration"
     menu item.
     */
    @objc func presentConfigView() {
        self.newConfig = (self.document.content.configuration.copy() as! Configuration)
        let configView = ConfigurationView(config: self.newConfig, editor: self)
        self.configView = NSHostingController(rootView: configView)
        self.presentAsSheet(self.configView)
    }
    
    /**
     Dismisses the `configView` sheet view.
     
     This method is invoked from within an instance of `ConfigurationView` when cancel/done action
     is received.
     It is only when the user clicks "Done" that the new configuration object is saved as the
     document's current configuration object.
     
     This method resets `configView` and `newConfig` back to `nil`, ensuring that any attempt to
     access these objects without a proper context would result in a fatal error.
     */
    func dismissConfigView(updateConfig: Bool = false) {
        self.configView.dismiss(nil)
        if updateConfig, !self.newConfig.isEqual(to: self.document.content.configuration) {
            self.document.content.configuration = self.newConfig.copy() as! Configuration
            self.renderText(updateOutline: false)
        }
        self.configView = nil
        self.newConfig = nil
    }
    
    @objc func showTeXScannerDropZone() {
        var selectionRect = self.contentTextView.rectForRange(self.contentTextView.selectedRange())
        if selectionRect.width == 0 {
            selectionRect.size.width = 1
        }
        self.present(self.texScannerDropZone,
                     asPopoverRelativeTo: selectionRect, of: self.contentTextView,
                     preferredEdge: .maxY, behavior: .semitransient)
    }
    
    func dismissTeXScannerDropZone() {
        self.texScannerDropZone.dismiss(nil)
    }
    
    func presentTeXScannerView(with image: NSImage) {
        let texScannerView = TeXScannerView(image: image, editor: self)
        let texScannerVC = NSHostingController(rootView: texScannerView)
        
        // set up layout constraints (width and height)
        texScannerVC.view.translatesAutoresizingMaskIntoConstraints = false
        texScannerVC.view.widthAnchor
            .constraint(lessThanOrEqualToConstant: 1200).isActive = true
        texScannerVC.view.widthAnchor
            .constraint(greaterThanOrEqualToConstant: 400).isActive = true
        texScannerVC.view.heightAnchor
            .constraint(lessThanOrEqualToConstant: 800).isActive = true
        texScannerVC.view.heightAnchor
            .constraint(greaterThanOrEqualToConstant: 350).isActive = true
        // set initial size
        texScannerVC.view.setFrameSize(NSSize(width: 700, height: 450))
        
        self.texScannerView = texScannerVC
        self.presentAsSheet(texScannerVC)
    }
    
    func dismissTeXScannerView(with texString: String? = nil) {
        if var texString {
            if self.document.content.configuration.renderMode == 0 {
                // Markdown mode, add delimiter
                texString = "$\(texString)$"
            }
            self.contentTextView.insertText(texString, replacementRange: self.contentTextView.selectedRange())
        }
        self.texScannerView.dismiss(nil)
    }
    
    /**
     Renders the content and conditionally updates the outline.
     
     This intermediate method renders the content as KaTeX and then conditionally loads or reloads
     the outline.
     
     - Parameter updateOutline: Whether or not this method should update the outline. Set this to
     `false` when rendering content without updating the outline.
     */
    func renderText(updateOutline: Bool = true) {
        if updateOutline {
            self.sidebar.updateOutline()
        }
        self.outputView.preprocess(with: self.outline)
        self.outputView.render()
    }
    
    /**
     Highlights the text in a given range in the text view and its corresponding rendered content in
     the output view.
     
     This method first scrolls the text view's scroll view to where the text range is in the text view,
     and then trigger the temporary highlighting effect on the desired portion of the text. Finally,
     it highlights the corresponding rendered content in the output view by evaluating dedicated
     JavaScript scripts, which is achieved by calling a dedicated JavaScript function through
     `evaluateJavaScript`.
     
     - Parameters:
        - range: The text range to be highlighted.
        - index: The index of the text's corresponding outline entry.
     
     - Note: The logic for highlighting content in the web view is not implemented here but in the
     template HTML file (within a `<script>` tag).
     
     For more details regarding how the JavaScript function is defined, please visit the template
     HTML file.
     */
    func reveal(at index: Int) {
        let range = self.document.editor.outline.ranges[index]
        
        self.contentTextView.scrollRangeToCenter(range, animated: true) {
            self.contentTextView.showFindIndicator(for: range)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            self.outputView.evaluateJavaScript("reveal(\(index));")
        }
    }
    
    /**
     Presents a panel for adding a bookmark as a sheet.
     
     This method is marked Objective-C as it is used as the target for the "Add Bookmark..." menu
     item in the main menu and text view's contextual menu.
     
     - Note: The `bookmarkEditor` handles the dismissal on its own, which involves `nil`-ifying itself.
     This is because the `BookmarkEntry` view is primarily managed by `BookmarksPane` and, by design,
     has required access to the document's content object.
     There is no reason to derive a separate logic for dismissal and conditional action and not make
     use of the existing scheme, let alone it is required for the communication between
     `BookmarksPane` and `BookmarkEntry`.
     */
    @objc func addBookmark() {
        let ranges = self.contentTextView.selectedRanges as! [NSRange]
        let newEntry = BookmarkEntry.new(ranges)
        let bookmarkEditor = BookmarkEditor(editor: self, fileObject: self.document.content, newEntry: newEntry)
        self.bookmarkEditor = NSHostingController(rootView: bookmarkEditor)
        self.presentAsSheet(self.bookmarkEditor)
    }
    
}

extension EditorVC: WKNavigationDelegate {
    
    /**
     Inherited from `WKNavigationDelegate` - Custom behavior upon the web view loading its content
     for the first time.
     
     As soon as the web view finishes loading its content from the HTML file for the first time:
     1. Moves cursor to the last cursor position saved in file.
     2. Simulates user interaction by directly invoking `textView(_:didInteract:)` to select matching
     outline entry and conditionally scroll to corresponding section if "line to line" is enabled.
     _(This also redundantly updates cursor position.)_
     3. Finalize loading the web view by adjusting the layout.
     */
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        let cursorPosition = self.document.content.configuration.cursorPosition
        let cursorRange = NSRange(location: cursorPosition, length: 0)
        self.contentTextView.setSelectedRange(cursorRange)
        
        // simulate user interaction: select matching outline entry
        // and scroll to corresponding section if line-to-line is enabled
        (self.contentTextView.delegate as? MainTextViewDelegate)?
            .textView(self.contentTextView, didInteract: cursorRange)
        
        // render for the first time
        self.renderText()
        
        webView.evaluateJavaScript("document.readyState", completionHandler: { (complete, _) in
            if complete != nil {
                webView.evaluateJavaScript("document.body.scrollHeight", completionHandler: { (height, _) in
                    webView.frame.size.height = height as! CGFloat
                    webView.layoutSubtreeIfNeeded()
                    
                    webView.evaluateJavaScript("isDarkMode = \(self.outputView.isDarkMode);")
                })
            }
        })
    }
    
}

extension EditorVC: MainTextViewDelegate {
    
    /**
     Custom behavior upon the text changing.
     
     It does the following:
     1. Appends a new line at EOF when one is missing.
     2. Updates the outline
     3. Conditionally renders the content.
     */
    func textDidChange(_ notification: Notification) {
        let contentString = self.contentTextView.sourceString
        var previousRange = self.contentTextView.selectedRange()
        defer {
            previousRange.location = min(previousRange.location, self.contentTextView.textLength - 1)
            self.contentTextView.setSelectedRange(previousRange)
        }
        if contentString.last != "\n" {
            self.contentTextView.textStorage!.mutableString.append("\n")
        }
        self.document.content.contentString = contentString
        
        // update outline
        self.sidebar.updateOutline()
        
        // live render
        if self.document.content.configuration.liveRender {
            self.renderText(updateOutline: false)
        }
    }
    
    /**
     Inherited from `MainTextViewDelegate` - Custom behavior upon user interaction with the text view.
     
     It does the following:
     1. Selects (without highlighting) row that matches the current editing range from outline.
     2. Updates file's cursor position.
     3. Line to line: Live scrolls the rendered content to section that matches the current editing
     range by evaluating dedicated JavaScript scripts.
     
     - Note: The logic for scrolling content in the web view is not implemented here but in the
     template HTML file (within a `<script>` tag).
     
     For more details regarding how the JavaScript function is defined, please visit the template
     HTML file.
     */
    func textView(_ textView: MainTextView, didInteract selectedRange: NSRange) {
        var matchingIndex: Int?
        for (index, range) in self.outline.ranges.enumerated() {
            if range.contains(selectedRange.location) || selectedRange.location == range.upperBound {
                // within the current line range
                matchingIndex = index
            } else if selectedRange.location > range.upperBound {
                // beyong the current line range
                continue
            } else if selectedRange.location < range.location {
                // not in the next line range, set to the previous range
                matchingIndex = index - 1
            }
            break
        }
        guard let index = matchingIndex else { return }
        // select row without highlighting
        let outlinePane = self.sidebar.panes[.outline] as! OutlinePaneVC
        outlinePane.bypassRevealOnSelectionChange = true
        outlinePane.outlineView.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
        outlinePane.outlineView.scrollRowToVisible(index)
        
        let docConfig = self.document.content.configuration
        
        // update cursor position
        docConfig.cursorPosition = selectedRange.location
        
        // line to line enabled
        if docConfig.lineToLine {
            self.outputView.evaluateJavaScript(
                (index == self.currentLine) ? "scrollLineToVisible(\(index));" : "reveal(\(index));"
            )
            self.currentLine = index
        }
    }
    
}
