//
//  ScratchPaper.swift
//  Scratch Paper
//
//  Created by Bingyi Billy Li on 2021/6/14.
//

import Cocoa
import UniformTypeIdentifiers

/**
 An object that represents a document.
 
 This object manages a document.
 
 - Note: Each document object should have no more than one window controller.
 */
class ScratchPaper: NSDocument {
    
    /// The document's file content object.
    @objc dynamic var content = FileObject.newFile
    
    /// A weak reference to the document's content view.
    weak var contentView: MainSplitView!
    
    /// A weak reference to the document's sidebar view.
    weak var sidebar: Sidebar!
    
    /// A weak reference to the document's editor view.
    weak var editor: Editor!

    // enables auto-save
    override class var autosavesInPlace: Bool {
        return true
    }
    
    // MARK: - Configurations
    
    // enables asynchronous writing
    override func canAsynchronouslyWrite(to url: URL, ofType typeName: String, for saveOperation: NSDocument.SaveOperationType) -> Bool {
        return true
    }
    
    // enables asynchronous reading
    override class func canConcurrentlyReadDocuments(ofType typeName: String) -> Bool {
        return typeName == "app.personal.Scratch-Paper"
    }

    // MARK: - User Interface
    
    /**
     Creates a window controller for the document.
     
     This overridden method is invoked after the document content is loaded (`read(from:ofType:)`).
     */
    override func makeWindowControllers() {
        // pass down reference down the hierarchy
        self.content.document = self
        
        let wc = mainStoryboard.instantiateController(withIdentifier: "documentWC") as! DocumentWindow
        wc.window!.setFrame(.init(x: 0, y: 0, width: 1000, height: 600), display: false)
        wc.window!.centerInScreen()
        self.addWindowController(wc)
        
        let contentVC = wc.contentViewController as! MainSplitView
        contentVC.document = self
        self.sidebar = (contentVC.splitViewItems[0].viewController as! Sidebar)
        self.editor = (contentVC.splitViewItems[1].viewController as! Editor)
        self.contentView = contentVC
        
        // dismiss open panel if there is one
        appDelegate.documentController.openPanel?.cancel(nil)
    }
    
    // MARK: - Reading and Writing

    override func data(ofType typeName: String) throws -> Data {
        let data = try NSKeyedArchiver.archivedData(withRootObject: self.content, requiringSecureCoding: true)
        return data
    }

    override func read(from data: Data, ofType typeName: String) throws {
        do {
            if let unarchived = try NSKeyedUnarchiver.unarchivedObject(ofClass: FileObject.self, from: data) {
                self.content = unarchived
            }
        } catch {
            NSLog(String(describing: error))
        }
    }
    
}
