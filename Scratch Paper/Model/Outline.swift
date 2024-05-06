import Cocoa

class Outline: NSObject, Sequence {
    
    @objc dynamic var entries: [OutlineNode] = []
    
    private var orderedEntries: [OutlineNode] = []
    
    var ranges: [NSRange] = []
    
    subscript(index: Int) -> OutlineNode {
        return self.orderedEntries[index]
    }
    
    func makeIterator() -> [OutlineNode].Iterator {
        return self.orderedEntries.makeIterator()
    }
    
    func update(with text: String) {
        self.orderedEntries.removeAll(keepingCapacity: true)
        self.ranges.removeAll(keepingCapacity: true)
        
        var entries: [OutlineNode] = []
        
        var sectionStart = 0
        var sectionType: OutlineNode.EntryType? = nil
        var mapIndex = 0
        
        func addPreviousSection(currentLine: Int, currentType: OutlineNode.EntryType?) {
            guard let type = sectionType else {
                if case .heading(_, _) = currentType {}
                else {
                    sectionType = currentType
                    sectionStart = currentLine
                }
                return
            }
            if type != currentType {
                // add previous node before updating state
                let node = OutlineNode(type: type, range: sectionStart..<currentLine,
                                       index: mapIndex)
                if let previousNode = entries.last,
                   case .heading(_, _) = previousNode.type {
                    // the previous node was a heading
                    previousNode.addNode(node)
                } else {
                    entries.append(node)
                }
                self.orderedEntries.append(node)
                self.ranges.append(text.rangeForLines(at: node.lineRange))
                // update state
                sectionStart = currentLine
                sectionType = currentType
                mapIndex += 1
            }
        }
        
        for (index, var line) in text.components(separatedBy: .newlines).enumerated() {
            line = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            let headingRegex = try! NSRegularExpression(pattern: "^(#{1,6}) +(.+)$")
            let bulletListRegex = try! NSRegularExpression(pattern: #"^ *[*+-] +(.+)$"#)
            let orderedListRegex = try! NSRegularExpression(pattern: #"^ *\d\. +(.+)$"#)
            
            if let headingResult = headingRegex.matches(in: line, range: line.range).first {
                let headingLevel = headingResult.range(at: 1).length
                let headingText = line.nsString.substring(with: headingResult.range(at: 2))
                // current line is a heading
                let headingNode = OutlineNode(type: .heading(level: headingLevel, text: headingText),
                                              range: index..<index + 1, index: mapIndex)
                // add previous section, if any
                addPreviousSection(currentLine: index, currentType: headingNode.type)
                if let previousNode = entries.last,
                   case .heading(let outerLevel, _) = previousNode.type,
                   outerLevel < headingLevel {
                    // previous node was a heading with level
                    previousNode.addNode(headingNode)
                } else {
                    entries.append(headingNode)
                }
                // add to ordered collection and ranges manually
                self.orderedEntries.append(headingNode)
                self.ranges.append(text.rangeForLines(at: headingNode.lineRange))
                // update map index manually
                mapIndex += 1
            } else if let orderedListResult = orderedListRegex.matches(in: line, range: line.range).first {
                let previewText = line.nsString.substring(with: orderedListResult.range(at: 1))
                // current line is an ordered list
                addPreviousSection(currentLine: index,
                                   currentType: .orderedList(preview: previewText))
            } else if let bulletListResult = bulletListRegex.matches(in: line, range: line.range).first {
                let previewText = line.nsString.substring(with: bulletListResult.range(at: 1))
                // current line is a bullet list
                addPreviousSection(currentLine: index,
                                   currentType: .bulletList(preview: previewText))
            } else if line.isEmpty {
                // current line is empty
                addPreviousSection(currentLine: index, currentType: nil)
            } else {
                // current line is text
                addPreviousSection(currentLine: index,
                                   currentType: .text(preview: line))
            }
        }
        
        self.entries = entries
    }
    
}
