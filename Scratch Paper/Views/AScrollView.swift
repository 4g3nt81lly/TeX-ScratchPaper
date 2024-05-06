import Cocoa

/**
 A custom subclass of `NSScrollView`.
 
 1. Specifies a custom animation to scroll its content view to a target point.
 
 Reference: [](https://stackoverflow.com/a/58307677/10446972).
 */
class AScrollView: NSScrollView {
    
    /// Scrolls a clip view to a point, animated.
    override func scroll(_ clipView: NSClipView, to point: NSPoint) {
        CATransaction.begin()
        // interrupt currently-running animations
        CATransaction.setDisableActions(true)
        self.contentView.setBoundsOrigin(point)
        CATransaction.commit()
    }

    /// Scrolls a point to the origin of scroll view's content view, animated.
    func scroll(toPoint point: NSPoint, animationDuration: Double, completionHandler: (() -> Void)? = nil) {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = animationDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            self.contentView.animator().setBoundsOrigin(point)
            self.reflectScrolledClipView(self.contentView)
        }, completionHandler: completionHandler)
    }
    
}
