import Cocoa

@objcMembers
class EditorTheme: NSObject, Reflective {
    
    static var editorFont: NSFont = .monospacedSystemFont(ofSize: 14.0, weight: .regular)
    
    class var templateStyle: ThemeToken {
        ThemeToken(
            pattern: nil,
            attributes: [.font : editorFont,
                         .foregroundColor : NSColor.textColor,
                         .underlineStyle : 0, .strikethroughStyle : 0],
            scope: .full,
            handler: nil
        )
    }
    
    class var markdownHeadingStyle: ThemeToken {
        ThemeToken(
            pattern: Patterns.markdownHeading,
            attributes: [.foregroundColor : NSColor.markdownHeadingTextColor],
            scope: .full) { textStorage, result, attributes in
                textStorage.addAttributes(attributes, range: result.range)
                
                let level = result.range(at: 1).length
                let fontSize = (editorFont.pointSize + 12) - CGFloat(level * 2)
                let font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .bold)
                textStorage.addAttributes([.font : font], range: result.range)
            }
    }
    
    class var markdownBoldFont: ThemeToken {
        ThemeToken(
            pattern: Patterns.markdownBoldText,
            attributes: [.font : {
                NSFont.monospacedSystemFont(ofSize: editorFont.pointSize,
                                            weight: .bold)
            }()],
            scope: .full,
            handler: nil
        )
    }
    
    class var markdownItalicFont: ThemeToken {
        ThemeToken(
            pattern: Patterns.markdownItalicText,
            attributes: [.font : {
                NSFont(descriptor: editorFont.fontDescriptor.withSymbolicTraits(.italic),
                       size: editorFont.pointSize)!
            }()],
            scope: .full,
            handler: nil
        )
    }
    
    class var markdownUnderlinedFont: ThemeToken {
        ThemeToken(
            pattern: Patterns.markdownUnderlinedText,
            attributes: [.underlineStyle : NSUnderlineStyle.single.rawValue],
            scope: .full,
            handler: nil
        )
    }
    
    class var markdownStrikethroughFont: ThemeToken {
        ThemeToken(
            pattern: Patterns.markdownStrikethroughText,
            attributes: [.strikethroughStyle : NSUnderlineStyle.single.rawValue],
            scope: .full,
            handler: nil
        )
    }
    
    class var texFont: ThemeToken {
        ThemeToken(
            pattern: nil,
            attributes: [.font : editorFont],
            scope: .mathOnly,
            handler: nil
        )
    }
    
    class var texCommandTextStyle: ThemeToken {
        ThemeToken(
            pattern: Patterns.texCommands,
            attributes: [
                .font : NSFont.monospacedSystemFont(ofSize: editorFont.pointSize,
                                                    weight: .medium),
                .foregroundColor : NSColor.texCommandTextColor
            ],
            scope: .mathOnly,
            handler: nil
        )
    }
    
    class var texOperatorTextColor: ThemeToken {
        ThemeToken(
            pattern: Patterns.texOperators,
            attributes: [.foregroundColor : NSColor.texOperatorTextColor],
            scope: .mathOnly,
            handler: nil
        )
    }
    
    class var texBracketsTextColor: ThemeToken {
        ThemeToken(
            pattern: Patterns.texBrackets,
            attributes: [.foregroundColor : NSColor.texBracketsTextColor],
            scope: .mathOnly,
            handler: nil
        )
    }
    
    class var texEnvironmentsTextColor: ThemeToken {
        ThemeToken(
            pattern: Patterns.texEnvironments,
            attributes: [
                .font : NSFont.monospacedSystemFont(ofSize: editorFont.pointSize,
                                                    weight: .medium),
                .foregroundColor : NSColor.texEnvironmentsTextColor
            ],
            scope: .mathOnly) { textStorage, result, attributes in
                textStorage.addAttributes(attributes, range: result.range(at: 1))
                textStorage.addAttributes(attributes, range: result.range(at: 2))
            }
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
