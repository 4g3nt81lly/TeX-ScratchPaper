//
//  ATextView.swift
//  Scratch Paper
//
//  Created by Bingyi Billy Li on 2022/7/4.
//

import Cocoa

/**
 A custom subclass of `NSTextView`.
 
 1. Implements a contextual menu.
 2. Scrolls content view to a character range with animation.
 3. Captures user interactions with the text view.
 4. Helper methods.
 
 Reference: [](https://stackoverflow.com/a/58307677/10446972).
 */
class ATextView: NSTextView {
    
    var textLength: Int {
        return self.textStorage!.length
    }
    
    /**
     A weak reference to the associated document object.
     
     Implicitly unwrapped optional is used rather than creating a dummy document object to avoid redundant calls.
     
     - Note: This is set by its superview `Editor` as it initializes the KaTeX view from `viewDidAppear()`.
     */
    weak var document: Document!
    
    /// The text view's line number ruler view.
    var lineNumberView: LineNumberRulerView!
    
    /**
     Sets the line number view as needing display to redraw its view.
     
     This method is marked Objective-C as it is used as the target for the text view's bound, frame, and text-changing notifications.
     */
    @objc func refreshLineNumberView() {
        self.lineNumberView.needsDisplay = true
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        self.initialize()
    }
    
    weak var customLayoutManager: LayoutManager!
    
    func initialize(withLineNumberView: Bool = true) {
        self.font = .monospacedSystemFont(ofSize: 14.0, weight: .regular)
        self.typingAttributes[.foregroundColor] = NSColor.controlTextColor
        
        self.isAutomaticTextCompletionEnabled = false
        self.isAutomaticTextReplacementEnabled = false
        self.isAutomaticQuoteSubstitutionEnabled = false
        self.isAutomaticDashSubstitutionEnabled = false
        self.isAutomaticLinkDetectionEnabled = false
        
        if withLineNumberView {
            self.lineNumberView = LineNumberRulerView(textView: self)
            if self.font == nil {
                self.font = .systemFont(ofSize: NSFont.systemFontSize)
            }
            let scrollView = self.enclosingScrollView!
            scrollView.verticalRulerView = self.lineNumberView
            scrollView.hasVerticalRuler = true
            scrollView.rulersVisible = true
            
            self.postsFrameChangedNotifications = true
            scrollView.contentView.postsBoundsChangedNotifications = true
            
            notificationCenter.addObserver(self, selector: #selector(refreshLineNumberView),
                                           name: NSView.boundsDidChangeNotification, object: nil)
            notificationCenter.addObserver(self, selector: #selector(refreshLineNumberView),
                                           name: NSView.frameDidChangeNotification, object: nil)
            notificationCenter.addObserver(self, selector: #selector(refreshLineNumberView),
                                           name: NSText.didChangeNotification, object: nil)
        }
        
        let layoutManager = LayoutManager()
        self.customLayoutManager = layoutManager

        self.textContainer!.replaceLayoutManager(layoutManager)
    }
    
    func initializePlaceholders() {
        let text = self.string
        let pattern = try! NSRegularExpression(pattern: "<@(.*?)@>")
        let matches = pattern.matches(in: text, range: self.textStorage!.range)
        guard !matches.isEmpty else {
            return
        }
        matches.reversed().forEach { result in
            let capturedRange = result.range(at: 1)
            let placeholderText = (text as NSString).substring(with: capturedRange)
            let placeholder = TextPlaceholder(placeholderText)
            self.textStorage!.replaceCharacters(in: result.range, with: placeholder.attributedString)
        }
    }
    
    var plainText: String {
        let attributedString = NSMutableAttributedString(attributedString: self.textStorage!)
        self.placeholderMap.reversed().forEach { (placeholder, range) in
            let plainText = "<@\(placeholder.contentString ?? placeholder.placeholderString)@>"
            attributedString.replaceCharacters(in: range, with: plainText)
        }
        return attributedString.string
    }
    
    var placeholderMap: OrderedDictionary<TextPlaceholder, NSRange> {
        var orderedMap: OrderedDictionary<TextPlaceholder, NSRange> = [:]
        self.textStorage!.enumerateAttribute(.attachment, in: self.textStorage!.range) { (attachment, range, _) in
            guard let placeholder = attachment as? TextPlaceholder else { return }
            orderedMap[placeholder] = range
        }
        return orderedMap
    }
    
    var hasPlaceholder: Bool {
        return !self.placeholderMap.isEmpty
    }
    
    weak var selectedPlaceholder: TextPlaceholder?
    
    var hasSelectedPlaceholder: Bool {
        return self.selectedPlaceholder != nil
    }
    
    // MARK: - Finding Placeholders
    
    func rangeOfPlaceholder(_ placeholder: TextPlaceholder) -> NSRange? {
        return self.placeholderMap[placeholder]
    }
    
    func locationOfPlaceholder(_ placeholder: TextPlaceholder) -> Int? {
        return self.rangeOfPlaceholder(placeholder)?.location
    }
    
    func placeholder(at range: NSRange) -> TextPlaceholder? {
        guard range.length == 1,
              range.upperBound <= self.textLength else {
            return nil
        }
        return self.placeholder(at: range.location)
    }
    
    func placeholder(at location: Int) -> TextPlaceholder? {
        guard location >= 0 && location < self.textLength else {
            return nil
        }
        let fullRange = self.textStorage!.range
        return self.textStorage!.attribute(.attachment, at: location, longestEffectiveRange: nil,
                                           in: fullRange) as? TextPlaceholder
    }
    
    func firstPlaceholder(in range: NSRange) -> TextPlaceholder? {
        guard self.hasPlaceholder else {
            return nil
        }
        var placeholder: TextPlaceholder?
        self.textStorage!.enumerateAttribute(.attachment, in: range) { (attachment, _, shouldAbort) in
            if let placeholderObject = attachment as? TextPlaceholder {
                placeholder = placeholderObject
                shouldAbort.pointee = true
            }
        }
        return placeholder
    }
    
    func allPlaceholders(in range: NSRange) -> [TextPlaceholder] {
        var selectedPlaceholders: [TextPlaceholder] = []
        guard range.location != 0 else {
            if let placeholder = self.placeholder(at: range.location) {
                return [placeholder]
            }
            return []
        }
        self.textStorage!.enumerateAttribute(.attachment, in: range) { (attachment, placeholderRange, _) in
            guard let placeholder = attachment as? TextPlaceholder else {
                return
            }
            if range.contains(placeholderRange.location) {
                selectedPlaceholders.append(placeholder)
            }
        }
        return selectedPlaceholders
    }
    
    func nearestPlaceholder(from location: Int, lookAhead aheadLength: Int = 0, shouldLoop: Bool = true) -> TextPlaceholder? {
        guard self.hasPlaceholder else {
            return nil
        }
        let startingIndex = max(0, location - aheadLength)
        let toEndRange = NSMakeRange(startingIndex, self.textLength - startingIndex)
        let endPlaceholder = self.firstPlaceholder(in: toEndRange)
        // if already found placeholder OR shouldn't loop, return
        if endPlaceholder != nil || !shouldLoop {
            return endPlaceholder
        }
        // otherwise, search from the beginning
        let fromStartRange = NSMakeRange(0, self.textLength - toEndRange.length)
        return self.firstPlaceholder(in: fromStartRange)
    }
    
    func nextPlaceholder(to placeholder: TextPlaceholder, shouldLoop: Bool = true) -> TextPlaceholder? {
        guard self.placeholderMap.count > 1,
              let location = self.locationOfPlaceholder(placeholder) else {
            return nil
        }
        let sortedPlaceholders = self.placeholderMap.sorted { $0.1.location < $1.1.location }
        if let nextPlaceholder = sortedPlaceholders.first(where: { $0.1.location > location }) {
            return nextPlaceholder.0
        } else if shouldLoop {
            return sortedPlaceholders.first?.0
        }
        return nil
    }
    
    // MARK: - Manipulating Placeholders
    
    func insertPlaceholder(_ placeholder: TextPlaceholder, at location: Int) {
        let range = NSMakeRange(location, 0)
        self.insertText(placeholder.attributedString, replacementRange: range)
    }
    
    func appendPlaceholder(_ placeholder: TextPlaceholder) {
        let range = NSMakeRange(self.textLength, 0)
        self.insertText(placeholder.attributedString, replacementRange: range)
    }
    
    func deletePlaceholder(_ placeholder: TextPlaceholder) {
        if var range = self.rangeOfPlaceholder(placeholder) {
            self.selectedPlaceholder = nil
            self.insertText("", replacementRange: range)
            range.length = 0
            self.setSelectedRange(range)
        }
    }
    
    func placeholder(at point: NSPoint) -> TextPlaceholder? {
        let pointInTextContainer = self.convertToTextContainer(point)
        guard let location = self.customLayoutManager.characterIndex(for: pointInTextContainer,
                                                                     in: self.textContainer!) else { return nil }
        return self.placeholder(at: location)
    }
    
    /**
     Calls the necessary methods to redraw the specified placeholder as highlighted or unhighlighted.
     
     - Parameters:
        - placeholder: The placeholder that will be redrawn.
        - flag: When `true`, redraws the placeholder as highlighted; otherwise, redraws it normally.
     */
    func highlightPlaceholder(_ placeholder: TextPlaceholder, _ flag: Bool) {
        if let range = self.rangeOfPlaceholder(placeholder) {
            placeholder.cell.highlight(flag, withFrame: placeholder.bounds, in: self)
            self.customLayoutManager.invalidateDisplay(forGlyphRange: range)
        }
    }
    
    func selectPlaceholder(_ placeholder: TextPlaceholder) {
        if placeholder != self.selectedPlaceholder {
            self.deselectPlaceholder()
            self.highlightPlaceholder(placeholder, true)
            self.selectedPlaceholder = placeholder
            
            if let location = self.locationOfPlaceholder(placeholder) {
                let range = NSMakeRange(location, 1)
                self.setSelectedRange(range)
            }
        }
    }
    
    func deselectPlaceholder() {
        if let placeholder = self.selectedPlaceholder {
            self.highlightPlaceholder(placeholder, false)
            self.selectedPlaceholder = nil
        }
    }
    
    /**
     Replaces the placeholder with its text contents.
     
     - Parameter placeholder: The placeholder to replace.
     */
    func makePlaceholderText(_ placeholder: TextPlaceholder) {
        if let range = self.rangeOfPlaceholder(placeholder) {
            let replacementString = placeholder.contentString ?? placeholder.placeholderString
            let attributedString = NSAttributedString(string: replacementString,
                                                      attributes: [.font : AppSettings.editorFont,
                                                                   .foregroundColor : NSColor.controlTextColor])
            self.selectedPlaceholder = nil
            self.insertText(attributedString, replacementRange: range)
        }
    }
    
    private func handlePlaceholderAction(_ action: TextPlaceholder.UserAction, for placeholder: TextPlaceholder) {
        if let replacementAction = (self.delegate as? ATextViewDelegate)?.textView(self, placeholderUserAction: action, for: placeholder) {
            switch replacementAction {
            case .delete:
                self.deletePlaceholder(placeholder)
            case .insert:
                self.makePlaceholderText(placeholder)
            default:
                break
            }
        }
    }
    
    /// Contextual menu for text view.
    override func menu(for event: NSEvent) -> NSMenu? {
        let menu = NSMenu()
        let pasteItem = NSMenuItem(title: "Paste", action: #selector(self.pasteAsPlainText(_:)), keyEquivalent: "")
        // if there's selected content
        guard self.selectedRange().length > 0 else {
            menu.addItem(pasteItem)
            return menu
        }
        menu.addItem(withTitle: "Copy", action: #selector(self.copy(_:)), keyEquivalent: "")
        menu.addItem(pasteItem)
        menu.addItem(withTitle: "Cut", action: #selector(self.cut(_:)), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Add Bookmark...", action: #selector(document.editor.addBookmark), keyEquivalent: "")
        
        return menu
    }
    
    /**
     Calculates rect of a given character range.
     
     Reference: [](https://stackoverflow.com/a/8919401/10446972).
     
     Objective-C Reference: [](https://stackoverflow.com/questions/11154157/how-to-calculate-correct-coordinates-for-selected-text-in-nstextview/11155388).
     
     - Parameter characterRange: A character range.
     */
    func rectForRange(_ characterRange: NSRange) -> NSRect {
        var layoutRect: NSRect
        
        // get glyph range for characters
        let textRange = self.layoutManager!.glyphRange(forCharacterRange: characterRange, actualCharacterRange: nil)
        let textContainer = self.textContainer!
        
        // get rect at glyph range
        layoutRect = self.layoutManager!.boundingRect(forGlyphRange: textRange, in: textContainer)
        
        // get rect relative to the text view
        let containerOrigin = self.textContainerOrigin
        layoutRect.origin.x += containerOrigin.x
        layoutRect.origin.y += containerOrigin.y
        
        // layoutRect = self.convertToLayer(layoutRect)
        
        return layoutRect
    }
    
    /**
     Scrolls a given range to center of the text view, animated.
     
     This method uses `rectForRange(_:)` to determine the rect of a given character range, and then scrolls the range to the center of the text view by invoking `scroll(toPoint:animationDuration:completionHandler:)`, with or without an animation.
     
     - Parameters:
        - range: A character range.
        - animated: A flag indicating whether or not the scroll should be animated.
        - completionHandler: A closure to be executed when the animation is complete.
     */
    func scrollRangeToCenter(_ range: NSRange, animated: Bool, completionHandler: (() -> Void)? = nil) {
        guard animated else {
            super.scrollRangeToVisible(range)
            return
        }
        // move down half the height to center
        var rect = self.rectForRange(range)
        rect.origin.y -= (self.enclosingScrollView!.contentView.frame.height - rect.height) / 2 - 10
        
        (self.enclosingScrollView as! AScrollView).scroll(toPoint: rect.origin, animationDuration: 0.25, completionHandler: completionHandler)
    }
    
    /**
     Converts a point from the coordinate system of the text view to that of the text container view.
     
     - Parameter point: A point specifying a location in the coordinate system of text view.
     
     - Returns: The point converted to the coordinate system of the text view's text container.
     */
    func convertToTextContainer(_ point: NSPoint) -> NSPoint {
        return NSPoint(x: point.x - self.textContainerOrigin.x,
                       y: point.y - self.textContainerOrigin.y)
    }
    
    /// Invokes `textView(_:didInteract:)` to notify for user interaction.
    override func keyDown(with event: NSEvent) {
        super.keyDown(with: event)
        (self.delegate as? ATextViewDelegate)?.textView(self, didInteract: self.selectedRange())
    }
    
    /// Invokes `textView(_:didInteract:)` to notify for user interaction.
    override func mouseDown(with event: NSEvent) {
        (self.delegate as? ATextViewDelegate)?.textView(self, didInteract: self.selectedRange())
        
        let point = self.convert(event.locationInWindow, from: nil)
        guard let placeholder = self.placeholder(at: point) else {
            self.deselectPlaceholder()
            return super.mouseDown(with: event)
        }
        if placeholder != self.selectedPlaceholder {
            self.selectPlaceholder(placeholder)
        } else if event.clickCount > 1 {
            self.handlePlaceholderAction(.doubleClick, for: placeholder)
        }
    }
    
    override func insertTab(_ sender: Any?) {
        if let selectedPlaceholder = self.selectedPlaceholder,
           let nextPlaceholder = self.nextPlaceholder(to: selectedPlaceholder) {
            return self.selectPlaceholder(nextPlaceholder)
        }
        let currentLocation = self.selectedRange().location
        let lineRange = self.document.editor.katexView.rangeMap.first(where: { $0.0.contains(currentLocation) })?.0
        if let nearestPlaceholder = self.nearestPlaceholder(from: lineRange?.location ?? currentLocation) {
            return self.selectPlaceholder(nearestPlaceholder)
        }
        super.insertTab(sender)
    }
    
    override func insertNewline(_ sender: Any?) {
        if let selectedPlaceholder = self.selectedPlaceholder {
            return self.handlePlaceholderAction(.enter, for: selectedPlaceholder)
        }
        super.insertNewline(sender)
    }
    
    override func deleteBackward(_ sender: Any?) {
        if let selectedPlaceholder = self.selectedPlaceholder {
            return self.handlePlaceholderAction(.delete, for: selectedPlaceholder)
        }
        super.deleteBackward(sender)
    }
    
    override func deleteWordBackward(_ sender: Any?) {
        if let selectedPlaceholder = self.selectedPlaceholder {
            return self.handlePlaceholderAction(.delete, for: selectedPlaceholder)
        }
        super.deleteWordBackward(sender)
    }
    
    override func deleteForward(_ sender: Any?) {
        if let selectedPlaceholder = self.selectedPlaceholder {
            self.handlePlaceholderAction(.delete, for: selectedPlaceholder)
        } else {
            super.deleteForward(sender)
        }
    }
    
    override func moveLeft(_ sender: Any?) {
        let range = self.selectedRange()

        if self.hasSelectedPlaceholder {
            // deselect it and call super (which will move the insertion point to the left side of the pill)
            // there may be a neighboring pill to the left: need to check before the next one
            self.deselectPlaceholder()
        } else if range.length == 0,
                  let placeholder = self.placeholder(at: range.location - 1) {
            // no current selection and previous index is a placeholder
            return self.selectPlaceholder(placeholder)
        }
        
        super.moveLeft(sender)
    }
    
    override func moveRight(_ sender: Any?) {
        let range = self.selectedRange()

        if self.hasSelectedPlaceholder {
            // deselect it and call super (which will move the insertion point to the right side of the pill)
            // there may be a neighboring pill to the right: need to check before the next one
            self.deselectPlaceholder()
        } else if range.length == 0,
                  let placeholder = self.placeholder(at: range.location) {
            // no current selection and previous index is a placeholder
            return self.selectPlaceholder(placeholder)
        }
        
        super.moveRight(sender)
    }
    
    override func setSelectedRange(_ charRange: NSRange, affinity: NSSelectionAffinity, stillSelecting stillSelectingFlag: Bool) {
        if let placeholder = self.placeholder(at: charRange) {
            self.selectPlaceholder(placeholder)
        } else {
            self.deselectPlaceholder()
        }
        super.setSelectedRange(charRange, affinity: affinity, stillSelecting: stillSelectingFlag)
    }
    
    override open func writeSelection(to pboard: NSPasteboard, type: NSPasteboard.PasteboardType) -> Bool {
        let range = self.selectedRange()
        let substring = self.textStorage!.attributedSubstring(from: range)
        
        if self.textStorage!.containsAttachments(in: range) {
            let attributedString = NSMutableAttributedString(attributedString: substring)
            
            attributedString.enumerateAttribute(.attachment, in: attributedString.range,
                                                options: .longestEffectiveRangeNotRequired) { (attachment, placeholderRange, _) in
                guard let placeholder = attachment as? TextPlaceholder else { return }
                attributedString.replaceCharacters(in: placeholderRange,
                                                   with: placeholder.contentString ?? placeholder.placeholderString)
            }
            pboard.clearContents()
            pboard.writeObjects([attributedString.mutableString])
            return true
        }
        return super.writeSelection(to: pboard, type: type)
    }
    
    deinit {
        // removes all observers upon release
        notificationCenter.removeObserver(self)
    }
    
}

protocol ATextViewDelegate: NSTextViewDelegate, NSTextStorageDelegate {
    
    /**
     Implement to specify custom behavior upon user interaction with the target text view.
     
     This protocol method is invoked whenever the user interacts with the text view.
     
     - Parameters:
        - textView: The text view.
        - selectedRange: The range selected by the user.
     */
    func textView(_ textView: ATextView, didInteract selectedRange: NSRange)
    
    /**
     Returns the replacement action to perform on the given selected placeholder for the user interaction.
     
     - Parameters:
        - textView: The text view that contains the selected placeholder the user interacted with.
        - userAction: The type of interaction the user performed on the selected placeholder.
        - placeholder: The selected placeholder the user interacted with.
     
     - Returns: The replacement action for the selected placeholder.
     */
    func textView(_ textView: ATextView, placeholderUserAction userAction: TextPlaceholder.UserAction, for placeholder: TextPlaceholder) -> TextPlaceholder.ReplacementAction
    
}

extension ATextViewDelegate {
    
    func textView(_ textView: ATextView, placeholderUserAction userAction: TextPlaceholder.UserAction, for placeholder: TextPlaceholder) -> TextPlaceholder.ReplacementAction {
        switch userAction {
        case .delete:
            return .delete
        default:
            return .insert
        }
    }
    
}
