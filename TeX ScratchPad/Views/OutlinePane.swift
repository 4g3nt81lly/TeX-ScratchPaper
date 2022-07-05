//
//  OutlinePane.swift
//  TeX-ScratchPad
//
//  Created by Bingyi Billy Li on 2022/4/5.
//

import Cocoa

class OutlinePane: NSViewController {
    
    @objc dynamic var entries: [OutlineEntry] = []
    
    var bypassIndicateOnSelectionChange = false
    
    @IBOutlet weak var outlineTableView: TableView!
    
}

extension OutlinePane: TableViewDelegate {
    
    var document: ScratchPad {
        return self.representedObject as! ScratchPad
    }
    
    var editor: Editor {
        return self.document.editor
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        guard !self.bypassIndicateOnSelectionChange else {
            self.bypassIndicateOnSelectionChange = false
            return
        }
        let row = self.outlineTableView.selectedRow
        if row > -1 {
            let entry = self.entries[row]
            self.editor.indicate(entry.selectableRange, index: row)
        }
    }
    
    func tableView(_ tableView: TableView, didClickRow row: Int) {
        let entry = self.entries[row]
        self.editor.indicate(entry.selectableRange, index: row)
    }
    
}
