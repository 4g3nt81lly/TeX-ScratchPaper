import Cocoa

/**
 A custom subclass of `NSTableView`.
 
 1. Captures row clicking event.
 */
class ATableView: NSTableView {
    
    /// Invokes `tableView(_:didClickRow:)` if the user clicks on a row, otherwise deselects all selected rows.
    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        let point = self.convert(event.locationInWindow, from: nil)
        let rowIndex = self.row(at: point)
        if rowIndex < 0 {
            self.deselectAll(nil)
        } else if let customDelegate = self.delegate as? TableViewDelegate {
            customDelegate.tableView(self, didClick: rowIndex)
        }
    }
    
}

protocol TableViewDelegate: NSTableViewDelegate {
    
    /**
     Implement to specify custom behavior upon clicking a row.
     
     This protocol method is invoked whenever the user clicks any of the table view's row.
     
     - Parameters:
        - tableView: The table view.
        - row: The row number that is clicked.
     */
    func tableView(_ tableView: ATableView, didClick row: Int)
    
}

extension TableViewDelegate {
    
    func tableView(_ tableView: NSTableView, didClick row: Int) {}
    
}


