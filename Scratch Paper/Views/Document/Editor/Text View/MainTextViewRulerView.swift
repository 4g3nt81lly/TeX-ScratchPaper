//  Reference: https://github.com/yichizhang/NSTextView-LineNumberView.git

import Cocoa

class MainTextViewRulerView: NSRulerView {
    
    var font: NSFont = .monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular) {
        didSet {
            needsDisplay = true
        }
    }
    
    init(textView: NSTextView) {
        super.init(scrollView: textView.enclosingScrollView!, orientation: .verticalRuler)
        clientView = textView
        clipsToBounds = true
    }
    
    required init(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override func drawHashMarksAndLabels(in rect: NSRect) {
        guard let textView = clientView as? MainTextView else {
            return
        }
        let string = textView.attributedString().string
        textView.backgroundColor.setFill()
        rect.fill()
        
        let lineCountDigit = "\(string.components(separatedBy: "\n").count)".count
        ruleThickness = CGFloat(lineCountDigit * 8 + 20)
        
        if let layoutManager = textView.layoutManager {
            
            // let anchorPoint = NSPoint(x: self.ruleThickness, y: 0)
            let relativePoint = convert(NSZeroPoint, from: textView)
            let lineNumberAttributes: [NSAttributedString.Key : Any] = [
                .font : font,
                .foregroundColor : NSColor.gray
            ]
            
            let drawLineNumber = { (lineNumberString: String, y: CGFloat) in
                let attString = NSAttributedString(string: lineNumberString,
                                                   attributes: lineNumberAttributes)
                let x = self.ruleThickness - attString.size().width - 10
                attString.draw(at: NSPoint(x: x, y: relativePoint.y + y))
            }
            
            let visibleGlyphRange = layoutManager.glyphRange(forBoundingRect: textView.visibleRect,
                                                             in: textView.textContainer!)
            let firstVisibleGlyphCharacterIndex = layoutManager
                .characterIndexForGlyph(at: visibleGlyphRange.location)
            
            let newLineRegex: RegEx = "\n"
            // the line number for the first visible line
            var lineNumber = newLineRegex
                .numberOfMatches(in: string, range: NSMakeRange(0, firstVisibleGlyphCharacterIndex)) + 1
            
            var glyphIndexForStringLine = visibleGlyphRange.location
            
            // Go through each line in the string.
            while (glyphIndexForStringLine < visibleGlyphRange.upperBound) {
                
                // Range of current line in the string.
                let characterRangeForStringLine = string.nsString.lineRange(
                    for: NSMakeRange(layoutManager.characterIndexForGlyph(at: glyphIndexForStringLine), 0)
                )
                let glyphRangeForStringLine = layoutManager
                    .glyphRange(forCharacterRange: characterRangeForStringLine, actualCharacterRange: nil)
                
                var glyphIndexForGlyphLine = glyphIndexForStringLine
                var glyphLineCount = 0
                
                while (glyphIndexForGlyphLine < glyphRangeForStringLine.upperBound) {
                    
                    // See if the current line in the string spread across
                    // several lines of glyphs
                    var effectiveRange: NSRange = .zero
                    
                    // Range of current "line of glyphs". If a line is wrapped,
                    // then it will have more than one "line of glyphs"
                    let lineRect = layoutManager.lineFragmentRect(forGlyphAt: glyphIndexForGlyphLine,
                                                                  effectiveRange: &effectiveRange,
                                                                  withoutAdditionalLayout: true)
                    if (glyphLineCount > 0) {
                        drawLineNumber("", lineRect.minY)
                    } else {
                        drawLineNumber("\(lineNumber)", lineRect.minY + 1)
                    }
                    
                    // Move to next glyph line
                    glyphLineCount += 1
                    glyphIndexForGlyphLine = effectiveRange.upperBound
                }
                
                glyphIndexForStringLine = glyphRangeForStringLine.upperBound
                lineNumber += 1
            }
            
            // Draw line number for the extra line at the end of the text
            if (layoutManager.extraLineFragmentTextContainer != nil) {
                drawLineNumber("\(lineNumber)", layoutManager.extraLineFragmentRect.minY)
            }
        }
    }
}
