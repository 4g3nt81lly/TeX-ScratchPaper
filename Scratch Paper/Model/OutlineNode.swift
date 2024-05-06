import Cocoa

class OutlineNode: NSObject {
    
    enum EntryType: Equatable {
        case heading(level: Int, text: String)
        case orderedList(preview: String)
        case bulletList(preview: String)
        case text(preview: String)
        
        static func == (lhs: EntryType, rhs: EntryType) -> Bool {
            switch (lhs, rhs) {
            case (.heading(let lhsLevel, let lhsText),
                  .heading(let rhsLevel, let rhsText)):
                return lhsLevel == rhsLevel && lhsText == rhsText
            case (.orderedList(_), .orderedList(_)),
                 (.bulletList(_), .bulletList(_)),
                 (.text(_), .text(_)):
                return true
            default:
                return false
            }
        }
    }
    
    var type: EntryType
    
    var lineRange: Range<Int>
    
    var mapIndex: Int
    
    @objc dynamic var subnodes: [OutlineNode] = []
    
    @objc dynamic var preview: String {
        switch self.type {
        case .heading(_, let text):
            return text
        case .orderedList(let preview),
             .bulletList(let preview),
             .text(let preview):
            return preview
        }
    }
    
    @objc dynamic var icon: NSImage {
        var symbolName: String
        switch self.type {
        case .heading(_, _):
            symbolName = "h.square"
        case .orderedList(_):
            symbolName = "list.number"
        case .bulletList(_):
            symbolName = "list.bullet"
        case .text(_):
            symbolName = "text.quote"
        }
        return NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)!
    }
    
    @objc dynamic var count: Int {
        return self.subnodes.count
    }
    
    @objc dynamic var isLeaf: Bool {
        return self.subnodes.isEmpty
    }
    
    override var description: String {
        return self.preview
    }
    
    init(type: EntryType, range: Range<Int>, index: Int) {
        self.type = type
        self.lineRange = range
        self.mapIndex = index
    }
    
    func addNode(_ node: OutlineNode) {
        if let previousNode = subnodes.last,
           case .heading(let previousLevel, _) = previousNode.type {
            if case .heading(let nodeLevel, _) = node.type,
               previousLevel >= nodeLevel {
                // node to be added is a heading with indent level shallower than previous heading
                self.subnodes.append(node)
            } else {
                // node to be added is not a heading, or is a heading with indent level deeper than
                //   that of the previous heading
                previousNode.addNode(node)
            }
        } else {
            // no previous node or previous node is not a heading
            self.subnodes.append(node)
        }
    }
    
}
