//
//  ScratchPad.swift
//  TeX-ScratchPad
//
//  Created by Bingyi Billy Li on 2021/6/14.
//

import Cocoa
import UniformTypeIdentifiers

@objcMembers
class ScratchPad: NSDocument {
    
    dynamic var content = FileContent()
    
    var contentView: MainSplitView!
    var sidebar: Sidebar!
    var editor: Editor!

    override init() {
        super.init()
    }

    // enables auto-save
    override class var autosavesInPlace: Bool {
        return true
    }
    
    override var autosavingIsImplicitlyCancellable: Bool {
        return true
    }
    
    // MARK: - Configurations
    
    // enables asynchronous writing
    override func canAsynchronouslyWrite(to url: URL, ofType typeName: String, for saveOperation: NSDocument.SaveOperationType) -> Bool {
        return true
    }
    
    // enables asynchronous reading
    override class func canConcurrentlyReadDocuments(ofType typeName: String) -> Bool {
        return typeName == "prj.alpha.TeX-ScratchPad"
    }

    // MARK: - User Interface
    
    override func makeWindowControllers() {
        // Returns the Storyboard that contains your Document window.
        let wc = mainStoryboard.instantiateController(withIdentifier: "documentWC") as! DocumentWindow
        wc.window!.setFrame(.init(x: 350, y: 220, width: 880, height: 520), display: false)
        self.addWindowController(wc)
        
        let contentVC = wc.contentViewController as! MainSplitView
        self.sidebar = (contentVC.splitViewItems[0].viewController as! Sidebar)
        self.editor = (contentVC.splitViewItems[1].viewController as! Editor)
        contentVC.document = self
        self.contentView = contentVC
    }
    
    // MARK: - Reading and Writing

    override func data(ofType typeName: String) throws -> Data {
        return self.content.data()
    }

    override func read(from data: Data, ofType typeName: String) throws {
        self.content.read(data)
    }
    
}
