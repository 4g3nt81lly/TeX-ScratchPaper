import Cocoa

@objcMembers
class EditorTheme: NSObject, Reflective {
    
    static var editorFont: NSFont = .monospacedSystemFont(ofSize: 14.0, weight: .regular)
    
    class var templateStyle: ThemeToken {
        ThemeToken(
            attributes: [
                .font : editorFont,
                .foregroundColor : NSColor.textColor,
                .underlineStyle : 0,
                .strikethroughStyle : 0
            ]
        )
    }
    
    class var markdownHeadingStyle: ThemeToken {
        ThemeToken(
            pattern: TokenPattern(regex: Patterns.markdownHeading),
            attributes: [.foregroundColor : NSColor.markdownHeadingTextColor],
            handler: { textStorage, match, attributes in
                textStorage.addAttributes(attributes, range: match.range)
                
                let level = match.groupRange(at: 1).length
                let fontSize = (editorFont.pointSize + 12) - CGFloat(level * 2)
                let font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .bold)
                textStorage.addAttributes([.font : font], range: match.range)
            }
        )
    }
    
    class var markdownEmphasisFont: ThemeToken {
        ThemeToken(
            pattern: TokenPattern(handler: { textStorage, range, userInfo in
                let mathRanges = (userInfo as! SectionNode).mathRanges
                var substring = textStorage.string.nsString.substring(with: range)
                for var mathRange in mathRanges {
                    // convert to local range
                    mathRange.location -= range.location
                    let placeholderString = String(repeating: " ", count: mathRange.length)
                    substring = substring.nsString.replacingCharacters(in: mathRange, with: placeholderString)
                }
                let parser = MDEmphasisParser(string: substring, at: range.location)
                return parser.emphasisRanges().map { (emphasisRange, info) in
                    TokenPattern.Match(ranges: [emphasisRange], groupRanges: [], userInfo: info)
                }
            }),
            scope: .textOnly,
            handler: { textStorage, match, _ in
                let info = match.userInfo as! (emphasize: Bool, strong: Bool)
                
                func newFont(from oldFont: NSFont, with newTraits: NSFontDescriptor.SymbolicTraits) -> NSFont {
                    var fontDescriptor = oldFont.fontDescriptor
                    var fontTraits = fontDescriptor.symbolicTraits
                    fontTraits.formUnion(newTraits)
                    fontDescriptor = fontDescriptor.withSymbolicTraits(fontTraits)
                    return NSFont(descriptor: fontDescriptor, size: oldFont.pointSize)!
                }
                
                if (info.strong) {
                    // add bold attributes to range
                    textStorage.enumerateAttribute(.font, in: match.range) { value, range, _ in
                        guard var font = value as? NSFont else { return }
                        font = newFont(from: font, with: .bold)
                        textStorage.addAttribute(.font, value: font, range: range)
                    }
                }
                if (info.emphasize) {
                    // add italic attributes to range
                    textStorage.enumerateAttribute(.font, in: match.range) { value, range, _ in
                        guard var font = value as? NSFont else { return }
                        font = newFont(from: font, with: .italic)
                        textStorage.addAttribute(.font, value: font, range: range)
                    }
                }
            }
        )
    }
    
    class var markdownUnderlinedFont: ThemeToken {
        ThemeToken(
            pattern: TokenPattern(regex: Patterns.markdownUnderlinedText),
            attributes: [.underlineStyle : NSUnderlineStyle.single.rawValue]
        )
    }
    
    class var markdownStrikethroughFont: ThemeToken {
        ThemeToken(
            pattern: TokenPattern(regex: Patterns.markdownStrikethroughText),
            attributes: [.strikethroughStyle : NSUnderlineStyle.single.rawValue]
        )
    }
    
    class var texFont: ThemeToken {
        ThemeToken(
            attributes: [.font : editorFont],
            scope: .mathOnly
        )
    }
    
    class var texCommandTextStyle: ThemeToken {
        ThemeToken(
            pattern: TokenPattern(regex: Patterns.texCommands),
            attributes: [
                .font : NSFont.monospacedSystemFont(ofSize: editorFont.pointSize,
                                                    weight: .medium),
                .foregroundColor : NSColor.texCommandTextColor
            ],
            scope: .mathOnly
        )
    }
    
    class var texOperatorTextColor: ThemeToken {
        ThemeToken(
            pattern: TokenPattern(regex: Patterns.texOperators),
            attributes: [.foregroundColor : NSColor.texOperatorTextColor],
            scope: .mathOnly
        )
    }
    
    class var texBracketsTextColor: ThemeToken {
        ThemeToken(
            pattern: TokenPattern(regex: Patterns.texBrackets),
            attributes: [.foregroundColor : NSColor.texBracketsTextColor],
            scope: .mathOnly
        )
    }
    
    class var texEnvironmentsTextColor: ThemeToken {
        ThemeToken(
            pattern: TokenPattern(regex: Patterns.texEnvironments),
            attributes: [
                .font : NSFont.monospacedSystemFont(ofSize: editorFont.pointSize,
                                                    weight: .medium),
                .foregroundColor : NSColor.texEnvironmentsTextColor
            ],
            scope: .mathOnly,
            handler: { textStorage, result, attributes in
                textStorage.addAttributes(attributes, range: result.groupRange(at: 1))
                textStorage.addAttributes(attributes, range: result.groupRange(at: 2))
            }
        )
    }
    
    class func apply(to textStorage: NSTextStorage, with node: SectionNode) {
        // styles to be applied in order (by properties)
        staticProperties?.forEach { key in
            if let token = value(forKey: key) as? ThemeToken {
                token.apply(to: textStorage, with: node)
            }
        }
    }
    
    private override init() {
        super.init()
    }
    
}

extension NSColor {
    
    static let markdownHeadingTextColor = NSColor(named: "MarkdownHeadingTextColor")!
    
    static let bookmarkBackgroundColor = NSColor(named: "BookmarkBackgroundColor")!
    
    static let bookmarkUnderlineColor = NSColor(named: "BookmarkUnderlineColor")!
    
    static let texCommandTextColor = NSColor(named: "TeXCommandTextColor")!
    
    static let texOperatorTextColor = NSColor(named: "TeXOperatorTextColor")!
    
    static let texBracketsTextColor = NSColor(named: "TeXBracketsTextColor")!
    
    static let texEnvironmentsTextColor = NSColor(named: "TeXEnvironmentsTextColor")!
    
}
