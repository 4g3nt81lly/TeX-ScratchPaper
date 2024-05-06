import Cocoa

protocol EditorControllable {
    
    var document: Document { get }
    
    var editor: EditorVC { get }
    
}

extension EditorControllable {
    
    var document: Document {
        return (self as? NSView ?? (self as! NSViewController).view)
            .window!.windowController!.document as! Document
    }
    
    var editor: EditorVC {
        return document.editor
    }
    
}
