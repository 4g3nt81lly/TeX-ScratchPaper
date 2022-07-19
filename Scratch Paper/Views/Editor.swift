//
//  Editor.swift
//  Scratch Paper
//
//  Created by Bingyi Billy Li on 2021/3/3.
//

import Cocoa
import SwiftUI
import WebKit

/**
 View controller for the main editor.
 
 1. Manages behaviors associated with the main text view and the KaTeX view.
 2. Implements features: changing configuration, adding/modifying bookmarks.
 3. Creates and populates outline entries.
 */
class Editor: NSViewController {
    
    /// Main text view.
    @IBOutlet weak var contentTextView: ATextView!
    
    /// Webview for displaying rendered content.
    @IBOutlet weak var katexView: KatexMathView!
    
    /**
     View controller for configuration.
     
     This property is always `nil` except when the user invokes `presentConfigView()` via clicking the "Render > Configuration" menu item.
     */
    var configView: NSViewController!
    
    /**
     A temporary, cancellable copy of the document's current configuration object.
     
     A temporary copy of the document's current configuration is created as the model for the configuration panel.
     It is ignored/discarded when the user cancels modifying the configuration.
     
     This property is always `nil` except when the user invokes `presentConfigView()` via clicking the "Configuration" menu item from the render button.
     */
    var newConfig: Configuration!
    
    /**
     View controller for bookmark editor.
     
     This property is always nil except when the user invokes `addBookmark()` via clicking the "Add Bookmark..." menu item from the `contentTextView`'s contextual menu.
     */
    var bookmarkEditor: NSViewController!
    
    /**
     Reference to the associated document object.
     
     Implicitly unwrapped optional is used rather than creating a dummy document object to avoid redundant calls.
     
     - Note: This is set by its superview `MainSplitViewController` when the document object creates a window controller via the `makeWindowControllers()` method.
     */
    @objc dynamic var document: ScratchPaper!
    
    /**
     Reference to its coexisting `Sidebar` object.
     
     A computed property that gets sidebar object on-demand.
     */
    var sidebar: Sidebar {
        return self.document.sidebar
    }
    
    /**
     A flag to keep track of the previously revealed line.
     
     Use this in comparison to determine if the current line has been previously revealed.
     */
    var previouslyIndicatedLine = 0
    
    /// A flag to keep track of whether the KaTeX view is properly initialized.
    var isKatexViewInitialized = false
    
    /**
     Custom behavior after the view is loaded.
     
     It does the following:
     1. Configures the main text view.
     2. Sets up the line number view for the main text view.
     3. Sets delegate for the main text view's text storage.
     
     - Note: Do things that do NOT require access to the `document` object or the `editor` view controller----operations at this point will not have access to these objects as the references are NOT yet available.
     */
    override func viewDidLoad() {
        super.viewDidLoad()
        self.contentTextView.font = .monospacedSystemFont(ofSize: 14.0, weight: .regular)
        self.contentTextView.isAutomaticTextCompletionEnabled = false
        self.contentTextView.isAutomaticTextReplacementEnabled = false
        self.contentTextView.isAutomaticQuoteSubstitutionEnabled = false
        self.contentTextView.isAutomaticDashSubstitutionEnabled = false
        self.contentTextView.isAutomaticLinkDetectionEnabled = false
        
        self.contentTextView.setUpLineNumberView()
        
        self.contentTextView.textStorage?.delegate = self
    }
    
    /**
     Custom behavior after the view finished drawing (initial appearance).
     
     It does the following:
     1. Initializes the KaTeX view if it has not already.
     2. Passes down reference to the document object to subviews that demand one.
     3. Automatically makes the main text view the first responder.
     
     - Note: Do things that DO require access to the `document` object or the `editor` view controller----operations at this point will have access to these objects.
     */
    override func viewDidAppear() {
        super.viewDidAppear()
        if !self.isKatexViewInitialized {
            self.contentTextView.document = self.document
            self.katexView.document = self.document
            
            self.katexView.initializeView()
            self.isKatexViewInitialized = true
        }
        self.view.window?.makeFirstResponder(self.contentTextView)
    }
    
    /**
     Action invoked by menu items to insert certain TeX command/syntax.
     
     The method inserts the requested command/syntax in-place when no texts is selected by the user, and encapsulates the selected texts with the requested command/syntax if the user selected one or multiple.
     
     - Note: Custom insertion/encapsulation logic are specified in this method.
     */
    @objc func insertCommand(_ sender: Any) {
        guard let command = (sender as? NSPopUpButton)?.titleOfSelectedItem ?? (sender as? NSMenuItem)?.title else {
            return
        }
        
        // get selected ranges sorted by their location
        let selectedRanges = (self.contentTextView.selectedRanges as! [NSRange]).sorted(by: { $0.location < $1.location })
        
        // utility function for text insertion
        func insertItem(_ item: String, _ range: NSRange, _ backspace: Int, _ length: Int = 0) {
            var selectedRange = range
            // replace text range
            self.contentTextView.insertText(item, replacementRange: selectedRange)
            
            selectedRange.location -= backspace
            selectedRange.length = length
            
            self.contentTextView.selectedRanges.append(selectedRange as NSValue)
        }
        
        if let menuItemTag = (sender as? NSMenuItem)?.tag, menuItemTag == 24 {
            let greekLettersCommand = "\\\(command.replacingOccurrences(of: ")", with: "").components(separatedBy: "(").last!)"
            for selectedRange in selectedRanges.reversed() {
                insertItem(greekLettersCommand, selectedRange, 0)
            }
            return
        }
        
        // utility function for text wrapping
        func wrapItem(_ left: String, _ right: String, _ range: NSRange, _ backspace: Int? = nil, _ forwardspace: Int = 0) {
            // right insertion
            var insertRange = NSRange(location: range.upperBound, length: 0)
            self.contentTextView.insertText(right, replacementRange: insertRange)
            // left insertion
            insertRange.location = range.location
            self.contentTextView.insertText(left, replacementRange: insertRange)
            
            if let count = backspace {
                insertRange.location += left.count + range.length + right.count - count
            } else {
                insertRange.location += left.count + forwardspace
                insertRange.length = forwardspace == 0 ? range.length : 0
            }
            self.contentTextView.selectedRanges.append(insertRange as NSValue)
        }
        
        // heuristic function for handling text insertion/wrapping
        func smartInsert(_ pattern: String, range: NSRange, smartMode: Bool = true, override: (String?, String?) = (nil, nil), insertBackspace: Int, insertSelectionLength: Int = 0, encapsulateBackspace: Int? = nil, encapsulateForwardspace: Int = 0) {
            let components = pattern.components(separatedBy: .whitespaces)
            
            // auto-decides only when smart mode is on
            guard smartMode else {
                // just insert item regardless
                insertItem(override.0 ?? components.joined(), range, insertBackspace, insertSelectionLength)
                return
            }
            guard range.length > 0 else {
                // insert item
                insertItem(override.0 ?? components.joined(), range, insertBackspace, insertSelectionLength)
                return
            }
            // wrap item
            let overrideComponents = override.1?.components(separatedBy: .whitespaces)
            let left = overrideComponents?.first ?? components[0]
            let right = overrideComponents?.last ?? components[1]
            wrapItem(left, right, range, encapsulateBackspace, encapsulateForwardspace)
        }
        
        // perform text insertion/wrapping for selected ranges starting at the furthest
        for selectedRange in selectedRanges.reversed() {
            switch command {
            case "Fraction":
                smartInsert("\\frac{ }{}", range: selectedRange, insertBackspace: 3, encapsulateBackspace: 1)
            case "Exponent":
                smartInsert("", range: selectedRange, override: ("^{}", "{ }^{}"), insertBackspace: 1, encapsulateBackspace: 1)
            case "Square Root":
                smartInsert("\\sqrt{ }", range: selectedRange, insertBackspace: 1)
            case "Root":
                smartInsert("\\sqrt[]{ }", range: selectedRange, insertBackspace: 3, encapsulateForwardspace: -2)
            case "Smart Parentheses":
                smartInsert("\\left( \\right)", range: selectedRange, insertBackspace: 7)
            case "Indefinite Integral":
                smartInsert("\\int{ }", range: selectedRange, insertBackspace: 1)
            case "Definite Integral":
                smartInsert("\\int_{ }^{}", range: selectedRange, insertBackspace: 4, encapsulateBackspace: 1)
            case "Sum":
                smartInsert("\\sum_{ }^{}", range: selectedRange, insertBackspace: 4, encapsulateBackspace: 1)
            case "Product":
                smartInsert("\\prod_{ }^{}", range: selectedRange, insertBackspace: 4, encapsulateBackspace: 1)
            case "Limit":
                smartInsert("\\lim_{ }", range: selectedRange, insertBackspace: 1, encapsulateBackspace: 1)
            case "Binomial":
                smartInsert("\\binom_{ }{}", range: selectedRange, insertBackspace: 3, encapsulateBackspace: 1)
            case "Aligned":
                smartInsert("\\begin{aligned}\n\t \n\\end{aligned}", range: selectedRange, insertBackspace: 14)
            case "Array":
                smartInsert("\\begin{array}{cc}\n\t \n\\end{array}", range: selectedRange, insertBackspace: 12)
            case "Matrix":
                smartInsert("\\begin{matrix}\n\t \n\\end{matrix}", range: selectedRange, insertBackspace: 13)
            case "Parenthesis Matrix":
                smartInsert("\\begin{pmatrix}\n\t \n\\end{pmatrix}", range: selectedRange, insertBackspace: 14)
            case "Bracket Matrix":
                smartInsert("\\begin{bmatrix}\n\t \n\\end{bmatrix}", range: selectedRange, insertBackspace: 14)
            case "Braces Matrix":
                smartInsert("\\begin{Bmatrix}\n\t \n\\end{Bmatrix}", range: selectedRange, insertBackspace: 14)
            case "Vertical Matrix":
                smartInsert("\\begin{vmatrix}\n\t \n\\end{vmatrix}", range: selectedRange, insertBackspace: 14)
            case "Double-Vertical Matrix":
                smartInsert("\\begin{Vmatrix}\n\t \n\\end{Vmatrix}", range: selectedRange, insertBackspace: 14)
            case "Cases":
                smartInsert("\\begin{cases}\n\ta & \\text{if } b \\\\\n\tc & \\text{if } d\n\\end{cases}", range: selectedRange, smartMode: false, insertBackspace: 50, insertSelectionLength: 38)
            case "Table":
                smartInsert("\\def\\arraystretch{1.5}\n\\begin{array}{c|c:c}\n\ta & b & c \\\\ \\hline\n\td & e & f \\\\ \\hdashline\n\tg & h & i\n\\end{array}", range: selectedRange, smartMode: false, insertBackspace: 69, insertSelectionLength: 57)
            case "Cancel (Left)":
                smartInsert("\\cancel{ }", range: selectedRange, insertBackspace: 1)
            case "Cancel (Right)":
                smartInsert("\\bcancel{ }", range: selectedRange, insertBackspace: 1)
            case "Cancel (X)":
                smartInsert("\\xcancel{ }", range: selectedRange, insertBackspace: 1)
            case "Strike Through":
                smartInsert("\\sout{ }", range: selectedRange, insertBackspace: 1)
            case "Overline":
                smartInsert("\\overline{ }", range: selectedRange, insertBackspace: 1)
            case "Underline":
                smartInsert("\\underline{ }", range: selectedRange, insertBackspace: 1)
            case "Overbrace":
                smartInsert("\\overbrace{ }^{}", range: selectedRange, insertBackspace: 4, encapsulateBackspace: 1)
            case "Underbrace":
                smartInsert("\\underbrace{ }^{}", range: selectedRange, insertBackspace: 4, encapsulateBackspace: 1)
            case "Over Left Arrow":
                smartInsert("\\overleftarrow{ }", range: selectedRange, insertBackspace: 1)
            case "Over Right Arrow":
                smartInsert("\\overrightarrow{ }", range: selectedRange, insertBackspace: 1)
            case "Vector":
                smartInsert("\\vec{ }", range: selectedRange, insertBackspace: 1)
            case "Hat":
                smartInsert("\\hat{ }", range: selectedRange, insertBackspace: 1)
            case "Bar":
                smartInsert("\\bar{ }", range: selectedRange, insertBackspace: 1)
            case "Box":
                smartInsert("\\boxed{ }", range: selectedRange, insertBackspace: 1)
            case "Toggle Mode":
                let selectedText = (self.contentTextView.string as NSString).substring(with: selectedRange)
                let entireRange = NSRange(location: selectedRange.location - 1, length: selectedRange.length + 2)
                if (self.contentTextView.string as NSString).substring(with: entireRange) == "$\(selectedText)$" {
                    self.contentTextView.insertText(selectedText, replacementRange: entireRange)
                } else {
                    smartInsert("$ $", range: selectedRange, insertBackspace: 1)
                }
            default:
                print("Unknown command.")
                return
            }
        }
        
        // live render if enabled
        if self.document.content.configuration.liveRender {
            self.renderText()
        } else {
            // otherwise, just update the outline
            self.sidebar.updateOutline(preprocessText: true)
        }
        
    }
    
    /**
     Action sent when the user interacts with the controls in the bar.
     
     Marks the document as "edited" (change done) and renders the content.
     */
    @IBAction func barConfigChanged(_ sender: Any) {
        self.document.updateChangeCount(.changeDone)
        self.renderText()
    }
    
    /**
     Presents a panel for the document's current configuration as a sheet.
     
     This method is marked Objective-C as it is used as the target for the "Render > Configuration" menu item.
     */
    @objc func presentConfigView() {
        self.newConfig = (self.document.content.configuration.copy() as! Configuration)
        let configView = ConfigView(config: self.newConfig,
                                    editor: self)
        self.configView = NSHostingController(rootView: configView)
        self.presentAsSheet(self.configView)
    }
    
    /**
     Dismisses the `configView` sheet view.
     
     This method is invoked from within an instance of `ConfigView` when cancel/done action is received.
     It is only when the user clicks "Done" that the new configuration object is saved as the document's current configuration object.
     
     This method resets `configView` and `newConfig` back to `nil`, ensuring that any attempt to access these objects without a proper context would result in a fatal error.
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
    
    /**
     Renders the content and conditionally updates the outline.
     
     This intermediate method renders the content as KaTeX and then conditionally loads or reloads the outline.
     
     - Parameter updateOutline: Whether or not this method should update the outline. Set this to `false` when rendering content without updating the outline.
     */
    func renderText(updateOutline: Bool = true) {
        self.katexView.render()
        if updateOutline {
            self.sidebar.updateOutline()
        }
    }
    
    /**
     Highlights the text in a given range in the text view and its corresponding rendered content in the KaTeX view.
     
     This method first scrolls the text view's scroll view to where the text range is in the text view, and then trigger the temporary highlighting effect on the desired portion of the text.
     Finally, it highlights the corresponding rendered content in the web view by evaluating dedicated JavaScript scripts, which is achieved by calling a dedicated JavaScript function through the  which takes in the
     
     - Parameters:
        - range: The text range to be highlighted.
        - index: The index of the text's corresponding outline entry.
     
     - Note: The logic for highlighting content in the web view is not implemented here but in the template HTML file (within a `<script>` tag).
     
     For more details regarding how the JavaScript function is defined, please visit the template HTML file.
     */
    func reveal(_ range: NSRange, index: Int) {
        self.contentTextView.scrollRangeToCenter(range, animated: true) {
            self.contentTextView.showFindIndicator(for: range)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            self.katexView.evaluateJavaScript("reveal(\(index));")
        }
    }
    
    /**
     Presents a panel for adding a bookmark as a sheet.
     
     This method is marked Objective-C as it is used as the target for the "Add Bookmark..." menu item in the main menu and text view's contextual menu.
     
     - Note: The `bookmarkEditor` handles the dismissal on its own, which involves `nil`-ifying itself.
     This is because the `BookmarkEntry` view is primarily managed by `BookmarksPane` and, by design, has required access to the document's content object.
     There is no reason to derive a separate logic for dismissal and conditional action and not make use of the existing scheme, let alone it is required for the communication between `BookmarksPane` and `BookmarkEntry`.
     */
    @objc func addBookmark() {
        let ranges = self.contentTextView.selectedRanges as! [NSRange]
        let newEntry = BookmarkEntry.new(ranges)
        let bookmarkEditor = BookmarkEditor(editor: self, fileObject: self.document.content, newEntry: newEntry)
        self.bookmarkEditor = NSHostingController(rootView: bookmarkEditor)
        self.presentAsSheet(self.bookmarkEditor)
    }
    
}

extension Editor: WKNavigationDelegate {
    
    /**
     Inherited from `WKNavigationDelegate` - Custom behavior upon the web view loading its content for the first time.
     
     As soon as the web view finishes loading its content from the HTML file for the first time:
     1. Moves cursor to the last cursor position saved in file.
     2. Simulates user interaction by directly invoking `textView(_:didInteract:)` to select matching outline entry and conditionally scroll to corresponding section if "line to line" is enabled.
     _(This also redundantly updates cursor position.)_
     3. Finalize loading the web view by adjusting the layout.
     */
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        let cursorPosition = self.document.content.configuration.cursorPosition
        let cursorRange = NSRange(location: cursorPosition, length: 0)
        self.contentTextView.setSelectedRange(cursorRange)
        
        // simulate user interaction: select matching outline entry
        // and scroll to corresponding section if line-to-line is enabled
        (self.contentTextView.delegate as? TextViewDelegate)?.textView(self.contentTextView, didInteract: cursorRange)
        
        // render for the first time
        self.renderText()
        
        webView.evaluateJavaScript("document.readyState", completionHandler: { (complete, _) in
            if complete != nil {
                webView.evaluateJavaScript("document.body.scrollHeight", completionHandler: { (height, _) in
                    webView.frame.size.height = height as! CGFloat
                    webView.layoutSubtreeIfNeeded()
                    
                    webView.evaluateJavaScript("isDarkMode = \(self.katexView.isDarkMode);")
                })
            }
        })
    }
    
}

extension Editor: TextViewDelegate {
    
    /**
     Custom behavior upon the text changing.
     
     It does the following:
     1. Appends a new line at EOF when one is missing.
     2. Updates the outline
     3. Conditionally renders the content.
     */
    func textDidChange(_ notification: Notification) {
        if self.document.content.contentString.last != "\n" {
            let previousRange = self.contentTextView.selectedRange()
            self.document.content.contentString += "\n"
            self.contentTextView.setSelectedRange(previousRange)
        }
        
        // refresh outline
        self.sidebar.updateOutline(preprocessText: true)
        
        // live render
        if self.document.content.configuration.liveRender {
            self.renderText(updateOutline: false)
        }
    }
    
    /**
     Inherited from `TextViewDelegate` - Custom behavior upon user interaction with the text view.
     
     It does the following:
     1. Selects (without highlighting) row that matches the current editing range from outline.
     2. Updates file's cursor position.
     3. Line to line: Live scrolls the rendered content to section that matches the current editing range by evaluating dedicated JavaScript scripts.
     
     - Note: The logic for scrolling content in the web view is not implemented here but in the template HTML file (within a `<script>` tag).
     
     For more details regarding how the JavaScript function is defined, please visit the template HTML file.
     */
    func textView(_ textView: ATextView, didInteract selectedRange: NSRange) {
        var correspondingRange: NSRange?
        for (index, (range, _)) in self.katexView.rangeMap.enumerated() {
            if range.contains(selectedRange.location) || selectedRange.location == range.upperBound {
                // if it's within the line range
                correspondingRange = range
                // print("\(selectedRange) is in line range \(range)")
            } else if selectedRange.location > range.upperBound {
                // else if it's beyond the line range
                // move on to the next line
                // print("\(selectedRange) is beyond the range \(range), move on to next line range: \(self.katexView.rangeMap.keys[index + 1])")
                continue
            } else if selectedRange.location < range.location {
                // else if not in the next line range
                // set to corresponding range to the previous
                correspondingRange = self.katexView.rangeMap.keys[index - 1]
                // print("\(selectedRange) does not reach the range \(range), take the previous range \(correspondingRange)")
            }
            // print("break using range \(correspondingRange)")
            break
        }
        guard let range = correspondingRange,
              let index = self.katexView.rangeMap.keys.firstIndex(of: range) else {
            return
        }
        // select row without highlighting
        let outlinePane = self.sidebar.panes[.outline] as! OutlinePane
        outlinePane.bypassRevealOnSelectionChange = true
        outlinePane.outlineTableView.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
        outlinePane.outlineTableView.scrollRowToVisible(index)
        
        let docConfig = self.document.content.configuration
        
        // update cursor position
        docConfig.cursorPosition = selectedRange.location
        
        // line to line enabled
        if docConfig.lineToLine {
            self.katexView.evaluateJavaScript(index == self.previouslyIndicatedLine ? "scrollLineToVisible(\(index));" : "reveal(\(index));")
            self.previouslyIndicatedLine = index
        }
    }
    
}
