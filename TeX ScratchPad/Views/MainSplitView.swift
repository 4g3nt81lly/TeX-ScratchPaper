//
//  MainSplitView.swift
//  TeX-ScratchPad
//
//  Created by Bingyi Billy Li on 2021/6/13.
//

import Cocoa

class MainSplitView: NSSplitViewController {
    
    var document = ScratchPad() {
        didSet {
            for child in self.children {
                if let sidebar = child as? Sidebar {
                    sidebar.document = self.document
                }
                if let editor = child as? Editor {
                    editor.document = self.document
                }
            }
        }
    }
    
}
