import AppKit

extension NSRange {
    
    static let zero = NSRange(location: 0, length: 0)
    
}

extension CGFloat {
    
    func within(interval: (lower: CGFloat, upper: CGFloat)) -> CGFloat {
        let (lower, upper) = interval
        guard (lower <= upper) else {
            fatalError("invalid bound: \(lower) > \(upper)")
        }
        return CGFloat.maximum(CGFloat.minimum(self, upper), lower)
    }
    
}

extension CGRect {
    
    mutating func translate(deltaX: CGFloat, deltaY: CGFloat) {
        origin.x += deltaX
        origin.y += deltaY
    }
    
    mutating func resize(deltaWidth: CGFloat, deltaHeight: CGFloat) {
        size.width += deltaWidth
        size.height += deltaHeight
    }
    
}

extension NSApplication {
    
    var isInDarkMode: Bool {
        return effectiveAppearance.name == .darkAqua
    }
    
}

extension NSWindow {
    
    /// Centers the receiver window to the screen.
    func centerInScreen() {
        if let screenSize = screen?.frame.size {
            let origin = NSPoint(x: (screenSize.width - frame.size.width) / 2,
                                 y: (screenSize.height - frame.size.height) / 2)
            setFrameOrigin(origin)
        }
    }
    
}

extension NSCursor {
    
    static private let cursorResourcesPath = "/System/Library/Frameworks/ApplicationServices.framework/Versions/A/Frameworks/HIServices.framework/Versions/A/Resources/cursors/"
    
    static var resizeNWSE: NSCursor = {
        let imagePath = cursorResourcesPath + "resizenorthwestsoutheast/cursor_1only_.png"
        let image = NSImage(byReferencingFile: imagePath)!
        return NSCursor(image: image, hotSpot: NSPoint(x: image.size.width / 2,
                                                       y: image.size.height / 2))
    }()
    
    static var resizeNESW: NSCursor = {
        let imagePath = cursorResourcesPath + "resizenortheastsouthwest/cursor_1only_.png"
        let image = NSImage(byReferencingFile: imagePath)!
        return NSCursor(image: image, hotSpot: NSPoint(x: image.size.width / 2,
                                                       y: image.size.height / 2))
    }()
    
}
