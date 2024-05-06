import Cocoa

/**
 View controller for the error pane.
 
 1. Stores and manages the error entries.
 2. Highlights text ranges where the error occurred when error entries are selected.
 */
class ErrorPaneVC: NSViewController, EditorControllable {
    
    /// Error entries
    @objc dynamic var entries: [ErrorEntry] = []
    
}

extension ErrorPaneVC: TableViewDelegate {
    
    /**
     Highlights text range where an selected error occurred.
     
     This method fetches the matching text range using the corresponding error entry of a selected row.
     
     - Parameter row: The selected row.
     */
    func highlightSelectedError(withRow row: Int) {
        let errorEntry = self.entries[row]
        editor.reveal(at: errorEntry.lineNumber)
    }
    
    /**
     Custom behavior upon the table view's selection changing.
     
     Highlights the selected error entry by invoking `hightlightSelectedError(withRow:)` using row
     number as the parameter.
     */
    func tableViewSelectionDidChange(_ notification: Notification) {
        let tableView = notification.object as! NSTableView
        if tableView.selectedRow > -1 {
            self.highlightSelectedError(withRow: tableView.selectedRow)
        }
    }
    
    /**
     Inherited from `TableViewDelegate` - Custom behavior upon user clicking a row.
     
     Highlights the clicked error entry by invoking `hightlightSelectedError(withRow:)` using
     clicked row number as the parameter.
     
     - Note: To differentiate the functionality of this method from the one implemented in
     `tableViewSelectionDidChange(_:)`, the previous method is only invoked when the selection
     changes, which does not take into the account the case where the user clicks on the same row.
     */
    func tableView(_ tableView: ATableView, didClick row: Int) {
        self.highlightSelectedError(withRow: row)
    }
    
    /**
     Inherited from `TableViewDelegate` - Specifies row actions.
     
     Implements: swipe left to "reveal" (highlight) an error.
     */
    func tableView(_ tableView: NSTableView, rowActionsForRow row: Int, edge: NSTableView.RowActionEdge) -> [NSTableViewRowAction] {
        if edge == .trailing {
            let action = NSTableViewRowAction(style: .regular, title: "Reveal") { action, row in
                self.highlightSelectedError(withRow: row)
                tableView.rowActionsVisible = false
            }
            action.backgroundColor = .controlAccentColor
            return [action]
        }
        return []
    }
    
}
