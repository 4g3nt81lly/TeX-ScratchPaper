//
//  OutlinePane.swift
//  Scratch Paper
//
//  Created by Bingyi Billy Li on 2022/4/5.
//

import Cocoa

/**
 View controller for the outline pane.
 
 1. Stores and manages the outline entries.
 2. Highlights matching text ranges when outline entries are selected.
 */
class OutlinePane: NSViewController {
    
    /// Outline entries
    @objc dynamic var entries: [OutlineEntry] = []
    
    /**
     Reference to the associated document object.
     
     A computed property that gets and downcasts document object on-demand from its `representedObject`.
     
     - Note: This is set by its superview `Sidebar` after `MainSplitViewController` set them the reference, which is after the document created a window controller via the `makeWindowControllers()` method. The reference retained by `representedObject` is released when `Editor` deallocates.
     
     - Warning: Do NOT use `representedObject` for other purposes. This property forcibly downcasts its `representedObject` as the document object which will fail if the `representedObject` is set to other data.
     */
    var document: Document {
        return self.representedObject as! Document
    }
    
    /**
     Reference to its coexisting `Editor` object.
     
     A computed property that gets editor object on-demand.
     */
    var editor: Editor {
        return self.document.editor
    }
    
    /**
     A flag that indicates whether or not the table view should avoid highlighting the selected entry's corresponding text range in the text view.
     
     Set this property to `true` to tell the table view not to highlight the seleccted entry's corresponding text range in the text view.
     
     - Note: This property only takes effect for **one time**----it will be reset to `false`.
     */
    var bypassRevealOnSelectionChange = false
    
    @IBOutlet weak var outlineTableView: ATableView!
    
}

extension OutlinePane: TableViewDelegate {
    
    /**
     Custom behavior upon the table view's selection changing.
     
     It does the following:
     1. Resets the `bypassRevealOnSelectionChange` flag to `false`.
     2. If `bypassRevealOnSelectionChange` is false, highlights the selected entry's corresponding text range in the text view by invoking `reveal(_:index:)`, using selected row number as the index parameter.
     */
    func tableViewSelectionDidChange(_ notification: Notification) {
        guard !self.bypassRevealOnSelectionChange else {
            self.bypassRevealOnSelectionChange = false
            return
        }
        let row = self.outlineTableView.selectedRow
        if row > -1 {
            let entry = self.entries[row]
            self.editor.reveal(entry.selectableRange, index: row)
        }
    }
    
    /**
     Inherited from `TableViewDelegate` - Custom behavior upon user clicking a row.
     
     It does the following:
     1. Gets entry by clicked row.
     2. Highlights the entry's corresponding text range in the text view by invoking `reveal(_:index:)`, using clicked row number as the index parameter.
     
     - Note: To differentiate the functionality of this method from the one implemented in `tableViewSelectionDidChange(_:)`, the previous method is only invoked when the selection changes, which does not take into the account the case where the user clicks on the same row.
     */
    func tableView(_ tableView: ATableView, didClickRow row: Int) {
        let entry = self.entries[row]
        self.editor.reveal(entry.selectableRange, index: row)
    }
    
}
