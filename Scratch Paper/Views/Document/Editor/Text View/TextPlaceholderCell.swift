import Cocoa

class TextPlaceholderCell: NSTextAttachmentCell {
    
    var attributedString: NSMutableAttributedString
    
    var placeholder: TextPlaceholder {
        return attachment as! TextPlaceholder
    }
    
    override init(textCell string: String) {
        attributedString = NSMutableAttributedString(string: string)
        super.init(textCell: string)
    }
    
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func cellSize() -> NSSize {
        attributedString.addAttributes([.font : TextPlaceholder.font,
                                        .foregroundColor : TextPlaceholder.textColor])
        var size = attributedString.size()
        size.width += 10
        return size
    }
    
    override func cellBaselineOffset() -> NSPoint {
        return NSPoint(x: 0, y: TextPlaceholder.font.descender)
    }
    
    override func draw(withFrame cellFrame: NSRect, in controlView: NSView?, characterIndex charIndex: Int,
                       layoutManager: NSLayoutManager) {
        var cellFrame = cellFrame
        
        let glyphIndex = layoutManager.glyphIndexForCharacter(at: charIndex)
        let glyphRange = NSMakeRange(glyphIndex, 1)
        
        let textContainer = layoutManager.textContainer(forGlyphAt: glyphIndex, effectiveRange: nil)!
        
        // maintain baseline alignment with surrounding text
        let lineFragmentRect = layoutManager
            .lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: nil, withoutAdditionalLayout: true)
        
        // difference between the line fragment rect height and bounding rect height
        // accounts for characters drawn outside of the line fragment (emojis)
        var lineFragBoundingHeightDelta: CGFloat = 0
        
        let boundingRect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
        lineFragBoundingHeightDelta = boundingRect.height - lineFragmentRect.height
        cellFrame.origin.y += lineFragBoundingHeightDelta
        
        // drawing the placeholder
        let radius = cellFrame.height / 5
        let roundedRectPath = NSBezierPath(roundedRect: cellFrame, xRadius: radius, yRadius: radius)
        (isHighlighted ? TextPlaceholder.highlightColor : TextPlaceholder.backgroundColor).setFill()
        roundedRectPath.fill()
        
        // calculate the frame to draw the text
        let textSize = attributedString.size()
        let textFrame = NSRect(x: cellFrame.origin.x + ((cellFrame.width - textSize.width) / 2),
                               y: cellFrame.origin.y,
                               width: textSize.width,
                               height: lineFragmentRect.height)
        // set baseline for attributed text
        let baselineOffset = layoutManager.typesetter
            .baselineOffset(in: layoutManager, glyphIndex: glyphIndex) + 1.5
        // the lower-left origin point
        let baselineOriginPoint = NSPoint(x: textFrame.origin.x, y: textFrame.maxY - baselineOffset)
        // draw text on baseline, size is ignored since it specifies max bounds for drawing (which is not needed)
        attributedString.draw(with: NSRect(origin: baselineOriginPoint, size: .zero),
                              options: [], context: nil)
    }
    
    override func highlight(_ flag: Bool, withFrame cellFrame: NSRect, in controlView: NSView?) {
        isHighlighted = flag
    }
    
}
