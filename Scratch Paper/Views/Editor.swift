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
     
     This property is always `nil` except when the user invokes `addBookmark()` via clicking the "Add Bookmark..." menu item from the `contentTextView`'s contextual menu.
     */
    var bookmarkEditor: NSViewController!
    
    /**
     A weak reference to the associated document object.
     
     Implicitly unwrapped optional is used rather than creating a dummy document object to avoid redundant calls.
     
     - Note: This is set by its superview `MainSplitViewController` when the document object creates a window controller via the `makeWindowControllers()` method.
     */
    @objc dynamic weak var document: Document!
    
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
    
    var timer: Timer?
    
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
        self.contentTextView.string = self.document.content.contentString
        self.contentTextView.initializePlaceholders()
    }
    
    override func viewDidDisappear() {
        super.viewDidDisappear()
        // print("[Editor \(self)] View did disappear.")
        self.katexView.configuration.websiteDataStore.fetchDataRecords(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes()) { records in
            records.forEach { record in
                self.katexView.configuration.websiteDataStore.removeData(ofTypes: record.dataTypes, for: [record]) {
                    NSLog("[Web Cache] Record \(record) purged.")
                }
            }
        }
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
        if self.contentTextView.isCoalescingUndo {
            self.contentTextView.breakUndoCoalescing()
        }
        
        // get selected ranges sorted by their location
        let selectedRanges = (self.contentTextView.selectedRanges as! [NSRange]).sorted(by: { $0.location < $1.location })
        
        var temporaryRange = selectedRanges.first!
        temporaryRange.length = 0
        
        self.contentTextView.setSelectedRange(temporaryRange)
        
        // utility function for text insertion
        func insertItem(_ item: String, _ range: NSRange, _ backspace: Int, _ length: Int = 0) {
            let text = item.replacingOccurrences(of: "!", with: "")
            // replace text range
            let attrString = NSMutableAttributedString(string: text, attributes: [.font : AppSettings.editorFont,
                                                                                  .foregroundColor : NSColor.controlTextColor])
            let pattern = try! NSRegularExpression(pattern: "<@(.*?)@>")
            var placeholders: OrderedDictionary<TextPlaceholder, NSRange> = [:]
            pattern.enumerateMatches(in: text, range: attrString.range) { (result, _, _) in
                let capturedRange = result!.range(at: 1)
                let placeholderText = attrString.attributedSubstring(from: capturedRange).string
                let placeholder = TextPlaceholder(placeholderText)
                placeholders[placeholder] = result!.range
            }
            placeholders.reversed().forEach { (placeholder, range) in
                attrString.replaceCharacters(in: range, with: placeholder.attributedString)
            }
            self.contentTextView.insertText(attrString, replacementRange: range)
            
            var selectedRange = range
            if placeholders.isEmpty {
                // select proper range
                selectedRange.location = selectedRange.location + attrString.length - backspace
                selectedRange.length = length
                
                return self.contentTextView.setSelectedRange(selectedRange)
            }
            selectedRange.length = 0
            self.contentTextView.setSelectedRange(selectedRange)
            self.contentTextView.insertTab(sender)
        }
        
        if let menuItemTag = (sender as? NSMenuItem)?.tag, menuItemTag == 24 {
            let greekLettersCommand = "\\\(command.replacingOccurrences(of: ")", with: "").components(separatedBy: "(").last!)"
            for selectedRange in selectedRanges.reversed() {
                insertItem(greekLettersCommand, selectedRange, 0)
            }
            return
        }
        
        // utility function for text wrapping
        func wrapItem(_ left: String, _ right: String, _ range: NSRange, offset: Int? = nil) {
            let text = self.contentTextView.string as NSString
            let selectedText = text.substring(with: range)
            
            let placeholderRegex = try! NSRegularExpression(pattern: "<@(.*?)@>")
            let replaceableRegex = try! NSRegularExpression(pattern: "<@(.*?)@>!")
            
            let leftStripped = NSMutableString(string: left)
            let leftRange = NSMakeRange(0, leftStripped.length)
            placeholderRegex.replaceMatches(in: leftStripped, range: leftRange, withTemplate: "")
            let rightStripped = NSMutableString(string: right)
            var rightRange = NSMakeRange(0, rightStripped.length)
            replaceableRegex.replaceMatches(in: rightStripped, range: rightRange, withTemplate: "")
            rightRange.length = rightStripped.length
            placeholderRegex.replaceMatches(in: rightStripped, range: rightRange, withTemplate: "")
            
            // if within entire range
            let (leftLength, rightLength) = (leftStripped.length, rightStripped.length)
            if (range.location > leftLength - 1) && (range.upperBound < text.length - rightLength + 1) {
                // check if the selected text is already wrapped with the pattern
                let checkRange = NSMakeRange(range.location - leftLength, range.length + leftLength + rightLength)
                let checkString = text.substring(with: checkRange)
                
                if checkString == leftStripped.string + selectedText + rightStripped.string {
                    // unwrap the item
                    self.contentTextView.insertText(selectedText, replacementRange: checkRange)
                    
                    self.contentTextView.selectedRanges.append(checkRange as NSValue)
                    return
                }
            }
            
            // entire replacement rather than individual right/left insertion
            let leftText = NSMutableAttributedString(string: left)
            var leftPlaceholders: OrderedDictionary<TextPlaceholder, NSRange> = [:]
            placeholderRegex.enumerateMatches(in: leftText.string, range: leftText.range) { (result, _, _) in
                let capturedRange = result!.range(at: 1)
                let placeholderText = leftText.attributedSubstring(from: capturedRange).string
                let placeholder = TextPlaceholder(placeholderText)
                leftPlaceholders[placeholder] = result!.range
            }
            leftPlaceholders.reversed().forEach { (placeholder, range) in
                leftText.replaceCharacters(in: range, with: placeholder.attributedString)
            }
            let rightText = NSMutableAttributedString(string: right)
            let matches = replaceableRegex.matches(in: rightText.string, range: rightText.range)
            if !matches.isEmpty {
                matches.reversed().forEach { result in
                    rightText.deleteCharacters(in: result.range)
                }
            }
            var rightPlaceholders: OrderedDictionary<TextPlaceholder, NSRange> = [:]
            placeholderRegex.enumerateMatches(in: rightText.string, range: rightText.range) { (result, _, _) in
                let capturedRange = result!.range(at: 1)
                let placeholderText = rightText.attributedSubstring(from: capturedRange).string
                let placeholder = TextPlaceholder(placeholderText)
                rightPlaceholders[placeholder] = result!.range
            }
            rightPlaceholders.reversed().forEach { (placeholder, range) in
                rightText.replaceCharacters(in: range, with: placeholder.attributedString)
            }
            
            let replacementText = NSMutableAttributedString(string: selectedText)
            replacementText.insert(leftText, at: 0)
            replacementText.append(rightText)
            
            self.contentTextView.insertText(replacementText, replacementRange: range)
            
            var newRange = NSMakeRange(range.location, replacementText.length)
            if !leftPlaceholders.isEmpty {
                self.contentTextView.textStorage!.enumerateAttribute(.attachment, in: newRange) { (attachment, attachmentRange, shouldAbort) in
                    if let _ = attachment as? TextPlaceholder {
                        if selectedRanges.count == 1 {
                            newRange.length = 0
                            self.contentTextView.setSelectedRange(newRange)
                            self.contentTextView.insertTab(nil)
                        } else {
                            self.contentTextView.selectedRanges.append(attachmentRange as NSValue)
                        }
                        shouldAbort.pointee = true
                    }
                }
            } else if !rightPlaceholders.isEmpty {
                newRange.location += leftText.length
                newRange.length -= leftText.length
                self.contentTextView.textStorage!.enumerateAttribute(.attachment, in: newRange) { (attachment, attachmentRange, shouldAbort) in
                    if let _ = attachment as? TextPlaceholder {
                        if selectedRanges.count == 1 {
                            newRange.length = 0
                            self.contentTextView.setSelectedRange(newRange)
                            self.contentTextView.insertTab(nil)
                        } else {
                            self.contentTextView.selectedRanges.append(attachmentRange as NSValue)
                        }
                        shouldAbort.pointee = true
                    }
                }
            } else {
                newRange.length = 0
                if let offset = offset, offset != 0 {
                    if offset > 0 {
                        // positive offset
                        newRange.location += leftText.length + offset
                    } else {
                        // negative offset
                        newRange.location = newRange.lowerBound + offset
                    }
                }
                return self.contentTextView.selectedRanges.append(newRange as NSValue)
            }
        }
        
        // heuristic function for handling text insertion/wrapping
        func smartInsert(_ pattern: String, range: NSRange, smartMode: Bool = true, override: (String?, String?) = (nil, nil), insertSelectionLength: Int = 0, wrappingOffset: Int? = nil) {
            let components = pattern.components(separatedBy: "#")
            
            let overriddenWrapping = override.1?.components(separatedBy: "#")
            let left = overriddenWrapping?.first ?? components[0]
            let right = overriddenWrapping?.last ?? components[1]
            
            let rightLength = (right as NSString).length
            let overriddenRightLength = (override.0?.components(separatedBy: "#").last as? NSString)?.length
            
            let overriddenInsertion = override.0?.replacingOccurrences(of: "#", with: "")
            
            // auto-decides only when smart mode is on
            guard smartMode else {
                // just insert item regardless
                insertItem(overriddenInsertion ?? components.joined(), range,
                           overriddenRightLength ?? rightLength, insertSelectionLength)
                return
            }
            guard range.length > 0 else {
                // insert item
                insertItem(overriddenInsertion ?? components.joined(), range,
                           overriddenRightLength ?? rightLength, insertSelectionLength)
                return
            }
            // wrap item
            wrapItem(left, right, range, offset: wrappingOffset)
        }
        
        // perform text insertion/wrapping for selected ranges starting at the furthest
        for selectedRange in selectedRanges.reversed() {
            switch command {
            case "Fraction":
                smartInsert("\\frac{#<@numerator@>!}{<@denominator@>}",
                            range: selectedRange)
            case "Exponent":
                smartInsert("", range: selectedRange, override: ("^{#<@exponent@>}", "{#}^{<@exponent@>}"), wrappingOffset: 3)
            case "Square Root":
                smartInsert("\\sqrt{#<@radicand@>!}",
                            range: selectedRange)
            case "Root":
                smartInsert("\\sqrt[<@degree@>]{#<@radicand@>!}",
                            range: selectedRange, wrappingOffset: -2)
            case "Smart Parentheses":
                smartInsert("\\left(#<@expression@>!\\right)",
                            range: selectedRange)
            case "Indefinite Integral":
                smartInsert("\\int{#<@integrand@>!}",
                            range: selectedRange)
            case "Definite Integral":
                smartInsert("\\int_{#<@lower bound@>!}^{<@upper bound@>}<integrand>",
                            range: selectedRange, wrappingOffset: 3)
            case "Sum":
                smartInsert("\\sum_{#<@index@>!}^{<@upper bound@>}<expression>",
                            range: selectedRange, wrappingOffset: 3)
            case "Product":
                smartInsert("\\prod_{#<@index@>!}^{<@upper bound@>}<expression>",
                            range: selectedRange, wrappingOffset: 3)
            case "Limit":
                smartInsert("\\lim_{#<@limit@>!}",
                            range: selectedRange)
            case "Binomial":
                smartInsert("\\binom_{#<@n@>!}{<@k@>}",
                            range: selectedRange, wrappingOffset: 2)
            case "Aligned":
                smartInsert("\\begin{aligned}\n\t#<@expression@>!\n\\end{aligned}",
                            range: selectedRange)
            case "Array":
                smartInsert("\\begin{array}{cc}\n\t#<@expression@>!\n\\end{array}",
                            range: selectedRange)
            case "Matrix":
                smartInsert("\\begin{matrix}\n\t#<@expression@>!\n\\end{matrix}",
                            range: selectedRange)
            case "Parenthesis Matrix":
                smartInsert("\\begin{pmatrix}\n\t#<@expression@>!\n\\end{pmatrix}",
                            range: selectedRange)
            case "Bracket Matrix":
                smartInsert("\\begin{bmatrix}\n\t#<@expression@>!\n\\end{bmatrix}",
                            range: selectedRange)
            case "Braces Matrix":
                smartInsert("\\begin{Bmatrix}\n\t#<@expression@>!\n\\end{Bmatrix}",
                            range: selectedRange)
            case "Vertical Matrix":
                smartInsert("\\begin{vmatrix}\n\t#<@expression@>!\n\\end{vmatrix}",
                            range: selectedRange)
            case "Double-Vertical Matrix":
                smartInsert("\\begin{Vmatrix}\n\t#<@expression@>!\n\\end{Vmatrix}",
                            range: selectedRange)
            case "Cases":
                smartInsert("\\begin{cases}\n\t#<@expression@>!a & \\text{if } b \\\\\n\tc & \\text{if } d\n\\end{cases}",
                            range: selectedRange, smartMode: false, insertSelectionLength: 38)
            case "Table":
                smartInsert("\\def\\arraystretch{1.5}\n\\begin{array}{c|c:c}\n\t#<@expression@>!a & b & c \\\\ \\hline\n\td & e & f \\\\ \\hdashline\n\tg & h & i\n\\end{array}",
                            range: selectedRange, smartMode: false, insertSelectionLength: 57)
            case "Cancel (Left)":
                smartInsert("\\cancel{#<@expression@>!}",
                            range: selectedRange)
            case "Cancel (Right)":
                smartInsert("\\bcancel{#<@expression@>!}",
                            range: selectedRange)
            case "Cancel (X)":
                smartInsert("\\xcancel{#<@expression@>!}",
                            range: selectedRange)
            case "Strike Through":
                smartInsert("\\sout{#<@expression@>!}",
                            range: selectedRange)
            case "Overline":
                smartInsert("\\overline{#<@expression@>!}",
                            range: selectedRange)
            case "Underline":
                smartInsert("\\underline{#<@expression@>!}",
                            range: selectedRange)
            case "Overbrace":
                smartInsert("\\overbrace{#<@expression@>!}^{<@expression@>}",
                            range: selectedRange, wrappingOffset: 3)
            case "Underbrace":
                smartInsert("\\underbrace{#<@expression@>!}^{<@expression@>}",
                            range: selectedRange, wrappingOffset: 3)
            case "Over Left Arrow":
                smartInsert("\\overleftarrow{#<@expression@>!}",
                            range: selectedRange)
            case "Over Right Arrow":
                smartInsert("\\overrightarrow{#<@expression@>!}",
                            range: selectedRange)
            case "Vector":
                smartInsert("\\vec{#<@v@>!}",
                            range: selectedRange)
            case "Hat":
                smartInsert("\\hat{#<@h@>!}",
                            range: selectedRange)
            case "Bar":
                smartInsert("\\bar{#<@b@>!}",
                            range: selectedRange)
            case "Box":
                smartInsert("\\boxed{#<@expression@>!}",
                            range: selectedRange)
            case "Toggle Mode":
                smartInsert("$#<@expression@>!$",
                            range: selectedRange)
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
            self.sidebar.updateOutline(preprocessText: true)
        }
        
    }
    
    /**
     Action sent when the user interacts with the controls in the bar.
     
     Marks the document as "edited" (change done) and renders the content. The content is rendered regardless of the live render option.
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
    
    deinit {
        // release reference passed to representedObject
        for child in self.children {
            child.representedObject = nil
        }
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
        let cursorRange = NSMakeRange(cursorPosition, 0)
        self.contentTextView.setSelectedRange(cursorRange)
        
        // simulate user interaction: select matching outline entry
        // and scroll to corresponding section if line-to-line is enabled
        (self.contentTextView.delegate as? ATextViewDelegate)?.textView(self.contentTextView, didInteract: cursorRange)
        
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

extension Editor: ATextViewDelegate {
    
    /**
     Custom behavior upon the text changing.
     
     It does the following:
     1. Appends a new line at EOF when one is missing.
     2. Updates the outline
     3. Conditionally renders the content.
     */
    func textDidChange(_ notification: Notification) {
        let contentString = self.contentTextView.plainText
        var previousRange = self.contentTextView.selectedRange()
        defer {
            if previousRange.location >= self.contentTextView.textLength {
                previousRange.location = self.contentTextView.textLength - 1
            }
            self.contentTextView.setSelectedRange(previousRange)
        }
        if contentString.last != "\n" {
            self.contentTextView.textStorage!.mutableString.append("\n")
        }
        self.document.content.contentString = contentString
        
        // refresh outline
        self.sidebar.updateOutline(preprocessText: true)
        
        // live render
        if self.document.content.configuration.liveRender {
            self.renderText(updateOutline: false)
        }
    }
    
    /**
     Inherited from `ATextViewDelegate` - Custom behavior upon user interaction with the text view.
     
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
