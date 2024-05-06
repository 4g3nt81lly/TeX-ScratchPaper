import Cocoa

class MainTextViewLayoutManager: NSLayoutManager {
    
    override func showAttachmentCell(_ cell: NSCell, in rect: NSRect, characterIndex attachmentIndex: Int) {
        super.showAttachmentCell(cell, in: rect, characterIndex: attachmentIndex)
    }
    
    override func fillBackgroundRectArray(_ rectArray: UnsafePointer<NSRect>, count rectCount: Int,
                                          forCharacterRange charRange: NSRange, color: NSColor) {
        // don't fill in selection background when only selection is a placeholder
        guard let textView = self.firstTextView as? MainTextView,
              textView.placeholder(at: charRange) == nil else {
            return
        }
        super.fillBackgroundRectArray(rectArray, count: rectCount, forCharacterRange: charRange, color: color)
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
        let index = self.glyphIndex(for: point, in: textContainer,
                                    fractionOfDistanceThroughGlyph: nil)
        // if the mouse actually lies over the glyph it is nearest to
        let glyphRect = self.boundingRect(forGlyphRange: NSMakeRange(index, 1),
                                          in: textContainer)
        if glyphRect.contains(point) {
            // convert the glyph index to a character index
            return self.characterIndexForGlyph(at: index)
        }
        return nil
    }
    
}
