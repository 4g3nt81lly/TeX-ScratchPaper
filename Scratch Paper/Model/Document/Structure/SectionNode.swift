import Cocoa

class SectionNode: NSObject {
    
    enum ContentType: Equatable {
        case heading(level: Int, text: String)
        case orderedList(preview: String)
        case bulletList(preview: String)
        case text(preview: String)
        
        static func == (lhs: ContentType, rhs: ContentType) -> Bool {
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
    
    var type: ContentType
    
    var lineRange: Range<Int>
    
    var textRange: NSRange
    
    var mapIndex: Int
    
    var mathRanges: [NSRange]
    
    @objc dynamic var subnodes: [SectionNode] = []
    
    @objc dynamic var preview: String {
        switch type {
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
        switch type {
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
        return subnodes.count
    }
    
    @objc dynamic var isLeaf: Bool {
        return subnodes.isEmpty
    }
    
    override var description: String {
        return preview
    }
    
    init(_ type: ContentType, lines lineRange: Range<Int>, in textRange: NSRange, at index: Int,
         with mathRanges: [NSRange]) {
        self.type = type
        self.lineRange = lineRange
        self.textRange = textRange
        self.mapIndex = index
        self.mathRanges = mathRanges
        super.init()
    }
    
    func addNode(_ node: SectionNode) {
        if let previousNode = subnodes.last,
           case .heading(let previousLevel, _) = previousNode.type {
            if case .heading(let nodeLevel, _) = node.type,
               previousLevel >= nodeLevel {
                // node to be added is a heading with indent level shallower than previous heading
                subnodes.append(node)
            } else {
                // node to be added is not a heading, or is a heading with indent level deeper than
                //   that of the previous heading
                previousNode.addNode(node)
            }
        } else {
            // no previous node or previous node is not a heading
            subnodes.append(node)
        }
    }
    
}
