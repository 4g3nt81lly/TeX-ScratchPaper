import Cocoa
import Collections

/**
 An object that represents a document's content.
 
 This object manages a document's content.
 
 - Note: Each document object should have no more than one instance of this object.
 */
class FileContent: NSObject, ObservableObject, NSSecureCoding {
    
    /// An unowned reference to its own document object.
    unowned var document: Document!
    
    @objc dynamic var structure = Structure()
    
    private enum Key: String {
        case contentString
        case bookmarks
    }
    
    /// The textual content of the document.
    var contentString: String {
        didSet {
            structure.update(with: contentString)
        }
    }
    
    var undoManager: UndoManager! {
        return document.undoManager
    }
    
    /// Debug description with memory address and content string.
    override var debugDescription: String {
        return "\(Unmanaged.passUnretained(self).toOpaque()): '\(contentString)'"
    }
    
    // MARK: - Bookmarks
    
    /**
     The document's saved bookmarks.
     
     The setter is only made available for the list view and should not be used to update this collection.
     Instead, it must be done through ``addBookmark(_:onAdd:onDelete:)``, ``deleteBookmark(_:onDelete:onAdd:)``,
     and ``updateBookmark(_:userInitiated:)``.
     */
    var bookmarks: Bookmarks = []
    
    func bookmark(with id: UUID) -> Bookmark? {
        return bookmarks.first { $0.id == id }
    }
    
    private func updateBookmarkRanges(with rangeMap: [UUID : [NSRange]]) {
        for (bookmarkID, ranges) in rangeMap {
            var bookmark = bookmark(with: bookmarkID)!
            if (ranges != bookmark.ranges) {
                bookmark.ranges = ranges
                _ = bookmarks.updateOrAppend(bookmark)!
            }
        }
        publishBookmarkChanges()
    }
    
    func addBookmarks(_ bookmarksToAdd: [Bookmark], at indices: [Int]? = nil,
                      onAdd addHandler: @escaping ([Bookmark]) -> Void,
                      undoAction: @escaping ([Bookmark]) -> Void) {
        if let indices {
            for (bookmark, index) in zip(bookmarksToAdd, indices) {
                bookmarks.insert(bookmark, at: index)
            }
        } else {
            bookmarks.append(contentsOf: bookmarksToAdd)
        }
        addHandler(bookmarksToAdd)
        
        undoManager.registerUndo(withTarget: self) { [unowned self] _ in
            deleteBookmarks(bookmarksToAdd, onDelete: undoAction, undoAction: addHandler)
        }
        setUndoActionName("Adding bookmark")
        publishBookmarkChanges()
    }
    
    func deleteBookmarks(_ bookmarksToDelete: [Bookmark],
                         onDelete deleteHandler: @escaping ([Bookmark]) -> Void,
                         undoAction: @escaping ([Bookmark]) -> Void) {
        var deletedIndices: [Int] = []
        var deletedBookmarks: [Bookmark] = []
        for bookmark in bookmarksToDelete {
            let index = bookmarks.firstIndex(of: bookmark)!
            deletedBookmarks.insert(bookmarks.remove(at: index), at: 0)
            deletedIndices.insert(index, at: 0)
        }
        deleteHandler(deletedBookmarks)
        
        undoManager.registerUndo(withTarget: self) { [unowned self] _ in
            addBookmarks(deletedBookmarks, at: deletedIndices,
                         onAdd: undoAction, undoAction: deleteHandler)
        }
        setUndoActionName("Deleting bookmark(s)")
        publishBookmarkChanges()
    }
    
    func editBookmark(with bookmark: Bookmark, onUpdate updateHandler: ((Bookmark) -> Void)? = nil) {
        let oldBookmark = bookmarks.updateOrAppend(bookmark)!
        updateHandler?(bookmark)
        undoManager.registerUndo(withTarget: self) { [unowned self] _ in
            editBookmark(with: oldBookmark, onUpdate: updateHandler)
        }
        setUndoActionName("Editing bookmark")
        publishBookmarkChanges()
    }
    
    func moveBookmark(at indices: IndexSet, to: Int) {
        var selectedBookmarks: [Bookmark] = []
        var offset = 0
        for index in indices.reversed() {
            selectedBookmarks.append(bookmarks.remove(at: index))
            if (index < to) {
                offset += 1
            }
        }
        for bookmark in selectedBookmarks {
            bookmarks.insert(bookmark, at: to - offset)
        }
        publishBookmarkChanges()
    }
    
    private func setUndoActionName(_ name: String) {
        var actionName = name
        if (undoManager.isUndoing) {
            actionName = undoManager.undoActionName
        } else if (undoManager.isRedoing) {
            actionName = undoManager.redoActionName
        }
        undoManager.setActionName(actionName)
    }
    
    private func publishBookmarkChanges() {
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
    }
    
    // MARK: - File Configuration
    
    /// The document's configuration object.
    @objc dynamic var configuration = appSettings.configuration() {
        didSet {
            guard let undoManager = document.undoManager else { return }
            undoManager.registerUndo(withTarget: self,
                                     selector: #selector(undoChangeConfig),
                                     object: oldValue)
            undoManager.setActionName("Changing configuration")
        }
    }
    
    /**
     A method to undo a change in configuration.
     
     - Parameter oldValue: The old configuration object.
     */
    @objc func undoChangeConfig(_ oldValue: Configuration) {
        configuration = oldValue
    }
    
    // MARK: - Initializations
    
    /**
     Convenient initializer for instantiating a new/empty file.
     
     - Parameter string: The initial content of the document.
     */
    init(contentString: String = "") {
        self.contentString = contentString
        self.structure.update(with: contentString)
    }
    
    /// An empty instance of the object.
    static func newFile() -> FileContent {
        return FileContent()
    }
    
    // MARK: - Encoding/Decoding
    
    static var supportsSecureCoding = true
    
    // file saving: encoding via archiver
    func encode(with coder: NSCoder) {
        coder.encode(contentString as NSString, forKey: Key.contentString.rawValue)
        
        configuration.encode(with: coder)
        
        let newBookmarkRanges = document.editor.fetchBookmarkRanges(for: bookmarks)
        updateBookmarkRanges(with: newBookmarkRanges)
        coder.encode(bookmarks.arrayObject, forKey: Key.bookmarks.rawValue)
    }
    
    // proper implementation of NSSecureCoding reference: https://stackoverflow.com/questions/24376746/nssecurecoding-trouble-with-collections-of-custom-class
    required init?(coder: NSCoder) {
        guard let contentString = coder
            .decodeObject(of: NSString.self, forKey: Key.contentString.rawValue)?.string else {
            let alert = NSAlert()
            alert.messageText = "Format Error"
            alert.informativeText = "Unable to read file content due to corrupted format."
            alert.alertStyle = .critical
            alert.runModal()
            return nil
        }
        
        self.contentString = contentString
        self.structure.update(with: contentString)
        
        let config = configuration
        config.decode(from: coder)
        
        var bookmarks: Bookmarks = []
        if let bookmarksArray = coder
            .decodeObject(of: [NSArray.self, NSDictionary.self,
                               NSUUID.self, NSString.self, NSNumber.self, NSValue.self],
                          forKey: Key.bookmarks.rawValue) as? NSArray {
            if let array = Array(bookmarksArray) as? [NSDictionary] {
                for item in array {
                    if let dictionary = item as? [String : Any] {
                        let bookmark = Bookmark(from: dictionary)
                        bookmarks.append(bookmark)
                    }
                }
            }
        }
        self.bookmarks = bookmarks
        
        super.init()
    }
    
}

typealias Bookmarks = OrderedSet<Bookmark>

extension Bookmarks {
    
    /**
     An array object of an array of bookmarkst.
     
     This property is used for file-saving purposes.
     */
    var arrayObject: NSArray {
        return map { $0.dictionary as NSDictionary } as NSArray
    }
    
}
