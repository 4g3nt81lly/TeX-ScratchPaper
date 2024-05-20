import Cocoa

final class Patterns {
    
    // MARK: - Editor
    
    static let textPlaceholder: RegEx = "\(TextPlaceholder.prefix)(.*?)\(TextPlaceholder.suffix)"
    
    // MARK: - Markdown
    
    static let markdownBoldText: RegEx = #"([*_]){2}.*?\1{2}(?!\1)"#
    
    static let markdownItalicText: RegEx = #"(?:(?<!\*)\*(?![\s*])(?:[^*]*[^\s*])?\*)|(?:(?<!_)_(?![\s_])(?:[^_]*[^\s_])?_)"#
    
    static let markdownUnderlinedText: RegEx = #"<u>.*?<\/u>"#
    
    static let markdownStrikethroughText: RegEx = #"(?<!~)(~~?)(?![\s~])(?:[^~]*[^\s~])?\1"#
    
    static let markdownHeading: RegEx = #"^[\t ]*(#{1,6})[\t ]+(.+?)$"#
    
    static let markdownBulletList: RegEx = #"^ *[*+-] +(.+)$"#
    
    static let markdownOrderedList: RegEx = #"^ *\d\. +(.+)$"#
    
    // MARK: - TeX
    
    static let texDelimiter: RegEx = #"(?:^|[^\\])(\\#(ContentRenderer.texDelimiter))"#
    
    static let texCommands: RegEx = #"\\(?:[a-zA-Z]+|[\\;, ])"#
    
    static let texBrackets: RegEx = #"[{}\[\]]"#
    
    static let texOperators: RegEx = #"[+\-=^_()|&]"#
    
    static let texEnvironments: RegEx = #"(?:[^\\]|^)\\begin\{([a-zA-Z]+\*?)\}[\s\S]*?[^\\]\\end\{(\1)\}"#
    
    private init() {}
    
}
