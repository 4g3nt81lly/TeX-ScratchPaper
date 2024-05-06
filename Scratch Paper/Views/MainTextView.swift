import Cocoa

/**
 A custom subclass of `NSTextView`.
 
 1. Implements a contextual menu.
 2. Scrolls content view to a character range with animation.
 3. Captures user interactions with the text view.
 4. Helper methods.
 
 Reference: [](https://stackoverflow.com/a/58307677/10446972).
 */
class MainTextView: NSTextView, EditorControllable {
    
    /// The text view's line number ruler view.
    var rulerView: MainTextViewRulerView!
    
    var customLayoutManager: MainTextViewLayoutManager {
        return self.layoutManager as! MainTextViewLayoutManager
    }
    
    private var placeholders: OrderedDictionary<TextPlaceholder, NSRange> {
        var orderedMap: OrderedDictionary<TextPlaceholder, NSRange> = [:]
        self.textStorage!.enumerateAttribute(.attachment, in: self.textStorage!.range,
                                             options: .reverse) { attachment, range, _ in
            if let placeholder = attachment as? TextPlaceholder {
                orderedMap[placeholder] = range
            }
        }
        return orderedMap
    }
    
    private var hasPlaceholder: Bool {
        return !self.placeholders.isEmpty
    }
    
    private weak var selectedPlaceholder: TextPlaceholder?
    
    var hasSelectedPlaceholder: Bool {
        return self.selectedPlaceholder != nil
    }
    
    var sourceString: String {
        return self.unrenderPlaceholders(self.textStorage!, in: self.textStorage!.range).string
    }
    
    var plainString: String {
        let attributedString = NSMutableAttributedString(attributedString: self.textStorage!)
        attributedString.enumerateAttribute(.attachment, in: attributedString.range,
                                            options: .reverse) { attachment, range, _ in
            if let placeholder = attachment as? TextPlaceholder {
                attributedString.replaceCharacters(in: range, with: placeholder.placeholderString)
            }
        }
        return attributedString.string
    }
    
    var textLength: Int {
        return self.textStorage!.length
    }
    
    func initialize(withLineNumbers initializeRulerView: Bool = true) {
        self.font = .monospacedSystemFont(ofSize: 14.0, weight: .regular)
        self.typingAttributes[.foregroundColor] = NSColor.controlTextColor
        self.isAutomaticTextCompletionEnabled = false
        self.isAutomaticTextReplacementEnabled = false
        self.isAutomaticQuoteSubstitutionEnabled = false
        self.isAutomaticDashSubstitutionEnabled = false
        self.isAutomaticLinkDetectionEnabled = false
        
        if initializeRulerView {
            self.rulerView = MainTextViewRulerView(textView: self)
            if self.font == nil {
                self.font = .systemFont(ofSize: NSFont.systemFontSize)
            }
            // install the ruler view into the enclosing scroll view
            let scrollView = self.enclosingScrollView!
            scrollView.verticalRulerView = self.rulerView
            scrollView.hasVerticalRuler = true
            scrollView.rulersVisible = true
            // register handler for frame change notifications, to redraw the ruler view
            self.postsFrameChangedNotifications = true
            scrollView.contentView.postsBoundsChangedNotifications = true
            notificationCenter.addObserver(self, selector: #selector(redrawRulerView),
                                           name: NSView.boundsDidChangeNotification, object: nil)
            notificationCenter.addObserver(self, selector: #selector(redrawRulerView),
                                           name: NSView.frameDidChangeNotification, object: nil)
            notificationCenter.addObserver(self, selector: #selector(redrawRulerView),
                                           name: NSText.didChangeNotification, object: nil)
        }
        
        // set up custom layout manager
        let layoutManager = MainTextViewLayoutManager()
        self.textContainer!.replaceLayoutManager(layoutManager)
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        self.initialize()
    }
    
    /// Sets the line number view as needing display to redraw its view.
    @objc func redrawRulerView() {
        self.rulerView.needsDisplay = true
    }
    
    func renderPlaceholders() {
        self.renderPlaceholders(self.textStorage!)
    }
    
    @discardableResult
    func renderPlaceholders(_ text: NSMutableAttributedString) -> Int {
        var placeholderCount = 0
        let matches = TextPlaceholder.pattern.matches(in: text.string, range: text.range)
        // iterate through matches in reverse order, replacing all placeholder texts
        for match in matches.reversed() {
            let placeholderString = text.mutableString.substring(with: match.range(at: 1))
            let placeholder = TextPlaceholder(placeholderString)
            // replace text with placeholder attachment
            text.replaceCharacters(in: match.range, with: placeholder.attributedString)
            placeholderCount += 1
        }
        return placeholderCount
    }
    
    private func unrenderPlaceholders(_ text: NSAttributedString, in range: NSRange) -> NSAttributedString {
        let attributedString = NSMutableAttributedString(attributedString: text)
        attributedString.enumerateAttribute(.attachment, in: range, options: .reverse) { attachment, aRange, _ in
            if let placeholder = attachment as? TextPlaceholder {
                let plainText = TextPlaceholder.prefix + placeholder.placeholderString + TextPlaceholder.suffix
                attributedString.replaceCharacters(in: aRange, with: plainText)
            }
        }
        return attributedString
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
        let glyphRange = self.layoutManager!.glyphRange(forCharacterRange: characterRange,
                                                        actualCharacterRange: nil)
        let textContainer = self.textContainer!
        
        // get bounding rect at glyph range
        layoutRect = self.layoutManager!.boundingRect(forGlyphRange: glyphRange, in: textContainer)
        
        // get rect relative to the text view
        let containerOrigin = self.textContainerOrigin
        layoutRect.origin.x += containerOrigin.x
        layoutRect.origin.y += containerOrigin.y
        
        // layoutRect = self.convertToLayer(layoutRect)
        
        return layoutRect
    }
    
    /**
     Scrolls a given range to center of the text view, animated.
     
     This method uses `rectForRange(_:)` to determine the rect of a given character range, and then
     scrolls the range to the center of the text view by invoking
     `scroll(toPoint:animationDuration:completionHandler:)`, with or without an animation.
     
     - Parameters:
        - range: A character range.
        - animated: A flag indicating whether or not the scroll should be animated.
        - completionHandler: A closure to be executed when the animation is complete.
     */
    func scrollRangeToCenter(_ range: NSRange, animated: Bool, completionHandler: (() -> Void)? = nil) {
        guard animated else {
            super.scrollRangeToVisible(range)
            completionHandler?()
            return
        }
        // move down half the height to center
        var rect = self.rectForRange(range)
        rect.origin.y -= (self.enclosingScrollView!.contentView.frame.height - rect.height) / 2 - 10
        
        (self.enclosingScrollView as! AScrollView).scroll(toPoint: rect.origin, animationDuration: 0.25,
                                                          completionHandler: completionHandler)
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
    
    // MARK: - Placeholder Queries
    
    func rangeOfPlaceholder(_ placeholder: TextPlaceholder) -> NSRange? {
        return self.placeholders[placeholder]
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
        return self.textStorage!.attribute(.attachment, at: location, longestEffectiveRange: nil,
                                           in: self.textStorage!.range) as? TextPlaceholder
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
        var placeholders: [TextPlaceholder] = []
        self.textStorage!.enumerateAttribute(.attachment, in: range) { (attachment, placeholderRange, _) in
            if let placeholder = attachment as? TextPlaceholder {
                placeholders.append(placeholder)
            }
        }
        return placeholders
    }
    
    func nearestPlaceholder(from location: Int, lookAhead aheadLength: Int = 0, shouldLoop: Bool = true) -> TextPlaceholder? {
        guard self.hasPlaceholder else {
            return nil
        }
        let startingIndex = max(0, location - aheadLength)
        let toEndRange = NSRange(location: startingIndex, length: self.textLength - startingIndex)
        let nearestPlaceholder = self.firstPlaceholder(in: toEndRange)
        // if already found placeholder OR shouldn't loop, return
        if nearestPlaceholder != nil || !shouldLoop {
            return nearestPlaceholder
        }
        // otherwise, search from the beginning up until the starting index (avoid redundant search)
        let fromStartRange = NSRange(location: 0, length: startingIndex)
        return self.firstPlaceholder(in: fromStartRange)
    }
    
    func nextPlaceholder(to placeholder: TextPlaceholder, shouldLoop: Bool = true) -> TextPlaceholder? {
        guard self.placeholders.count > 1,
              let location = self.locationOfPlaceholder(placeholder) else {
            return nil
        }
        let sortedPlaceholders = self.placeholders.sorted { $0.value.location < $1.value.location }
        if let nextPlaceholder = sortedPlaceholders.first(where: { $0.value.location > location }) {
            return nextPlaceholder.key
        } else if shouldLoop {
            return sortedPlaceholders.first?.key
        }
        return nil
    }
    
    // MARK: - Placeholder Operations
    
    func insertPlaceholder(_ placeholder: TextPlaceholder, at location: Int) {
        let range = NSRange(location: location, length: 0)
        self.insertText(placeholder.attributedString, replacementRange: range)
    }
    
    func appendPlaceholder(_ placeholder: TextPlaceholder) {
        let range = NSRange(location: self.textLength, length: 0)
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
        guard let location = self.customLayoutManager
            .characterIndex(for: pointInTextContainer, in: self.textContainer!)
        else {
            return nil
        }
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
        if self.selectedPlaceholder != placeholder {
            self.deselectPlaceholder()
            self.highlightPlaceholder(placeholder, true)
            self.selectedPlaceholder = placeholder
            
            if let location = self.locationOfPlaceholder(placeholder) {
                let range = NSRange(location: location, length: 1)
                self.setSelectedRange(range)
            }
        }
    }
    
    func deselectPlaceholder() {
        if let selectedPlaceholder = self.selectedPlaceholder {
            highlightPlaceholder(selectedPlaceholder, false)
            self.selectedPlaceholder = nil
        }
    }
    
    /**
     Replaces the placeholder with its text contents.
     
     - Parameter placeholder: The placeholder to replace.
     */
    func makePlaceholderText(_ placeholder: TextPlaceholder) {
        if let range = self.rangeOfPlaceholder(placeholder) {
            let replacementString = placeholder.replacementString ?? placeholder.placeholderString
            self.deselectPlaceholder()
            self.insertText(replacementString, replacementRange: range)
        }
    }
    
    private func handlePlaceholderAction(_ action: TextPlaceholder.UserAction, for placeholder: TextPlaceholder) {
        if let replacementAction = (self.delegate as? MainTextViewDelegate)?
            .textView(self, placeholderUserAction: action, for: placeholder) {
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
    
    // MARK: - User Actions
    
    /// Contextual menu for text view.
    override func menu(for event: NSEvent) -> NSMenu? {
        let menu = NSMenu()
        let pasteItem = NSMenuItem(title: "Paste", action: #selector(self.pasteAsPlainText(_:)), keyEquivalent: "")
        let texScannerItem = NSMenuItem(title: "Scan TeX…",
                                        action: #selector(self.editor.showTeXScannerDropZone),
                                        keyEquivalent: "")
        defer {
            // register TeX scanner only if single selection
            if self.selectedRanges.count == 1 {
                menu.addItem(texScannerItem)
            }
        }
        // if there's selected content
        guard self.selectedRange().length > 0 else {
            menu.addItem(pasteItem)
            return menu
        }
        menu.addItem(withTitle: "Copy", action: #selector(self.copy(_:)), keyEquivalent: "")
        menu.addItem(pasteItem)
        menu.addItem(withTitle: "Cut", action: #selector(self.cut(_:)), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Add Bookmark…", action: #selector(self.editor.addBookmark), keyEquivalent: "")
        
        return menu
    }
    
    /// Invokes `textView(_:didInteract:)` to notify for user interaction.
    override func keyDown(with event: NSEvent) {
        super.keyDown(with: event)
        let range = self.selectedRange()
        if range.length == 1, let placeholder = self.placeholder(at: range) {
            self.selectPlaceholder(placeholder)
        } else {
            self.deselectPlaceholder()
        }
        (self.delegate as? MainTextViewDelegate)?.textView(self, didInteract: range)
    }
    
    /// Invokes `textView(_:didInteract:)` to notify for user interaction.
    override func mouseDown(with event: NSEvent) {
        let point = self.convert(event.locationInWindow, from: nil)
        
        let glyphIndex = self.customLayoutManager.glyphIndex(for: point, in: self.textContainer!)
        let characterIndex = self.customLayoutManager.characterIndexForGlyph(at: glyphIndex)
        (self.delegate as? MainTextViewDelegate)?
            .textView(self, didInteract: NSRange(location: characterIndex, length: 0))
        
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
        let lineRange = self.document.editor.outline.ranges.first { range in
            return range.contains(currentLocation)
        }
        
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
            return self.handlePlaceholderAction(.delete, for: selectedPlaceholder)
        }
        super.deleteForward(sender)
    }
    
    override func moveLeft(_ sender: Any?) {
        // get current selected range (not updated yet)
        let range = self.selectedRange()
        if self.hasSelectedPlaceholder {
            // deselect it and call super (which will move the insertion point to the left side of
            //   the placeholder), there may be a neighboring placeholder to the left: need to check
            //   before selecting the previous one
            self.deselectPlaceholder()
        } else if range.length == 0,
                  let placeholder = self.placeholder(at: range.location - 1) {
            // no current selection and previous position is a placeholder
            return self.selectPlaceholder(placeholder)
        }
        super.moveLeft(sender)
    }
    
    override func moveRight(_ sender: Any?) {
        // get current selected range (not updated yet)
        let range = self.selectedRange()
        if self.hasSelectedPlaceholder {
            // deselect it and call super (which will move the insertion point to the right side of
            //   the placeholder), there may be a neighboring placeholder to the right: need to check
            //   before selecting the next one
            self.deselectPlaceholder()
        } else if range.length == 0,
                  let placeholder = self.placeholder(at: range.location) {
            // no current selection and next position is a placeholder
            return self.selectPlaceholder(placeholder)
        }
        super.moveRight(sender)
    }
    
    override func setSelectedRange(_ charRange: NSRange, affinity: NSSelectionAffinity, stillSelecting stillSelectingFlag: Bool) {
        super.setSelectedRange(charRange, affinity: affinity, stillSelecting: stillSelectingFlag)
        if let placeholder = self.placeholder(at: charRange) {
            self.selectPlaceholder(placeholder)
        } else {
            self.deselectPlaceholder()
        }
    }
    
    override open func writeSelection(to pboard: NSPasteboard, type: NSPasteboard.PasteboardType) -> Bool {
        // get currently selected range
        let range = self.selectedRange()
        // get attributed substring in the selected range
        let substring = self.textStorage!.attributedSubstring(from: range)
        
        // check if the substring contains attachments
        if self.textStorage!.containsAttachments(in: range) {
            // make a mutable copy of the substring
            let attributedString = self.unrenderPlaceholders(substring, in: substring.range)
            pboard.clearContents()
            pboard.writeObjects([attributedString.string.nsString])
            return true
        }
        return super.writeSelection(to: pboard, type: type)
    }
    
    deinit {
        // removes all observers upon release
        notificationCenter.removeObserver(self)
    }
    
}

protocol MainTextViewDelegate: NSTextViewDelegate, NSTextStorageDelegate {
    
    /**
     Implement to specify custom behavior upon user interaction with the target text view.
     
     This protocol method is invoked whenever the user interacts with the text view.
     
     - Parameters:
        - textView: The text view.
        - selectedRange: The range selected by the user.
     */
    func textView(_ textView: MainTextView, didInteract selectedRange: NSRange)
    
    /**
     Returns the replacement action to perform on the given selected placeholder for the user interaction.
     
     - Parameters:
        - textView: The text view that contains the selected placeholder the user interacted with.
        - userAction: The type of interaction the user performed on the selected placeholder.
        - placeholder: The selected placeholder the user interacted with.
     
     - Returns: The replacement action for the selected placeholder.
     */
    func textView(_ textView: MainTextView, placeholderUserAction userAction: TextPlaceholder.UserAction, for placeholder: TextPlaceholder) -> TextPlaceholder.ReplacementAction
    
}

extension MainTextViewDelegate {
    
    func textView(_ textView: MainTextView, placeholderUserAction userAction: TextPlaceholder.UserAction, for placeholder: TextPlaceholder) -> TextPlaceholder.ReplacementAction {
        switch userAction {
        case .delete:
            return .delete
        default:
            return .insert
        }
    }
    
}
