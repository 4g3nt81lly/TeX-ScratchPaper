//
//  ScrollView.swift
//  TeX-ScratchPad
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
