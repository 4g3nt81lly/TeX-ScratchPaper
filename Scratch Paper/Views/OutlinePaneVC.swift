import Cocoa

/**
 View controller for the outline pane.
 
 1. Stores and manages the outline entries.
 2. Highlights matching text ranges when outline entries are selected.
 */
class OutlinePaneVC: NSViewController, EditorControllable {
    
    @objc dynamic var outline: Outline = Outline()
    
    /**
     A flag that indicates whether or not the table view should avoid highlighting the selected
     entry's corresponding text range in the text view.
     
     Set this property to `true` to tell the table view not to highlight the seleccted entry's
     corresponding text range in the text view.
     
     - Note: This property only takes effect for **one time**----it will be reset to `false`.
     */
    var bypassRevealOnSelectionChange = false
    
    @IBOutlet weak var outlineView: NSOutlineView!
    
}

extension OutlinePaneVC: OutlineViewDelegate {
    
    func outlineViewSelectionDidChange(_ notification: Notification) {
        guard !self.bypassRevealOnSelectionChange else {
            self.bypassRevealOnSelectionChange = false
            return
        }
        let row = self.outlineView.selectedRow
        if row > -1 {
            self.editor.reveal(at: row)
        }
    }
    
    func outlineView(_ outlineView: NSOutlineView, shouldShowOutlineCellForItem item: Any) -> Bool {
        return false
    }
    
    func outlineView(_ outlineView: NSOutlineView, didDoubleClick row: Int) {
        let row = self.outlineView.selectedRow
        if row > -1 {
            self.editor.reveal(at: row)
        }
    }
    
}
