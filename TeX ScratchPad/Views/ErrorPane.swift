//
//  ErrorPane.swift
//  TeX-ScratchPad
//
//  Created by Bingyi Billy Li on 2022/3/31.
//

import Cocoa

class ErrorPane: NSViewController {
    
    @objc dynamic var entries: [ErrorEntry] = []
    
}

extension ErrorPane: TableViewDelegate {
    
    var document: ScratchPad {
        return self.representedObject as! ScratchPad
    }
    
    var editor: Editor {
        return self.document.editor
    }
    
    func highlightSelectedError(row: Int) {
        let editor = self.editor
        let errorEntry = self.entries[row]
        var correspondingRange = editor.katexView!.rangeMap.keys[errorEntry.lineNumber]
        correspondingRange.length += 1
        editor.indicate(correspondingRange, index: row)
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        let tableView = notification.object as! NSTableView
        if tableView.selectedRow > -1 {
            self.highlightSelectedError(row: tableView.selectedRow)
        }
    }
    
    func tableView(_ tableView: TableView, didClickRow row: Int) {
        self.highlightSelectedError(row: row)
    }
    
    func tableView(_ tableView: NSTableView, rowActionsForRow row: Int, edge: NSTableView.RowActionEdge) -> [NSTableViewRowAction] {
        if edge == .trailing {
            let action = NSTableViewRowAction(style: .regular, title: "Reveal") { action, row in
                self.highlightSelectedError(row: row)
                tableView.rowActionsVisible = false
            }
            action.backgroundColor = .controlAccentColor
            return [action]
        }
        return []
    }
    
}
