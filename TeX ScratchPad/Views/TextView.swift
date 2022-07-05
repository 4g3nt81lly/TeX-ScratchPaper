//
//  TextView.swift
//  TeX-ScratchPad
//
//  Created by Bingyi Billy Li on 2022/7/4.
//

import Cocoa

class TextView: NSTextView {
    
//    var highlightRanges: [NSRange] = []
    
    // Reference: https://stackoverflow.com/a/8919401/10446972
    // Obj-C Reference: https://stackoverflow.com/questions/11154157/how-to-calculate-correct-coordinates-for-selected-text-in-nstextview/11155388
    public func rectOfRange(_ characterRange: NSRange) -> NSRect {
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
    
    func scrollRangeToCenter(_ range: NSRange, animated: Bool, completionHandler: (() -> Void)? = nil) {
        guard animated else {
            super.scrollRangeToVisible(range)
            return
        }
        // move down half the height to center
        var rect = self.rectOfRange(range)
        rect.origin.y -= (self.enclosingScrollView!.contentView.frame.height - rect.height) / 2 - 10
        
        (self.enclosingScrollView as! ScrollView).scroll(toPoint: rect.origin, animationDuration: 0.25, completionHandler: completionHandler)
    }
    
    override func keyDown(with event: NSEvent) {
        super.keyDown(with: event)
        if let delegate = self.delegate as? TextViewDelegate {
            delegate.textView(self, didClick: self.selectedRange())
        }
    }
    
    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        if let delegate = self.delegate as? TextViewDelegate {
            delegate.textView(self, didClick: self.selectedRange())
        }
    }
    
}

protocol TextViewDelegate: NSTextViewDelegate {
    
    func textView(_ textView: TextView, didClick selectedRange: NSRange)
    
}
