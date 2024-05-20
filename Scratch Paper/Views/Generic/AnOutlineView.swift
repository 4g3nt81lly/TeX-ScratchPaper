import Cocoa

class AnOutlineView: NSOutlineView {
    
    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        let point = convert(event.locationInWindow, from: nil)
        if (row(at: point) < 0) {
            deselectAll(nil)
        } else if event.clickCount == 2,
            let customDelegate = delegate as? OutlineViewDelegate {
             let point = convert(event.locationInWindow, from: nil)
             customDelegate.outlineView(self, didDoubleClick: row(at: point))
         }
    }
    
    override func frameOfCell(atColumn column: Int, row: Int) -> NSRect {
        super.frameOfCell(atColumn: column, row: row)
        // reference: https://stackoverflow.com/questions/4251790/nsoutlineview-remove-disclosure-triangle-and-indent
        let frame = super.frameOfCell(atColumn: column, row: row)
        let offset = indentationPerLevel * CGFloat(level(forRow: row)) + 12
        return NSMakeRect(offset, frame.origin.y, bounds.width - (offset + 10), frame.height)
    }
    
}

protocol OutlineViewDelegate: NSOutlineViewDelegate {
    
    func outlineView(_ outlineView: NSOutlineView, didDoubleClick row: Int)
    
}

extension OutlineViewDelegate {
    
    func outlineView(_ outlineView: NSOutlineView, didDoubleClick row: Int) {}
    
}
