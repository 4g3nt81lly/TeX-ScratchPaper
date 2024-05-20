import Cocoa

class Structure: NSObject, Sequence {
    
    @objc dynamic var outline: [SectionNode] = []
    
    private(set) var flattenedOutline: [SectionNode] = []
    
    var sectionRanges: [NSRange] {
        return flattenedOutline.map { $0.textRange }
    }
    
    subscript(index: Int) -> SectionNode {
        return flattenedOutline[index]
    }
    
    func makeIterator() -> [SectionNode].Iterator {
        return flattenedOutline.makeIterator()
    }
    
    func sections(near range: NSRange) -> [SectionNode] {
        return flattenedOutline.filter { node in
            node.textRange.intersection(range) != nil
        }
    }
    
    func update(with text: String) {
        flattenedOutline.removeAll(keepingCapacity: true)
        
        // get plain text by removing all placeholders
        // this is to ensure the processed text range matches that of in the text storage
        let plainText = Patterns.textPlaceholder
            .stringByReplacingMatches(in: text, range: text.range, withTemplate: " ")
        
        updateOutline(with: plainText)
    }
    
    private func updateOutline(with text: String) {
        let lines = text.components(separatedBy: .newlines)
        
        var sections: [SectionNode] = []
        
        var sectionStart = 0
        var sectionType: SectionNode.ContentType?
        var mapIndex = 0
        
        func beginSection(at currentLine: Int, currentType: SectionNode.ContentType) {
            sectionStart = currentLine
            sectionType = currentType
        }
        
        func endSection(at currentLine: Int) {
            guard let currentType = sectionType else { return }
            let lines = sectionStart..<currentLine
            var textRange = text.rangeForLines(at: lines)
            if (currentLine == lines.endIndex) {
                // current line is the last line, and is non-empty
                textRange.length -= 1
            }
            let mathRanges = mathRanges(in: text.nsString.substring(with: textRange),
                                        from: textRange)
            let node = SectionNode(currentType, lines: lines, in: textRange,
                                   at: mapIndex, with: mathRanges)
            if let previousNode = sections.last,
               case .heading(_, _) = previousNode.type {
                // the previous node at top level was a heading
                previousNode.addNode(node)
            } else {
                // otherwise add to top level
                sections.append(node)
            }
            flattenedOutline.append(node)
            sectionType = nil
            mapIndex += 1
        }
        
        func processLine(_ currentLine: Int, of currentType: SectionNode.ContentType? = nil) {
            if let currentType {
                switch (currentType) {
                case .heading(_, _):
                    // current line is a heading, commit previous section
                    endSection(at: currentLine)
                    // add heading node immediately
                    beginSection(at: currentLine, currentType: currentType)
                    endSection(at: currentLine + 1)
                default:
                    if (sectionType != currentType) {
                        endSection(at: currentLine)
                        beginSection(at: currentLine, currentType: currentType)
                    }
                    if (currentLine == lines.endIndex - 1) {
                        // current line is the last line
                        endSection(at: currentLine + 1)
                    }
                }
            } else {
                // current line is empty
                endSection(at: currentLine)
            }
        }
        
        for (index, var line) in lines.enumerated() {
            line = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if let headingResult = Patterns.markdownHeading.matches(in: line, range: line.range).first {
                // current line is a heading
                let headingLevel = headingResult.range(at: 1).length
                let headingText = line.nsString.substring(with: headingResult.range(at: 2))
                processLine(index, of: .heading(level: headingLevel, text: headingText))
            } else if let orderedListResult = Patterns.markdownOrderedList
                .matches(in: line, range: line.range).first {
                // current line is an ordered list
                let previewText = line.nsString.substring(with: orderedListResult.range(at: 1))
                processLine(index, of: .orderedList(preview: previewText))
            } else if let bulletListResult = Patterns.markdownBulletList
                .matches(in: line, range: line.range).first {
                // current line is a bullet list
                let previewText = line.nsString.substring(with: bulletListResult.range(at: 1))
                processLine(index, of: .bulletList(preview: previewText))
            } else if (line.isEmpty) {
                // current line is empty
                processLine(index)
            } else {
                // current line is text
                processLine(index, of: .text(preview: line))
            }
        }
        
        self.outline = sections
    }
    
    private func mathRanges(in text: String, from baseRange: NSRange,
                            isBalanced: UnsafeMutablePointer<Bool>? = nil) -> [NSRange] {
        var mathRanges: [NSRange] = []
        var leftDelimiterRange: NSRange?
        Patterns.texDelimiter.enumerateMatches(in: text, range: text.range) { result, _, _ in
            guard let delimiterRange = result?.range else { return }
            if let leftRange = leftDelimiterRange {
                // right delimiter
                let mathRange = NSRange(location: baseRange.location + leftRange.upperBound,
                                        length: delimiterRange.location - leftRange.upperBound + 1)
                mathRanges.append(mathRange)
                leftDelimiterRange = nil
            } else {
                // left delimiter
                leftDelimiterRange = delimiterRange
            }
        }
        isBalanced?.pointee = (leftDelimiterRange == nil)
        return mathRanges
    }
    
}
