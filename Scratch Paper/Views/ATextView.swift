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
    
    /**
     Reference to the associated document object.
     
     Implicitly unwrapped optional is used rather than creating a dummy document object to avoid redundant calls.
     
     - Note: This is set by its superview `Editor` as it initializes the KaTeX view from `viewDidAppear()`.
     */
    var document: ScratchPaper!
    
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
    
    /// Invokes `textView(_:didInteract:)` to notify for user interaction.
    override func keyDown(with event: NSEvent) {
        super.keyDown(with: event)
        if let delegate = self.delegate as? TextViewDelegate {
            delegate.textView(self, didInteract: self.selectedRange())
        }
    }
    
    /// Invokes `textView(_:didInteract:)` to notify for user interaction.
    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        if let delegate = self.delegate as? TextViewDelegate {
            delegate.textView(self, didInteract: self.selectedRange())
        }
    }
    
}

protocol TextViewDelegate: NSTextViewDelegate, NSTextStorageDelegate {
    
    /**
     Implement to specify custom behavior upon user interaction with the target text view.
     
     This protocol method is invoked whenever the user interacts with the text view.
     
     - Parameters:
        - textView: The text view.
        - selectedRange: The range selected by the user.
     */
    func textView(_ textView: ATextView, didInteract selectedRange: NSRange)
    
}
