//
//  TextPlaceholderCell.swift
//  Scratch Paper
//
//  Created by Bingyi Billy Li on 2022/8/1.
//

import Cocoa

class TextPlaceholderCell: NSTextAttachmentCell {
    
    var attributedString: NSMutableAttributedString
    
    var placeholder: TextPlaceholder {
        return self.attachment as! TextPlaceholder
    }
    
    override func cellSize() -> NSSize {
        self.attributedString.addAttributes([.font : TextPlaceholder.font,
                                             .foregroundColor : TextPlaceholder.textColor])
        var size = self.attributedString.size()
        size.width += 10
        return size
    }
    
    override func cellBaselineOffset() -> NSPoint {
        return NSPoint(x: 0, y: TextPlaceholder.font.descender)
    }
    
    override func draw(withFrame cellFrame: NSRect, in controlView: NSView?, characterIndex charIndex: Int, layoutManager: NSLayoutManager) {
        var frame = cellFrame
        let glyphIndex = layoutManager.glyphIndexForCharacter(at: charIndex)
        let glyphRange = NSMakeRange(glyphIndex, 1)
        
        let textContainer = layoutManager.textContainer(forGlyphAt: glyphIndex, effectiveRange: nil)!
        
        // maintain baseline alignment with surrounding text
        let lineFragmentRect = layoutManager.lineFragmentRect(forGlyphAt: glyphIndex,
                                                              effectiveRange: nil,
                                                              withoutAdditionalLayout: true)
        
        // difference between the line fragment rect height and bounding rect height
        // accounts for characters drawn outside of the line fragment (emojis)
        var lineFragBoundingHeightDelta: CGFloat = 0
        
        let boundingRect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
        lineFragBoundingHeightDelta = boundingRect.height - lineFragmentRect.height
        frame.origin.y += lineFragBoundingHeightDelta
        
        // drawing the placeholder
        let radius = frame.height / 5
        let roundedRectPath = NSBezierPath(roundedRect: frame, xRadius: radius, yRadius: radius)
        (self.isHighlighted ? TextPlaceholder.highlightColor : TextPlaceholder.backgroundColor).setFill()
        roundedRectPath.fill()
        
        let textSize = self.attributedString.size()
        // the frame to draw the text
        let textFrame = CGRect(x: frame.origin.x + ((frame.width - textSize.width) / 2),
                               y: frame.origin.y,
                               width: textSize.width,
                               height: lineFragmentRect.height)
        // set baseline for attributed text
        let baselineOffset = layoutManager.typesetter.baselineOffset(in: layoutManager,
                                                                     glyphIndex: glyphIndex) + 1.5
        // the lower-left origin point
        let baselineOriginPoint = NSPoint(x: textFrame.origin.x, y: textFrame.maxY - baselineOffset)
        // draw text on baseline, size is negligible because it specifies max bounds for drawing (which is not needed)
        self.attributedString.draw(with: NSRect(origin: baselineOriginPoint, size: .zero))
    }
    
    override func highlight(_ flag: Bool, withFrame cellFrame: NSRect, in controlView: NSView?) {
        self.isHighlighted = flag
    }
    
    override init(textCell string: String) {
        self.attributedString = NSMutableAttributedString(string: string)
        super.init(textCell: string)
    }
    
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}
