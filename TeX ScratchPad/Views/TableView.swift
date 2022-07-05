//
//  TableView.swift
//  TeX-ScratchPad
//
//  Created by Bingyi Billy Li on 2022/7/5.
//

import Cocoa

class TableView: NSTableView {
    
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
    
    func tableView(_ tableView: TableView, didClickRow row: Int)
    
}
