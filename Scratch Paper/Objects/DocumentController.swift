//
//  DocumentController.swift
//  Scratch Paper
//
//  Created by Bingyi Billy Li on 2022/7/6.
//

import Cocoa

/**
 A custom subclass of the application's document controller.
 
 This object manages all the documents.
 
 - Note: No more than one unique instance of this object should be present.
 */
class DocumentController: NSDocumentController {
    
    /// An open panel displayed on launch.
    var openPanel: NSOpenPanel?
    
    /**
     Inherited from `NSDocumentController` - Custom behavior upon displaying the open panel.
     
     This overridden method intercepts the creation process of the open panel on launch and keeps a reference to the open panel.
     */
    override func beginOpenPanel(_ openPanel: NSOpenPanel, forTypes inTypes: [String]?, completionHandler: @escaping (Int) -> Void) {
        if self.openPanel == nil {
            self.openPanel = openPanel
        }
        super.beginOpenPanel(self.openPanel!, forTypes: inTypes, completionHandler: completionHandler)
    }
    
    /**
     Inherited from `NSDocumentController` - Custom behavior upon opening a new untitled document.
     
     This overridden method intercepts the creation process of a new untitled document and passes down the document's reference to its file content object.
     */
    override func openUntitledDocumentAndDisplay(_ displayDocument: Bool) throws -> NSDocument {
        let document = try super.openUntitledDocumentAndDisplay(displayDocument) as! ScratchPaper
        document.content.document = document
        return document
    }
    
}
