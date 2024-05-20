import Cocoa
import UniformTypeIdentifiers

/**
 An object that represents a document.
 
 This object manages a document.
 
 - Note: Each document object should have no more than one window controller.
 */
class Document: NSDocument {
    
    /// The document's file content object.
    @objc dynamic var content = FileContent.newFile()
    
    /// A weak reference to the document's editor view.
    @objc dynamic weak var editor: EditorVC!
    
    /**
     General `init` method for document initialization that calls `super.init()` and passes its own
     reference to its content object.
     
     By passing its own reference to its content object (with the target having an `unowned`
     reference), this `init` method creates a retain cycle between the document object and its
     content object, implying that the two share the same lifecycle.
     */
    override init() {
        super.init()
        content.document = self
    }

    // enables auto-save
    override class var autosavesInPlace: Bool {
        return true
    }
    
    // MARK: - Configurations
    
    // enables asynchronous writing
    override func canAsynchronouslyWrite(to url: URL, ofType typeName: String,
                                         for saveOperation: NSDocument.SaveOperationType) -> Bool {
        return true
    }
    
    // enables asynchronous reading
    override class func canConcurrentlyReadDocuments(ofType typeName: String) -> Bool {
        return true
    }
    
    /**
     Creates a window controller for the document and initializes the editor.
     
     This method is invoked after the document content is loaded (`read(from:ofType:)`).
     */
    override func makeWindowControllers() {
        content.document = self
        
        let wc = mainStoryboard.instantiateController(withIdentifier: "documentWC") as! DocumentWindow
        wc.window!.delegate = wc
        wc.window!.setFrame(NSRect(x: 0, y: 0, width: 1000, height: 600), display: false)
        wc.window!.centerInScreen()
        
        addWindowController(wc)
        
        // dismiss open panel if there is one
        appDelegate.documentController.openPanel?.cancel(nil)
        
        let contentVC = wc.contentViewController as! NSSplitViewController
        editor = (contentVC.splitViewItems[1].viewController as! EditorVC)
        editor.sidebar = (contentVC.splitViewItems[0].viewController as! SidebarVC)
        editor.document = self
        
        editor.initialize()
        editor.sidebar.initialize()
    }
    
    // MARK: - Reading and Writing
    
    var usedEncoding: String.Encoding = .unicode

    /// Creates file-writing data for supported document types.
    override func data(ofType typeName: String) throws -> Data {
        if (typeName == "Scratch Paper Document") {
            let data = try NSKeyedArchiver.archivedData(withRootObject: content, requiringSecureCoding: true)
            return data
        } else {
            if let data = content.contentString.data(using: usedEncoding) {
                return data
            }
            throw NSError(domain: NSOSStatusErrorDomain, code: unimpErr)
        }
    }
    
    /// Reads and loads the content of a supported document type from a given url.
    override func read(from url: URL, ofType typeName: String) throws {
        if (typeName == "Scratch Paper Document") {
            let data = try Data(contentsOf: url)
            if let unarchived = try NSKeyedUnarchiver.unarchivedObject(ofClass: FileContent.self, from: data) {
                content = unarchived
            } else {
                throw NSError(domain: NSOSStatusErrorDomain, code: unimpErr)
            }
        } else {
            // read text/unknown document: public.text, public.plain-text, public.data
            let stringContent = try String(contentsOf: url, usedEncoding: &usedEncoding)
            content.contentString = stringContent
        }
    }
    
    // MARK: Backtracing for troubleshooting.
    
    /*
    
    init(type typeName: String) throws {
        super.init()
        self.fileType = typeName
        Swift.print("[Document \(self)] Finish initialized document object using type '\(typeName)' with content \(self.content).")
    }
    
    init(contentsOf url: URL, ofType typeName: String) throws {
        super.init()
        self.fileURL = url
        self.fileType = typeName
        self.fileModificationDate = .now
        try self.read(from: url, ofType: typeName)
        try super.fileWrapper(ofType: typeName)
        let data = try Data(contentsOf: url)
        try self.read(from: data, ofType: typeName)
        Swift.print("[Document \(self)] Finished initializing document object using type '\(typeName)' with content \(self.content).")
    }
    
    override func addWindowController(_ windowController: NSWindowController) {
        Swift.print("[Document \(self)] Adding created window controller \(windowController) to document.")
        super.addWindowController(windowController)
    }
    
    override func showWindows() {
        Swift.print("[Document \(self)] Document creation process complete, showing windows...")
        super.showWindows()
    }
    
    override func save(_ sender: Any?) {
        Swift.print("[Document \(self)] Beginning to save the document.")
        super.save(sender)
    }
    
    override func save(withDelegate delegate: Any?, didSave didSaveSelector: Selector?, contextInfo: UnsafeMutableRawPointer?) {
        Swift.print("[Document \(self)] Saving with delegate \(String(describing: delegate)), selector \(String(describing: didSaveSelector)), and context info \(String(describing: contextInfo)).")
        super.save(withDelegate: delegate, didSave: didSaveSelector, contextInfo: contextInfo)
    }
    
    override func runModalSavePanel(for saveOperation: NSDocument.SaveOperationType, delegate: Any?, didSave didSaveSelector: Selector?, contextInfo: UnsafeMutableRawPointer?) {
        Swift.print("[Document \(self)] Running save panel for save operation '\(saveOperation)'.")
        super.runModalSavePanel(for: saveOperation, delegate: delegate, didSave: didSaveSelector, contextInfo: contextInfo)
    }
    
    override func writableTypes(for saveOperation: NSDocument.SaveOperationType) -> [String] {
        let types = super.writableTypes(for: saveOperation)
        Swift.print("[Document \(self)] Retrieved writable types. Retrieved types: \(types).")
        return types
    }
    
    override func prepareSavePanel(_ savePanel: NSSavePanel) -> Bool {
        Swift.print("[Document \(self)] Preparing save panel \(savePanel).")
        return super.prepareSavePanel(savePanel)
    }
    
    override func save(to url: URL, ofType typeName: String, for saveOperation: NSDocument.SaveOperationType, delegate: Any?, didSave didSaveSelector: Selector?, contextInfo: UnsafeMutableRawPointer?) {
        Swift.print("[Document \(self)] Saving document to \(url.absoluteString) with type '\(typeName)'.")
        super.save(to: url, ofType: typeName, for: saveOperation, delegate: delegate, didSave: didSaveSelector, contextInfo: contextInfo)
    }
    
    override func save(to url: URL, ofType typeName: String, for saveOperation: NSDocument.SaveOperationType, completionHandler: @escaping (Error?) -> Void) {
        Swift.print("[Document \(self)] Saving document to \(url.absoluteString) with type '\(typeName)' with a completion handler.")
        super.save(to: url, ofType: typeName, for: saveOperation, completionHandler: completionHandler)
    }
    
    override func writeSafely(to url: URL, ofType typeName: String, for saveOperation: NSDocument.SaveOperationType) throws {
        Swift.print("[Document \(self)] Writing safely to \(url.absoluteString).")
        try super.writeSafely(to: url, ofType: typeName, for: saveOperation)
    }
    
    override func write(to url: URL, ofType typeName: String, for saveOperation: NSDocument.SaveOperationType, originalContentsURL absoluteOriginalContentsURL: URL?) throws {
        Swift.print("[Document \(self)] Writing to \(url.absoluteString). Original contents at: \(absoluteOriginalContentsURL?.path ?? "none").")
        try super.write(to: url, ofType: typeName, for: saveOperation, originalContentsURL: absoluteOriginalContentsURL)
    }
     
     */
    
}
