//
//  MainSplitView.swift
//  Scratch Paper
//
//  Created by Bingyi Billy Li on 2021/6/13.
//

import Cocoa

/**
 Main split view controller.
 
 It is used for the following:
 1. Pass the reference to the associated document object down the hierarchy (to sidebar and editor).
 */
class MainSplitView: NSSplitViewController {
    
    /**
     References its associated document object.
     
     Implicitly unwrapped optional is used rather than creating a dummy document object to avoid redundant calls.
     It passes down reference to the same document object to its child view controllers (sidebar and editor), giving them direct access.
     
     - Note: This is set when the document creates a window controller for the document via the `makeWindowControllers()` method. The children immediately receives the reference to the document object.
     */
    var document: ScratchPaper! {
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
