import Cocoa

typealias TextAttributes = [NSAttributedString.Key : Any]

@objcMembers
class ThemeToken: NSObject {
    
    enum Scope {
        case full
        case mathOnly
        case custom((NSRange) -> [NSRange])
    }
    
    let pattern: RegEx?
    
    let attributes: TextAttributes
    
    let scope: Scope
    
    let handler: ((NSTextStorage, NSTextCheckingResult, TextAttributes) -> Void)?
    
    init(pattern: RegEx?, attributes: TextAttributes, scope: Scope,
         handler: ((NSTextStorage, NSTextCheckingResult, TextAttributes) -> Void)?) {
        self.pattern = pattern
        self.attributes = attributes
        self.scope = scope
        self.handler = handler
    }
    
    func apply(to textStorage: NSTextStorage, with outline: SectionNode) {
        var targetRanges: [NSRange] = []
        switch scope {
        case .full:
            targetRanges = [outline.textRange]
        case .mathOnly:
            targetRanges = outline.mathRanges
        case .custom(let subranges):
            targetRanges = subranges(outline.textRange)
        }
        for range in targetRanges {
            if let pattern {
                pattern.enumerateMatches(in: textStorage.string, range: range) { result, _, _ in
                    guard let result else { return }
                    if let handler {
                        handler(textStorage, result, attributes)
                    } else {
                        textStorage.addAttributes(attributes, range: result.range)
                    }
                }
            } else {
                textStorage.addAttributes(attributes, range: range)
            }
        }
        if (!targetRanges.isEmpty) {
            textStorage.edited(.editedAttributes, range: outline.textRange, changeInLength: 0)
        }
    }
    
}
