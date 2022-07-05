//
//  OutlinePaneVC.swift
//  ScratchPad
//
//  Created by Bingyi Billy Li on 2022/4/5.
//

import Cocoa

@objcMembers
class OutlineEntry: NSObject {
    dynamic var content: String
    var lineRange: Range<Int>
    var selectableRange: NSRange
    
    init(text: String, lineRange: Range<Int>, selectableRange: NSRange) {
        self.content = text
        self.lineRange = lineRange
        self.selectableRange = selectableRange
    }
}

class OutlinePaneVC: NSViewController {
    
    @objc dynamic var entries: [OutlineEntry] = []
    
    var bypassIndicateOnSelectionChange = false
    
    @IBOutlet weak var outlineTableView: TableView!
    
}

extension OutlinePaneVC: TableViewDelegate {
    
    var editorVC: EditorVC {
        return (self.view.window!.contentViewController as! NSSplitViewController).splitViewItems[1].viewController as! EditorVC
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        guard !self.bypassIndicateOnSelectionChange else {
            self.bypassIndicateOnSelectionChange = false
            return
        }
        let row = self.outlineTableView.selectedRow
        if row > -1 {
            let entry = self.entries[row]
            self.editorVC.indicate(entry.selectableRange, index: row)
        }
    }
    
    func tableView(_ tableView: TableView, didClickRow row: Int) {
        let entry = self.entries[row]
        self.editorVC.indicate(entry.selectableRange, index: row)
    }
    
}
