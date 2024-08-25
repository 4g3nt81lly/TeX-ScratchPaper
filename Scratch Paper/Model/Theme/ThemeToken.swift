import Cocoa

typealias TextAttributes = [NSAttributedString.Key : Any]

@objcMembers
class ThemeToken: NSObject {
    
    enum Scope {
        case full
        case mathOnly
        case textOnly
        case custom((NSRange) -> [NSRange])
    }
    
    let pattern: TokenPattern?
    
    let attributes: TextAttributes
    
    let scope: Scope
    
    let handler: ((NSTextStorage, TokenPattern.Match, TextAttributes) -> Void)?
    
    init(pattern: TokenPattern? = nil, attributes: TextAttributes = [:], scope: Scope = .full,
         handler: ((NSTextStorage, TokenPattern.Match, TextAttributes) -> Void)? = nil) {
        self.pattern = pattern
        self.attributes = attributes
        self.scope = scope
        self.handler = handler
    }
    
    func apply(to textStorage: NSTextStorage, with section: SectionNode) {
        // retrieve all target ranges within the section
        var targetRanges: [NSRange] = []
        switch scope {
        case .full, .textOnly:
            targetRanges = [section.range]
        case .mathOnly:
            targetRanges = section.mathRanges
        case .custom(let subranges):
            targetRanges = subranges(section.range)
        }
        for targetRange in targetRanges {
            if let pattern {
                // apply the attributes to the matched ranges in the target range
                for match in pattern.ranges(textStorage, targetRange, section) {
                    if let handler {
                        // custom application of attributes
                        handler(textStorage, match, attributes)
                    } else {
                        textStorage.addAttributes(attributes, range: match.range)
                    }
                }
            } else {
                // apply the attributes to the entire target range
                textStorage.addAttributes(attributes, range: targetRange)
            }
        }
        // is this necessary? :/
        if (!targetRanges.isEmpty) {
            textStorage.edited(.editedAttributes, range: section.range, changeInLength: 0)
        }
    }
    
}
