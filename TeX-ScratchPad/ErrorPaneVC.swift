//
//  ErrorPaneVC.swift
//  ScratchPad
//
//  Created by Bingyi Billy Li on 2022/3/31.
//

import Cocoa

class ErrorEntry: NSObject {
    
    var lineNumber: Int
    var groupNumber: Int
    var charPosition: Int?
    @objc dynamic var summary: String
    
    override var description: String {
        return summary
    }
    
    init(line: String, group: String, message: String) {
        self.lineNumber = Int(line.components(separatedBy: "_")[1])!
        self.groupNumber = Int(group.components(separatedBy: "_")[1])!
        self.summary = message
        var parsed = message.components(separatedBy: " at position ")
        parsed.removeFirst()
        if let position = parsed.first?.components(separatedBy: ":").first {
            self.charPosition = Int(position)!
        }
    }
    
}

class ErrorPaneVC: NSViewController {
    
    @objc dynamic var entries: [ErrorEntry] = []
    
}

extension ErrorPaneVC: TableViewDelegate {
    
    var editorVC: EditorVC {
        return (self.view.window!.contentViewController as! NSSplitViewController).splitViewItems[1].viewController as! EditorVC
    }
    
    func highlightSelectedError(row: Int) {
        let editorVC = self.editorVC
        let errorEntry = self.entries[row]
        var correspondingRange = editorVC.katexView!.rangeMap.keys[errorEntry.lineNumber]
        correspondingRange.length += 1
        editorVC.indicate(correspondingRange, index: row)
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
