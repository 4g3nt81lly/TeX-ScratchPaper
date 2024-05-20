import Cocoa

/**
 A custom subclass of the application's document controller.
 
 This object manages all the documents.
 
 - Note: No more than one unique instance of this object should be present.
 */
class DocumentController: NSDocumentController {
    
    /// A weak reference to the open panel displayed on launch.
    weak var openPanel: NSOpenPanel?

    /**
     Inherited from `NSDocumentController` - Custom behavior upon displaying the open panel.

     This overridden method intercepts the creation process of the open panel on launch and keeps a
     reference to the open panel.
     */
    override func beginOpenPanel(_ openPanel: NSOpenPanel, forTypes inTypes: [String]?,
                                 completionHandler: @escaping (Int) -> Void) {
        self.openPanel = openPanel
        super.beginOpenPanel(openPanel, forTypes: inTypes, completionHandler: completionHandler)
    }
    
    // MARK: Backtracing for troubleshooting.
    
    /*
    
    override func newDocument(_ sender: Any?) {
        print("[DC \(self)] Beginning to create new document.")
        super.newDocument(sender)
    }
    
    override func openUntitledDocumentAndDisplay(_ displayDocument: Bool) throws -> NSDocument {
        let document = try super.openUntitledDocumentAndDisplay(displayDocument) as! Document
        print("[DC \(self)] Opened untitled document \(document) with content \(document.content), display flag: \(displayDocument).")
        return document
    }
    
    override var defaultType: String? {
        print("[DC \(self)] Requesting for default document type.")
        return "Scratch Paper Document"
    }
    
    override func makeUntitledDocument(ofType typeName: String) throws -> NSDocument {
        let document = try super.makeUntitledDocument(ofType: typeName) as! Document
        print("[DC \(self)] Made untitled document \(document) of type '\(typeName)', named '\(document.displayName ?? "")' with content \(document.content).")
        return document
    }
    
    override func documentClass(forType typeName: String) -> AnyClass? {
        let `class`: AnyClass? = super.documentClass(forType: typeName)
        print("[DC \(self)] Retrieved document class \(String(describing: `class`)) for document type '\(typeName)'.")
        return `class`
    }
    
    override func addDocument(_ document: NSDocument) {
        let content = (document as! Document).content
        print("[DC \(self)] Adding initialized document \(document as! Document) with content: \(content).")
        super.addDocument(document)
    }
    
    
    
    override func openDocument(_ sender: Any?) {
        print("[DC \(self)] Beginning to open a document.")
        super.openDocument(sender)
    }
    
    override func urlsFromRunningOpenPanel() -> [URL]? {
        let urls = super.urlsFromRunningOpenPanel()
        let paths = (urls ?? []).map { $0.path }
        print("[DC \(self)] Retrieved urls (\(paths)) from open panel.")
        return urls
    }
    
    override func runModalOpenPanel(_ openPanel: NSOpenPanel, forTypes types: [String]?) -> Int {
        print("[DC \(self)] Running open panel \(openPanel) for types \(String(describing: types)).")
        return super.runModalOpenPanel(openPanel, forTypes: types)
    }
    
    override func openDocument(withContentsOf url: URL, display displayDocument: Bool, completionHandler: @escaping (NSDocument?, Bool, Error?) -> Void) {
        super.openDocument(withContentsOf: url, display: displayDocument, completionHandler: completionHandler)
        print("[DC \(self)] Opened document with contents from \(url.absoluteString).")
    }
    
    override func typeForContents(of url: URL) throws -> String {
        let type = try super.typeForContents(of: url)
        print("[DC \(self)] Retrieved type for \(url.absoluteString). Retrieved type: \(type).")
        return type
    }
    
    override func makeDocument(withContentsOf url: URL, ofType typeName: String) throws -> NSDocument {
        let document = try super.makeDocument(withContentsOf: url, ofType: typeName) as! Document
        print("[DC \(self)] Made document \(document) named '\(String(describing: document.displayName))' with content \(document.content).")
        return document
    }
    
    */
    
}
