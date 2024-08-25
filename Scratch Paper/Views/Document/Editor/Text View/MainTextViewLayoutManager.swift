import Cocoa

class MainTextViewLayoutManager: NSLayoutManager, NSLayoutManagerDelegate {
    
    private var textView: MainTextView {
        return firstTextView as! MainTextView
    }
    
    /**
     Returns the index of the character falling under the given point.
    
     - Parameters:
       - point: The point for which to return the character index, in coordinates of `textContainer`.
       - textContainer: The container in which the returned character index is laid out.
     
     - Returns: The index of the character falling under the given point, which is expressed in the
     given container's coordinate system.
     */
    func characterIndex(for point: NSPoint, in textContainer: NSTextContainer) -> Int? {
        // convert point to the nearest glyph index
        let index = glyphIndex(for: point, in: textContainer, fractionOfDistanceThroughGlyph: nil)
        // if the mouse actually lies over the glyph it is nearest to
        let glyphRect = boundingRect(forGlyphRange: NSMakeRange(index, 1), in: textContainer)
        if (glyphRect.contains(point)) {
            // convert the glyph index to a character index
            return characterIndexForGlyph(at: index)
        }
        return nil
    }
    
    override func fillBackgroundRectArray(_ rectArray: UnsafePointer<NSRect>, count rectCount: Int,
                                          forCharacterRange charRange: NSRange, color: NSColor) {
        // don't fill in selection background when only selection is a placeholder
        guard textView.placeholder(at: charRange) == nil else { return }
//        let glyphRange = glyphRange(forCharacterRange: charRange, actualCharacterRange: nil)
//        var fragmentRects: [CGRect] = []
//        let context = NSGraphicsContext.current!
//        context.saveGraphicsState()
//        color.setFill()
//        enumerateLineFragments(forGlyphRange: glyphRange) { _, _, textContainer, glyphRange, _ in
//            let fragmentCharRange = self.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
//                .intersection(charRange)!
//            var fragmentGlyphRange = self.glyphRange(forCharacterRange: fragmentCharRange, actualCharacterRange: nil)
//            
//            let lastFragmentGlyphLocation = fragmentGlyphRange.upperBound - 1
//            let characterRangeAtLastFragmentGlyph = self.characterRange(forGlyphRange: NSMakeRange(lastFragmentGlyphLocation, 1), actualGlyphRange: nil)
//            print(self.textView.string.nsString.substring(with: characterRangeAtLastFragmentGlyph),
//                  self.propertyForGlyph(at: lastFragmentGlyphLocation).rawValue)
//            let fragmentRect = self.boundingRect(forGlyphRange: fragmentGlyphRange, in: textContainer)
//            fragmentRect.fill()
//            fragmentRects.append(fragmentRect)
//        }
//        context.restoreGraphicsState()
        super.fillBackgroundRectArray(rectArray, count: rectCount, forCharacterRange: charRange, color: color)
    }
    
    // MARK: - Bookmarks
    
    private let bookmarkUnderlineThickness: CGFloat = 2.5
    
    override func drawGlyphs(forGlyphRange glyphsToShow: NSRange, at origin: NSPoint) {
        // iterate through all line fragments for the current glyph range
        enumerateLineFragments(forGlyphRange: glyphsToShow) { _, _, textContainer, glyphRange, _ in
            // the character range for the current line fragment
            let fragmentCharRange = self.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
            
            var bookmarkRanges: [UUID : [NSRange]] = [:]
            
            self.textStorage!.enumerateAttributes(in: fragmentCharRange) { items, range, _ in
                for value in items.values {
                    guard let bookmarkID = value as? UUID else { continue }
                    
                    var ranges = bookmarkRanges[bookmarkID] ?? []
                    if var previousRange = ranges.last,
                       range.location == previousRange.upperBound {
                        previousRange.length += range.length
                        ranges[ranges.endIndex - 1] = previousRange
                    } else {
                        ranges.append(range)
                    }
                    bookmarkRanges[bookmarkID] = ranges
                }
            }
            for ranges in bookmarkRanges.values {
                for range in ranges {
                    let glyphRange = self.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
                    self.drawBookmarkRect(for: glyphRange, in: textContainer)
                }
            }
        }
        super.drawGlyphs(forGlyphRange: glyphsToShow, at: origin)
    }
    
    private func drawBookmarkRect(for glyphRange: NSRange, in textContainer: NSTextContainer) {
        let context = NSGraphicsContext.current!
        context.saveGraphicsState()
        
        let boundingRect = boundingRect(forGlyphRange: glyphRange, in: textContainer)
        
        NSColor.bookmarkBackgroundColor.setFill()
        boundingRect.fill()
        
        let underlineSize = CGSize(width: boundingRect.width, height: bookmarkUnderlineThickness)
        var underlineOrigin = boundingRect.origin
        underlineOrigin.y += boundingRect.height - underlineSize.height
        let underlineRect = CGRect(origin: underlineOrigin, size: underlineSize)
        
        NSColor.bookmarkUnderlineColor.setFill()
        underlineRect.fill()
        
        context.restoreGraphicsState()
    }
    
    func layoutManager(_ layoutManager: NSLayoutManager,
                       shouldSetLineFragmentRect lineFragmentRect: UnsafeMutablePointer<NSRect>,
                       lineFragmentUsedRect: UnsafeMutablePointer<NSRect>,
                       baselineOffset: UnsafeMutablePointer<CGFloat>,
                       in textContainer: NSTextContainer, forGlyphRange glyphRange: NSRange) -> Bool {
        let characterRange = characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
        var hasBookmarkInRange = false
        textStorage!.enumerateAttributes(in: characterRange) { items, _, shouldStop in
            if (!items.compactMapValues({ $0 as? UUID }).isEmpty) {
                hasBookmarkInRange = true
                shouldStop.pointee = true
            }
        }
        if (hasBookmarkInRange) {
            var boundingRect = lineFragmentRect.pointee
            var usedRect = lineFragmentUsedRect.pointee
            
            boundingRect.size.height += bookmarkUnderlineThickness
            usedRect.size.height += bookmarkUnderlineThickness
            
            lineFragmentRect.pointee = boundingRect
            lineFragmentUsedRect.pointee = usedRect
        }
        return true
    }
    
}
