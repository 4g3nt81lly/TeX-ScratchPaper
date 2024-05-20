import Cocoa

protocol EditorControllable {
    
    var document: Document { get }
    
    var structure: Structure { get }
    
    var editor: EditorVC { get }
    
}

extension EditorControllable {
    
    var document: Document {
        return (self as? NSView ?? (self as! NSViewController).view)
            .window!.windowController!.document as! Document
    }
    
    var structure: Structure {
        return document.content.structure
    }
    
    var editor: EditorVC {
        return document.editor
    }
    
}
