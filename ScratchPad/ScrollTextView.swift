//
//  ScrollTextView.swift
//  ScratchPad
//
//  Created by Bingyi Billy Li on 2022/4/7.
//

import Cocoa

// Reference: https://stackoverflow.com/a/58307677/10446972
class ScrollView: NSScrollView {
    
    override func scroll(_ clipView: NSClipView, to point: NSPoint) {
        CATransaction.begin()
        // interrupt currently-running animations
        CATransaction.setDisableActions(true)
        self.contentView.setBoundsOrigin(point)
        CATransaction.commit()
    }

    // scroll point to origin of scroll view's content view
    func scroll(toPoint point: NSPoint, animationDuration: Double, completionHandler: (() -> Void)? = nil) {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = animationDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            self.contentView.animator().setBoundsOrigin(point)
            self.reflectScrolledClipView(self.contentView)
        }, completionHandler: completionHandler)
    }
    
}

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
    
//    override func drawBackground(in rect: NSRect) {
//        super.drawBackground(in: rect)
//        for range in self.highlightRanges {
//            let rect = self.rectOfRange(range)
//            NSColor(red: 0.85, green: 0, blue: 0, alpha: 0.5).setFill()
//            rect.fill()
//        }
//    }
    
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
