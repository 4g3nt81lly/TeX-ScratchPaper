//
//  Content.swift
//  Scratch Paper
//
//  Created by Bingyi Billy Li on 2021/6/14.
//

import Cocoa

/**
 An object that represents a document's content.
 
 This object manages a document's content.
 
 - Note: Each document object should have no more than one instance of this object.
 */
class Content: NSObject, NSSecureCoding, ObservableObject {
    
    /// Debug description with memory address and content string.
    override var description: String {
        return "\(Unmanaged.passUnretained(self).toOpaque()): '\(self.contentString)'"
    }
    
    /// An unowned reference to its own document object.
    unowned var document: Document!
    
    /// The textual content of the document.
    var contentString: String
    
    /// The document's saved bookmarks.
    @Published var bookmarks: Bookmarks = [] {
        didSet {
            guard let undoManager = self.document.undoManager else { return }
            
            undoManager.registerUndo(withTarget: self,
                                     selector: #selector(undoModifyBookmarks),
                                     object: oldValue as NSArray)
            // first time: depending on the change
            var verb = "Editing"
            if self.bookmarks.count > oldValue.count {
                // added bookmark
                verb = "Adding"
            } else if self.bookmarks.count < oldValue.count {
                // deleted bookmark
                verb = "Deleting"
            }
            verb = "\(verb) bookmark"
            
            // not first time
            if undoManager.isUndoing {
                // when undoing, redo name should be the same as undo name
                verb = undoManager.undoActionName
            } else if undoManager.isRedoing {
                // when redoing, undo name should be the same as redo name
                verb = undoManager.redoActionName
            }
            
            // register for subsequent undo/redo action name
            undoManager.setActionName(verb)
        }
    }
    
    /// The document's currently-selected bookmark.
    @Published var selectedBookmark: BookmarkEntry?
    
    /// The document's configuration object.
    @objc dynamic var configuration = appSettings.configuration() {
        didSet {
            guard let undoManager = self.document.undoManager else { return }
            undoManager.registerUndo(withTarget: self,
                                     selector: #selector(undoChangeConfig),
                                     object: oldValue)
            undoManager.setActionName("Changing configuration")
        }
    }
    
    // MARK: Initializers & Protocol Stubs
    
    /// An empty instance of the object.
    static func newFile() -> Content {
        return Content()
    }
    
    /**
     Convenient initializer for instantiating a new/empty file.
     
     - Parameter string: The initial content of the document.
     */
    init(contentString string: String = "") {
        self.contentString = string
    }
    
    /**
     A method to undo a change in configuration.
     
     - Parameter oldValue: The old configuration object.
     */
    @objc func undoChangeConfig(_ oldValue: Configuration) {
        self.configuration = oldValue
    }
    
    /**
     A method to undo a modification made to bookmarks.
     
     - Parameter oldValue: An array object of old bookmarks.
     */
    @objc func undoModifyBookmarks(_ oldValue: NSArray) {
        let oldBookmarks = oldValue as! Bookmarks
        self.bookmarks = oldBookmarks
    }
    
    static var supportsSecureCoding = true
    
    // file saving: encoding via archiver
    func encode(with coder: NSCoder) {
        coder.encode(self.contentString as NSString, forKey: "contentString")
        
        coder.encode(self.configuration.cursorPosition as NSNumber, forKey: "cursorPosition")
        
        coder.encode(self.configuration.renderMode as NSNumber, forKey: "renderMode")
        coder.encode(self.configuration.displayMode as NSNumber, forKey: "displayMode")
        coder.encode(self.configuration.displayStyle as NSNumber, forKey: "displayStyle")
        coder.encode(self.configuration.lineToLine as NSNumber, forKey: "lineToLine")
        coder.encode(self.configuration.lockToBottom as NSNumber, forKey: "lockToBottom")
        coder.encode(self.configuration.lockToRight as NSNumber, forKey: "lockToRight")
        
        coder.encode(self.configuration.liveRender as NSNumber, forKey: "liveRender")
        
        coder.encode(self.configuration.renderError as NSNumber, forKey: "renderError")
        coder.encode(self.configuration.errorColorString as NSString, forKey: "errorColorString")
        
        coder.encode(self.configuration.minLineThicknessEnabled as NSNumber, forKey: "minLineThicknessEnabled")
        coder.encode(self.configuration.minLineThickness as NSNumber, forKey: "minLineThickness")
        
        coder.encode(self.configuration.leftJustifyTags as NSNumber, forKey: "leftJustifyTags")
        
        coder.encode(self.configuration.sizeLimitEnabled as NSNumber, forKey: "sizeLimitEnabled")
        coder.encode(self.configuration.sizeLimit as NSNumber, forKey: "sizeLimit")
        
        coder.encode(self.configuration.maxExpansionEnabled as NSNumber, forKey: "maxExpansionEnabled")
        coder.encode(self.configuration.maxExpansion as NSNumber, forKey: "maxExpansion")
        
        coder.encode(self.configuration.trustAllCommands as NSNumber, forKey: "trustAllCommands")
        coder.encode(self.configuration.trustedCommands.arrayObject, forKey: "trustedCommands")
        
        coder.encode(self.bookmarks.arrayObject, forKey: "bookmarks")
    }
    
    // proper implementation of NSSecureCoding reference: https://stackoverflow.com/questions/24376746/nssecurecoding-trouble-with-collections-of-custom-class
    required init?(coder: NSCoder) {
        guard let string = coder.decodeObject(of: NSString.self, forKey: "contentString")?.string else {
            let alert = NSAlert()
            alert.messageText = "Format Error"
            alert.informativeText = "Unable to read file content due to corrupted format."
            alert.alertStyle = .critical
            alert.runModal()
            return nil
        }
        
        self.contentString = string
        
        self.configuration.cursorPosition = coder.decodeObject(of: NSNumber.self, forKey: "cursorPosition")?.intValue ?? 0
        
        self.configuration.renderMode = coder.decodeObject(of: NSNumber.self, forKey: "renderMode")?.intValue ?? 0
        
        self.configuration.displayMode = coder.decodeObject(of: NSNumber.self, forKey: "displayMode")?.boolValue ?? false
        self.configuration.displayStyle = coder.decodeObject(of: NSNumber.self, forKey: "displayStyle")?.boolValue ?? false
        
        self.configuration.lineToLine = coder.decodeObject(of: NSNumber.self, forKey: "lineToLine")?.boolValue ?? false
        
        self.configuration.lockToBottom = coder.decodeObject(of: NSNumber.self, forKey: "lockToBottom")?.boolValue ?? false
        self.configuration.lockToRight = coder.decodeObject(of: NSNumber.self, forKey: "lockToRight")?.boolValue ?? false
        
        self.configuration.liveRender = coder.decodeObject(of: NSNumber.self, forKey: "liveRender")?.boolValue ?? true
        
        self.configuration.renderError = coder.decodeObject(of: NSNumber.self, forKey: "renderError")?.boolValue ?? true
        self.configuration.errorColorString = coder.decodeObject(of: NSString.self, forKey: "errorColorString")?.string ?? "CC0000"
        
        self.configuration.minLineThicknessEnabled = coder.decodeObject(of: NSNumber.self, forKey: "minLineThicknessEnabled")?.boolValue ?? false
        self.configuration.minLineThickness = coder.decodeObject(of: NSNumber.self, forKey: "minLineThickness")?.doubleValue ?? 0.04
        
        self.configuration.leftJustifyTags = coder.decodeObject(of: NSNumber.self, forKey: "leftJustifyTags")?.boolValue ?? false
        
        self.configuration.sizeLimitEnabled = coder.decodeObject(of: NSNumber.self, forKey: "sizeLimitEnabled")?.boolValue ?? false
        self.configuration.sizeLimit = coder.decodeObject(of: NSNumber.self, forKey: "sizeLimit")?.doubleValue ?? 500.0
        
        self.configuration.maxExpansionEnabled = coder.decodeObject(of: NSNumber.self, forKey: "maxExpansionEnabled")?.boolValue ?? false
        self.configuration.maxExpansion = coder.decodeObject(of: NSNumber.self, forKey: "maxExpansion")?.doubleValue ?? 1000.0
        
        self.configuration.trustAllCommands = coder.decodeObject(of: NSNumber.self, forKey: "trustAllCommands")?.boolValue ?? false
        if let commandsArray = coder.decodeObject(of: [NSArray.self, NSNumber.self], forKey: "trustedCommands") as? NSArray {
            if let array = Array(commandsArray) as? [NSNumber], array.count == self.configuration.trustedCommands.count {
                for index in 0..<self.configuration.trustedCommands.count {
                    self.configuration.trustedCommands[index].trusted = array[index].boolValue ?? false
                }
            }
        }
        
        var bookmarks: Bookmarks = []
        if let bookmarksArray = coder.decodeObject(of: [NSArray.self, NSDictionary.self, NSUUID.self, NSString.self, NSValue.self],
                                                   forKey: "bookmarks") as? NSArray {
            if let array = Array(bookmarksArray) as? [NSDictionary] {
                for item in array {
                    if let dictionary = item as? [String : Any],
                       let id = dictionary["id"] as? UUID,
                       let name = dictionary["name"] as? String,
                       let unnamed = dictionary["unnamed"] as? Bool,
                       let description = dictionary["description"] as? String,
                       let icon = dictionary["icon"] as? String,
                       let ranges = dictionary["ranges"] as? [NSRange] {
                        let bookmark = BookmarkEntry(id: id, name: name, unnamed: unnamed, description: description, iconName: icon, ranges: ranges)
                        bookmarks.append(bookmark)
                    }
                }
            }
        }
        self.bookmarks = bookmarks
        
        super.init()
    }
    
}
