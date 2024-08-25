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
    
    private var customLayoutManager: MainTextViewLayoutManager {
        return layoutManager as! MainTextViewLayoutManager
    }
    
    var textLength: Int {
        return textStorage!.length
    }
    
    // MARK: - Initializations
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        font = EditorTheme.editorFont
        isAutomaticTextCompletionEnabled = false
        isAutomaticTextReplacementEnabled = false
        isAutomaticQuoteSubstitutionEnabled = false
        isAutomaticDashSubstitutionEnabled = false
        isAutomaticLinkDetectionEnabled = false
        isEditable = false
        
        initializeRulerView()
        
        // set up custom layout manager
        let layoutManager = MainTextViewLayoutManager()
        layoutManager.delegate = layoutManager
        textContainer!.replaceLayoutManager(layoutManager)
    }
    
    func initialize() {
        // initialize text content
        string = document.content.contentString
        
        // highlighting syntax
        initializeSyntaxHighlighting()
        highlightSyntaxInVisibleRange()
        
        initializeBookmarking()
    }
    
    // MARK: - Line Number Ruler View
    
    /// The text view's line number ruler view.
    private var rulerView: MainTextViewRulerView!
    
    private func initializeRulerView() {
        rulerView = MainTextViewRulerView(textView: self)
        // install the ruler view into the enclosing scroll view
        let scrollView = enclosingScrollView!
        scrollView.verticalRulerView = rulerView
        scrollView.hasVerticalRuler = true
        scrollView.rulersVisible = true
        // register handler for frame change notifications, to redraw the ruler view
        postsFrameChangedNotifications = true
        scrollView.contentView.postsBoundsChangedNotifications = true
        notificationCenter.addObserver(self, selector: #selector(redrawRulerView),
                                       name: NSView.boundsDidChangeNotification, object: nil)
        notificationCenter.addObserver(self, selector: #selector(redrawRulerView),
                                       name: NSView.frameDidChangeNotification, object: nil)
        notificationCenter.addObserver(self, selector: #selector(redrawRulerView),
                                       name: NSText.didChangeNotification, object: nil)
    }
    
    /// Sets the line number view as needing display to redraw its view.
    @objc func redrawRulerView() {
        rulerView.needsDisplay = true
    }
    
    deinit {
        // removes all observers upon release
        notificationCenter.removeObserver(self)
    }
    
    // MARK: - Utility
    
    /**
     Calculates rect of a given character range.
     
     Reference: [](https://stackoverflow.com/a/8919401/10446972).
     
     Objective-C Reference: [](https://stackoverflow.com/questions/11154157/how-to-calculate-correct-coordinates-for-selected-text-in-nstextview/11155388).
     
     - Parameter characterRange: A character range.
     */
    func rectForRange(_ characterRange: NSRange) -> NSRect {
        var layoutRect: NSRect
        
        // get glyph range for characters
        let glyphRange = customLayoutManager.glyphRange(forCharacterRange: characterRange,
                                                        actualCharacterRange: nil)
        
        // get bounding rect at glyph range
        layoutRect = customLayoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer!)
        
        // get rect relative to the text view
        layoutRect.origin.x += textContainerOrigin.x
        layoutRect.origin.y += textContainerOrigin.y
        
        // layoutRect = convertToLayer(layoutRect)
        
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
        guard (animated) else {
            super.scrollRangeToVisible(range)
            completionHandler?()
            return
        }
        // move down half the height to center
        var rect = rectForRange(range)
        rect.origin.y -= (enclosingScrollView!.contentView.frame.height - rect.height) / 2 - 10
        
        (enclosingScrollView as! AScrollView).scroll(toPoint: rect.origin, animationDuration: 0.25,
                                                     completionHandler: completionHandler)
    }
    
    override func breakUndoCoalescing() {
        if (isCoalescingUndo) {
            super.breakUndoCoalescing()
        }
    }
    
    /**
     Converts a point from the coordinate system of the text view to that of the text container view.
     
     - Parameter point: A point specifying a location in the coordinate system of text view.
     
     - Returns: The point converted to the coordinate system of the text view's text container.
     */
    private func convertToTextContainer(_ point: NSPoint) -> NSPoint {
        return NSPoint(x: point.x - textContainerOrigin.x,
                       y: point.y - textContainerOrigin.y)
    }
    
    // MARK: - Placeholder
    
    private weak var selectedPlaceholder: TextPlaceholder?
    
    func sourceString(withReplacement: Bool = false) -> String {
        return unrenderPlaceholders(textStorage!, in: textStorage!.range, replace: withReplacement).string
    }
    
    // MARK: Placeholder Queries
    
    private var hasSelectedPlaceholder: Bool {
        return selectedPlaceholder != nil
    }
    
    func rangeOfPlaceholder(_ placeholder: TextPlaceholder) -> NSRange? {
        var placeholderRange: NSRange?
        textStorage!.enumerateAttribute(.attachment, in: textStorage!.range) { attachment, range, shouldAbort in
            if let candidatePlaceholder = attachment as? TextPlaceholder,
               candidatePlaceholder == placeholder {
                placeholderRange = range
                shouldAbort.pointee = true
            }
        }
        return placeholderRange
    }
    
    func locationOfPlaceholder(_ placeholder: TextPlaceholder) -> Int? {
        return rangeOfPlaceholder(placeholder)?.location
    }
    
    func placeholder(at range: NSRange) -> TextPlaceholder? {
        guard range.length == 1,
              range.upperBound <= textLength else {
            return nil
        }
        return placeholder(at: range.location)
    }
    
    func placeholder(at location: Int) -> TextPlaceholder? {
        guard (location >= 0 && location < textLength) else {
            return nil
        }
        return textStorage!.attribute(.attachment, at: location, longestEffectiveRange: nil,
                                      in: textStorage!.range) as? TextPlaceholder
    }
    
    func firstPlaceholder(in range: NSRange? = nil) -> TextPlaceholder? {
        var placeholder: TextPlaceholder?
        textStorage!.enumerateAttribute(.attachment, in: range ?? textStorage!.range) { (attachment, _, shouldAbort) in
            if let placeholderObject = attachment as? TextPlaceholder {
                placeholder = placeholderObject
                shouldAbort.pointee = true
            }
        }
        return placeholder
    }
    
    func allPlaceholders(in range: NSRange) -> [TextPlaceholder] {
        var placeholders: [TextPlaceholder] = []
        textStorage!.enumerateAttribute(.attachment, in: range) { (attachment, placeholderRange, _) in
            if let placeholder = attachment as? TextPlaceholder {
                placeholders.append(placeholder)
            }
        }
        return placeholders
    }
    
    func nearestPlaceholder(from location: Int, in contextRange: NSRange, shouldLoop: Bool = true) -> TextPlaceholder? {
        var firstPlaceholder: TextPlaceholder?
        
        var nearestPlaceholder: TextPlaceholder?
        
        textStorage!.enumerateAttribute(.attachment, in: contextRange) { attachment, range, shouldAbort in
            guard let placeholder = attachment as? TextPlaceholder else { return }
            
            if (firstPlaceholder == nil) {
                firstPlaceholder = placeholder
            }
            if (range.location > location) {
                nearestPlaceholder = placeholder
                shouldAbort.pointee = true
            }
        }
        if (shouldLoop) {
            return nearestPlaceholder ?? firstPlaceholder
        }
        return nearestPlaceholder
    }
    
    func nextPlaceholder(to placeholder: TextPlaceholder, in contextRange: NSRange, shouldLoop: Bool = true) -> TextPlaceholder? {
        var firstPlaceholder: TextPlaceholder?
        
        var currentPlaceholder: TextPlaceholder?
        var nextPlaceholder: TextPlaceholder?
        
        textStorage!.enumerateAttribute(.attachment, in: contextRange) { attachment, _, shouldAbort in
            guard let thisPlaceholder = attachment as? TextPlaceholder else { return }
            
            if (firstPlaceholder == nil) {
                firstPlaceholder = thisPlaceholder
            }
            if (currentPlaceholder != nil) {
                nextPlaceholder = thisPlaceholder
                shouldAbort.pointee = true
            } else if (thisPlaceholder == placeholder) {
                currentPlaceholder = thisPlaceholder
            }
        }
        
        if let nextPlaceholder {
            return nextPlaceholder
        } else if shouldLoop {
            return firstPlaceholder
        }
        return nil
    }
    
    // MARK: Placeholder Operations
    
    @discardableResult
    func renderPlaceholders(_ text: NSMutableAttributedString) -> Int {
        var placeholderCount = 0
        let matches = Patterns.textPlaceholder.matches(in: text.string, range: text.range)
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
    
    private func unrenderPlaceholders(_ text: NSAttributedString, in range: NSRange,
                                      replace: Bool = true) -> NSAttributedString {
        let attributedString = NSMutableAttributedString(attributedString: text)
        attributedString.enumerateAttribute(.attachment, in: range, options: .reverse) { attachment, aRange, _ in
            if let placeholder = attachment as? TextPlaceholder {
                let plainText = placeholder.replacementString ?? placeholder.placeholderString
                attributedString.replaceCharacters(in: aRange, with: replace ? plainText : " ")
            }
        }
        return attributedString
    }
    
    func insertPlaceholder(_ placeholder: TextPlaceholder, at location: Int) {
        let range = NSRange(location: location, length: 0)
        insertText(placeholder.attributedString, replacementRange: range)
    }
    
    func deletePlaceholder(_ placeholder: TextPlaceholder) {
        if var range = rangeOfPlaceholder(placeholder) {
            if (selectedPlaceholder == placeholder) {
                deselectPlaceholder()
            }
            insertText("", replacementRange: range)
            range.length = 0
            setSelectedRange(range)
        }
    }
    
    func placeholder(at point: NSPoint) -> TextPlaceholder? {
        let pointInTextContainer = convertToTextContainer(point)
        if let location = customLayoutManager
            .characterIndex(for: pointInTextContainer, in: textContainer!) {
            return placeholder(at: location)
        }
        return nil
    }
    
    /**
     Calls the necessary methods to redraw the specified placeholder as highlighted or unhighlighted.
     
     - Parameters:
        - placeholder: The placeholder that will be redrawn.
        - flag: When `true`, redraws the placeholder as highlighted; otherwise, redraws it normally.
     */
    func highlightPlaceholder(_ placeholder: TextPlaceholder, _ flag: Bool) {
        if let range = rangeOfPlaceholder(placeholder) {
            placeholder.cell.highlight(flag, withFrame: placeholder.bounds, in: self)
            customLayoutManager.invalidateDisplay(forGlyphRange: range)
        }
    }
    
    func selectPlaceholder(_ placeholder: TextPlaceholder) {
        if (selectedPlaceholder != placeholder),
           let location = locationOfPlaceholder(placeholder) {
            deselectPlaceholder()
            highlightPlaceholder(placeholder, true)
            selectedPlaceholder = placeholder
            
            let range = NSRange(location: location, length: 1)
            setSelectedRange(range)
        }
    }
    
    func deselectPlaceholder() {
        if let selectedPlaceholder {
            highlightPlaceholder(selectedPlaceholder, false)
            self.selectedPlaceholder = nil
        }
    }
    
    /**
     Replaces the placeholder with its text contents.
     
     - Parameter placeholder: The placeholder to replace.
     */
    func makePlaceholderText(_ placeholder: TextPlaceholder) {
        if let range = rangeOfPlaceholder(placeholder) {
            let replacementString = placeholder.replacementString ?? placeholder.placeholderString
            deselectPlaceholder()
            insertText(replacementString, replacementRange: range)
        }
    }
    
    private func handlePlaceholderAction(_ action: TextPlaceholder.UserAction, for placeholder: TextPlaceholder) {
        if let replacementAction = (delegate as? MainTextViewDelegate)?
            .textView(self, placeholderUserAction: action, for: placeholder) {
            switch replacementAction {
            case .delete:
                deletePlaceholder(placeholder)
            case .insert:
                makePlaceholderText(placeholder)
            default:
                break
            }
        }
    }
    
    // MARK: - User Actions
    
    /// Contextual menu for text view.
    override func menu(for event: NSEvent) -> NSMenu? {
        let menu = NSMenu()
        let pasteItem = NSMenuItem(title: "Paste", action: #selector(pasteAsPlainText(_:)),
                                   keyEquivalent: "")
        defer {
            let editorMenuItems = editor.contextualMenuItems
            if (!editorMenuItems.isEmpty) {
                menu.addItem(.separator())
                for editorMenuItem in editorMenuItems {
                    menu.addItem(editorMenuItem)
                }
            }
        }
        guard (selectedRange().length > 0) else {
            menu.addItem(pasteItem)
            return menu
        }
        menu.addItem(withTitle: "Copy", action: #selector(copy(_:)), keyEquivalent: "")
        menu.addItem(pasteItem)
        menu.addItem(withTitle: "Cut", action: #selector(cut(_:)), keyEquivalent: "")
        
        return menu
    }
    
    /// Invokes `textView(_:didInteract:)` to notify for user interaction.
    override func keyDown(with event: NSEvent) {
        super.keyDown(with: event)
        let range = selectedRange()
        if range.length == 1, let placeholder = placeholder(at: range) {
            selectPlaceholder(placeholder)
        } else {
            deselectPlaceholder()
        }
        (delegate as? MainTextViewDelegate)?.textView(self, didInteract: range)
    }
    
    /// Invokes `textView(_:didInteract:)` to notify for user interaction.
    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        
        let glyphIndex = customLayoutManager.glyphIndex(for: point, in: textContainer!)
        let characterIndex = customLayoutManager.characterIndexForGlyph(at: glyphIndex)
        (delegate as? MainTextViewDelegate)?
            .textView(self, didInteract: NSRange(location: characterIndex, length: 0))
        
        guard let placeholder = placeholder(at: point) else {
            deselectPlaceholder()
            return super.mouseDown(with: event)
        }
        if (placeholder != selectedPlaceholder) {
            selectPlaceholder(placeholder)
        } else if (event.clickCount > 1) {
            handlePlaceholderAction(.doubleClick, for: placeholder)
        }
    }
    
    override func insertTab(_ sender: Any?) {
        if let selectedPlaceholder,
           let nextPlaceholder = nextPlaceholder(to: selectedPlaceholder, in: textStorage!.range) {
            return selectPlaceholder(nextPlaceholder)
        }
        let currentLocation = selectedRange().location
        let currentTextRange = structure.sectionRanges.first { range in
            range.contains(currentLocation)
        }
        if let nearestPlaceholder = nearestPlaceholder(from: currentLocation, in: currentTextRange ?? textStorage!.range) {
            return selectPlaceholder(nearestPlaceholder)
        }
        super.insertTab(sender)
    }
    
    override func insertNewline(_ sender: Any?) {
        if let selectedPlaceholder {
            return handlePlaceholderAction(.enter, for: selectedPlaceholder)
        }
        super.insertNewline(sender)
    }
    
    override func deleteBackward(_ sender: Any?) {
        if let selectedPlaceholder {
            return handlePlaceholderAction(.delete, for: selectedPlaceholder)
        }
        super.deleteBackward(sender)
    }
    
    override func deleteWordBackward(_ sender: Any?) {
        if let selectedPlaceholder {
            return handlePlaceholderAction(.delete, for: selectedPlaceholder)
        }
        super.deleteWordBackward(sender)
    }
    
    override func deleteForward(_ sender: Any?) {
        if let selectedPlaceholder {
            return handlePlaceholderAction(.delete, for: selectedPlaceholder)
        }
        super.deleteForward(sender)
    }
    
    override func moveLeft(_ sender: Any?) {
        // get current selected range (not updated yet)
        let range = selectedRange()
        if (hasSelectedPlaceholder) {
            // deselect it and call super (which will move the insertion point to the left side of
            //   the placeholder), there may be a neighboring placeholder to the left: need to check
            //   before selecting the previous one
            deselectPlaceholder()
        } else if range.length == 0,
                  let placeholder = placeholder(at: range.location - 1) {
            // no current selection and previous position is a placeholder
            return selectPlaceholder(placeholder)
        }
        super.moveLeft(sender)
    }
    
    override func moveRight(_ sender: Any?) {
        // get current selected range (not updated yet)
        let range = selectedRange()
        if (hasSelectedPlaceholder) {
            // deselect it and call super (which will move the insertion point to the right side of
            //   the placeholder), there may be a neighboring placeholder to the right: need to check
            //   before selecting the next one
            deselectPlaceholder()
        } else if range.length == 0,
                  let placeholder = placeholder(at: range.location) {
            // no current selection and next position is a placeholder
            return selectPlaceholder(placeholder)
        }
        super.moveRight(sender)
    }
    
    override func writeSelection(to pboard: NSPasteboard, type: NSPasteboard.PasteboardType) -> Bool {
        // get currently selected range
        let range = selectedRange()
        // get attributed substring in the selected range
        let substring = textStorage!.attributedSubstring(from: range)
        
        // check if the substring contains attachments
        if (textStorage!.containsAttachments(in: range)) {
            // make a mutable copy of the substring
            let attributedString = unrenderPlaceholders(substring, in: substring.range)
            pboard.clearContents()
            pboard.writeObjects([attributedString.string.nsString])
            return true
        }
        return super.writeSelection(to: pboard, type: type)
    }
    
    override func setSelectedRange(_ charRange: NSRange, affinity: NSSelectionAffinity, stillSelecting stillSelectingFlag: Bool) {
        super.setSelectedRange(charRange, affinity: affinity, stillSelecting: stillSelectingFlag)
        if let placeholder = placeholder(at: charRange) {
            selectPlaceholder(placeholder)
        } else {
            deselectPlaceholder()
        }
    }
    
    // MARK: - Syntax Highlighting
    
    /**
     The most-recently edited range, if any.
     
     This property is manually set by ``textStorage(_:didProcessEditing:range:changeInLength:)`` when the
     text storage did process edited characters.
     
     - Note: This property is used because the `editedRange` property for the text storage is only valid
     while the text is being processed.
     */
    private var lastEditedRange: NSRange?
    
    /**
     A set of sections already syntax highlighted due to bounds changes.
     
     This property is used as a buffer to keep track of the sections that have already been syntax highlighted
     due to bounds changes to reduce redundant highlighting. These sections are subtracted from the visible
     sections when performing syntax highlighting to avoid reapplying attributes.
     */
    private var syntaxHighlightedSections: Set<SectionNode> = []
    
    /**
     Initializes the text view to set up syntax highlighting.
     */
    private func initializeSyntaxHighlighting() {
        // set up text notification for syntax highlighting
        textStorage!.delegate = self
        notificationCenter.addObserver(self, selector: #selector(textObjectDidChange),
                                       name: NSText.didChangeNotification, object: nil)
        notificationCenter.addObserver(self, selector: #selector(highlightSyntaxInVisibleRange),
                                       name: NSView.boundsDidChangeNotification, object: nil)
    }
    
    /**
     Syntax-highlights the given set of sections, applying text attributes according to the ``EditorTheme``.
     
     - Parameter sections: The set of section nodes to be syntax-highlighted.
     */
    private func highlightSyntax(in sections: Set<SectionNode>) {
        textStorage!.beginEditing()
        for section in sections {
            EditorTheme.apply(to: textStorage!, with: section)
        }
        textStorage!.endEditing()
    }
    
    /**
     Syntax-highlights the sections within the given text range.
     
     - Parameters:
        - range: The text range to be syntax-highlighted.
        - visibleOnly: A flag indicating whether only visible sections should be syntax-highlighted.
     */
    private func highlightSyntax(in range: NSRange, visibleOnly: Bool = false) {
        var sections = Set(structure.sections(near: range))
        if (visibleOnly) {
            sections.formIntersection(visibleSections())
        }
        highlightSyntax(in: sections)
    }
    
    /**
     Syntax-highlights the sections within the visible range.
     
     - Parameter ignoreCached: A flag indicating whether the cached syntax-highlighted sections should be
     ignored. If this is set to `true`, then all sections within the visible range are forcibly syntax-highlighted.
     
     - Note: This is marked `@objc` because it is invoked by the bounds change notification.
     */
    @objc func highlightSyntaxInVisibleRange(ignoreCached: Bool = false) {
        var dirtyVisibleSections = Set(visibleSections())
        if (!ignoreCached) {
            dirtyVisibleSections.subtract(syntaxHighlightedSections)
        }
        highlightSyntax(in: dirtyVisibleSections)
        syntaxHighlightedSections.formUnion(dirtyVisibleSections)
    }
    
    /**
     Returns a list of sections that are within the visible range.
     
     - Returns: An array of section nodes, containing all sections that are fully or partially within the
     visible range.
     */
    func visibleSections() -> [SectionNode] {
        let visibleGlyphRange = customLayoutManager
            .glyphRange(forBoundingRect: visibleRect, in: textContainer!)
        let visibleTextRange = customLayoutManager
            .characterRange(forGlyphRange: visibleGlyphRange, actualGlyphRange: nil)
        return structure.sections(near: visibleTextRange)
    }
    
    // MARK: - Bookmarks
    
    /**
     Initializes the text view to set up syntax highlighting.
     */
    private func initializeBookmarking() {
        notificationCenter.addObserver(self, selector: #selector(selectionDidChange),
                                       name: NSTextView.didChangeSelectionNotification, object: nil)
    }
    
    /**
     Fetches text ranges for bookmarks with the given set of identifiers.
     
     - Parameter identifiers: An array of bookmark identifiers to be fetched for. If this is empty, then the
     method fetches text ranges for all bookmarks in the text view.
     
     - Returns: A mapping between the bookmark identifiers and their text ranges. If a bookmark to be fetched
     for did not correspond to any non-empty text ranges (no corresponding text attributes in the text
     storage), then that identifier maps to an empty array.
     */
    func fetchBookmarkRanges(with identifiers: [UUID] = []) -> [UUID : [NSRange]] {
        var bookmarkRanges: [UUID : [NSRange]] = [:]
        for identifier in identifiers {
            bookmarkRanges[identifier] = []
        }
        textStorage!.enumerateAttributes(in: textStorage!.range) { (items, range, _) in
            for value in items.values {
                guard let bookmarkID = value as? UUID,
                      (identifiers.isEmpty || identifiers.contains(bookmarkID)) else { continue }
                var ranges = bookmarkRanges[bookmarkID] ?? []
                // since enumerateAttributes maintains order, the ranges are sorted by default
                if var previousRange = ranges.last,
                   range.location == previousRange.upperBound {
                    // merge the new range with the previous range as they are contiguous
                    previousRange.length += range.length
                    ranges[ranges.endIndex - 1] = previousRange
                } else {
                    ranges.append(range)
                }
                bookmarkRanges[bookmarkID] = ranges
            }
        }
        return bookmarkRanges
    }
    
    func fetchBookmarkRanges(for bookmark: Bookmark) -> [NSRange] {
        return fetchBookmarkRanges(with: [bookmark.id])[bookmark.id]!
    }
    
    /**
     Adds the given array of bookmarks to the text storage as text attributes.
     
     This method uses the text ranges cached by the bookmarks. It is the caller's responsibility to ensure
     that these text ranges are valid and up-to-date.
     */
    func addBookmarks<Bookmarks: Collection<Bookmark>>(_ bookmarks: Bookmarks) {
        guard (!bookmarks.isEmpty) else { return }
        textStorage!.beginEditing()
        for bookmark in bookmarks {
            for range in bookmark.ranges {
                textStorage!.addAttribute(.bookmark(with: bookmark), value: bookmark.id, range: range)
            }
        }
        textStorage!.endEditing()
    }
    
    /**
     Deletes the text attributes associated to the given array of bookmarks from the text storage.
     
     This method does not rely on the text ranges cached by the bookmarks.
     */
    func deleteBookmarks<Bookmarks: Collection<Bookmark>>(_ bookmarks: Bookmarks) {
        guard (!bookmarks.isEmpty) else { return }
        textStorage!.beginEditing()
        for bookmark in bookmarks {
            textStorage!.removeAttribute(.bookmark(with: bookmark))
        }
        textStorage!.endEditing()
    }
    
    /**
     Reveals the given bookmark in the text view, temporarily highlighting the corresponding range.
     
     - Parameter bookmark: A bookmark to be highlighted.
     
     If the given bookmark corresponds to more than one non-contiguous ranges, then the first one is
     highlighted. The method has no effect if the given bookmark corresponds to text ranges with a total
     length of zero.
     */
    func revealBookmark(_ bookmark: Bookmark) {
        let ranges = fetchBookmarkRanges(for: bookmark)
        guard (ranges.totalLength > 0) else { return }
        scrollRangeToCenter(ranges.aggregateRange(), animated: true) {
            self.showFindIndicator(for: ranges.first!)
        }
    }
    
    /**
     Selects all text ranges associated with the given collection of bookmarks.
     
     - Parameter bookmarks: A collection of bookmarks to be selected.
     
     Prior to selection, the text view is scrolled to center the selection ranges, ensuring most ranges, if not all, are visible.
     Finally, the text view registers itself as the first responder, ready for user interaction.
     */
    func selectBookmarks<Bookmarks: Collection<Bookmark>>(_ bookmarks: Bookmarks) {
        let allRanges = bookmarks.map(fetchBookmarkRanges(for:)).joined()
        guard (allRanges.totalLength > 0) else { return }
        scrollRangeToCenter(allRanges.aggregateRange(), animated: true) { [unowned self] in
            selectedRanges = Array(allRanges) as [NSValue]
            window?.makeFirstResponder(self)
        }
    }
    
    /**
     Updates the typing attributes at the currently selected range.
     
     If the currently selected range is within a bookmark's range, then the typing attributes is updated with
     the text attributes associated with the bookmark(s).
     */
    func updateTypingAttributes() {
        // attributes(at:effectiveRange:) raise an exception when the index is the end of string
        let selectedRange = selectedRange()
        guard (selectedRange.location < textLength) else { return }
        
        let attributes = textStorage!.attributes(at: selectedRange.location, effectiveRange: nil)
        
        for (key, value) in attributes {
            if let bookmarkID = value as? UUID {
                typingAttributes[key] = bookmarkID
                return
            }
        }
        typingAttributes = EditorTheme.templateStyle.attributes
    }
    
}

// MARK: - Text View/Storage Delegate

extension MainTextView: NSTextStorageDelegate {
    
    /**
     - Note: This needs to be invoked _after_ `NSTextViewDelegate.textDidChange(_:)`, which updates
             the structure instance of the document's content.
     */
    @objc func textObjectDidChange() {
        if let lastEditedRange {
            highlightSyntax(in: lastEditedRange, visibleOnly: true)
        }
    }
    
    func textStorage(_ textStorage: NSTextStorage,
                     didProcessEditing editedMask: NSTextStorageEditActions,
                     range editedRange: NSRange, changeInLength delta: Int) {
        lastEditedRange = nil
        if (editedMask.contains(.editedCharacters)) {
            lastEditedRange = editedRange
        }
    }
    
    @objc func selectionDidChange() {
        updateTypingAttributes()
    }
    
}

// MARK: - Custom Delegate

protocol MainTextViewDelegate: NSTextViewDelegate {
    
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
    
    func textView(_ textView: MainTextView, didInteract selectedRange: NSRange) {}
    
    func textView(_ textView: MainTextView, placeholderUserAction userAction: TextPlaceholder.UserAction, for placeholder: TextPlaceholder) -> TextPlaceholder.ReplacementAction {
        switch userAction {
        case .delete:
            return .delete
        default:
            return .insert
        }
    }
    
}
