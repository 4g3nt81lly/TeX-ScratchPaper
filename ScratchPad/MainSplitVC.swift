//
//  MainSplitVC.swift
//  ScratchPaper
//
//  Created by Bingyi Billy Li on 2021/6/13.
//

import Cocoa

class MainSplitVC: NSSplitViewController {
    
    override var representedObject: Any? {
        didSet {
            for child in self.children {
                child.representedObject = representedObject
            }
        }
    }
    
}
