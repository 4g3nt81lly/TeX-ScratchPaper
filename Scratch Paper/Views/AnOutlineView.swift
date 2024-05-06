import Cocoa

class AnOutlineView: NSOutlineView {
    
    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        let point = self.convert(event.locationInWindow, from: nil)
        if self.row(at: point) < 0 {
            self.deselectAll(nil)
        } else if event.clickCount == 2,
            let customDelegate = self.delegate as? OutlineViewDelegate {
             let point = self.convert(event.locationInWindow, from: nil)
             customDelegate.outlineView(self, didDoubleClick: self.row(at: point))
         }
    }
    
    override func frameOfCell(atColumn column: Int, row: Int) -> NSRect {
        super.frameOfCell(atColumn: column, row: row)
        // reference: https://stackoverflow.com/questions/4251790/nsoutlineview-remove-disclosure-triangle-and-indent
        let frame = super.frameOfCell(atColumn: column, row: row)
        let offset = self.indentationPerLevel * CGFloat(self.level(forRow: row)) + 12
        return NSMakeRect(offset, frame.origin.y, self.bounds.width - (offset + 10), frame.height)
    }
    
}

protocol OutlineViewDelegate: NSOutlineViewDelegate {
    
    func outlineView(_ outlineView: NSOutlineView, didDoubleClick row: Int)
    
}

extension OutlineViewDelegate {
    
    func outlineView(_ outlineView: NSOutlineView, didDoubleClick row: Int) {}
    
}
