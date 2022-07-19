//
//  ATableView.swift
//  Scratch Paper
//
//  Created by Bingyi Billy Li on 2022/7/5.
//

import Cocoa
import SwiftUI

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
        } else {
            if let customDelegate = self.delegate as? TableViewDelegate {
                customDelegate.tableView(self, didClickRow: rowIndex)
            }
        }
    }
    
}

protocol TableViewDelegate: NSTableViewDelegate {
    
    /**
     Implement to specify custom behavior upon clicking a row.
     
     This protocol method is invoked whenever the user clicks any of the table view's row.
     
     - Parameters:
        - tableView: The table view.
        - row: The
     */
    func tableView(_ tableView: ATableView, didClickRow row: Int)
    
}


