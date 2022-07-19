//
//  ErrorPane.swift
//  Scratch Paper
//
//  Created by Bingyi Billy Li on 2022/3/31.
//

import Cocoa

/**
 View controller for the error pane.
 
 1. Stores and manages the error entries.
 2. Highlights text ranges where the error occurred when error entries are selected.
 */
class ErrorPane: NSViewController {
    
    /// Error entries
    @objc dynamic var entries: [ErrorEntry] = []
    
    /**
     Reference to the associated document object.
     
     A computed property that gets and downcasts document object on-demand from its `representedObject`.
     
     - Note: This is set by its superview `Sidebar` after `MainSplitViewController` set them the reference, which is after the document created a window controller via the `makeWindowControllers()` method.
     
     - Warning: Do NOT use `representedObject` for other purposes. This property forcibly downcasts its `representedObject` as the document object which will fail if the `representedObject` is set to other data.
     */
    var document: ScratchPaper {
        return self.representedObject as! ScratchPaper
    }
    
    /**
     Reference to its coexisting `Editor` object.
     
     A computed property that gets editor object on-demand.
     */
    var editor: Editor {
        return self.document.editor
    }
    
}

extension ErrorPane: TableViewDelegate {
    
    /**
     Highlights text range where an selected error occurred.
     
     This method fetches the matching text range using the corresponding error entry of a selected row.
     
     - Parameter row: The selected row.
     */
    func highlightSelectedError(withRow row: Int) {
        let editor = self.editor
        let errorEntry = self.entries[row]
        var correspondingRange = editor.katexView!.rangeMap.keys[errorEntry.lineNumber]
        // include new line
        correspondingRange.length += 1
        editor.reveal(correspondingRange, index: row)
    }
    
    /**
     Custom behavior upon the table view's selection changing.
     
     Highlights the selected error entry by invoking `hightlightSelectedError(withRow:)` using row number as the parameter.
     */
    func tableViewSelectionDidChange(_ notification: Notification) {
        let tableView = notification.object as! NSTableView
        if tableView.selectedRow > -1 {
            self.highlightSelectedError(withRow: tableView.selectedRow)
        }
    }
    
    /**
     Inherited from `TableViewDelegate` - Custom behavior upon user clicking a row.
     
     Highlights the clicked error entry by invoking `hightlightSelectedError(withRow:)` using clicked row number as the parameter.
     
     - Note: To differentiate the functionality of this method from the one implemented in `tableViewSelectionDidChange(_:)`, the previous method is only invoked when the selection changes, which does not take into the account the case where the user clicks on the same row.
     */
    func tableView(_ tableView: ATableView, didClickRow row: Int) {
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
