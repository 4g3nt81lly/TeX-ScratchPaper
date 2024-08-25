import Cocoa

final class Patterns {
    
    // MARK: - Editor
    
    static let textPlaceholder: RegEx = "\(TextPlaceholder.prefix)(.*?)\(TextPlaceholder.suffix)"
    
    // MARK: - Markdown
    
    static let markdownEmphasisDelimiter: RegEx = #"(?<!\\)(?:\*+|_+)"#
    
    static let unicodeWhitespace: RegEx = #"^\s$"#
    static let unicodePunctuation: RegEx = #"^[!"\#\$%&'()*+,\-./:;<=>?@\[\]\\^_`{|}~\p{P}\p{S}]$"#
    
    static let markdownUnderlinedText: RegEx = #"<u>.*?<\/u>"#
    
    static let markdownStrikethroughText: RegEx = #"(?<!~)(~~?)(?![\s~])(?:[^~]*[^\s~])?\1"#
    
    static let markdownHeading: RegEx = #"^ {0,3}(#{1,6})[\t ]+(.+?)$"#
    
    static let markdownBulletList: RegEx = #"^ *[*+-] +(.+)$"#
    
    static let markdownOrderedList: RegEx = #"^ *\d\. +(.+)$"#
    
    // MARK: - TeX
    
    static let texDelimiter: RegEx = #"(?<!\\)\\#(ContentRenderer.texDelimiter)"#
    
    static let backticks: RegEx = #"(?<!\\)`"#
    
    static let texCommands: RegEx = #"\\(?:[a-zA-Z]+|[\\;, ])"#
    
    static let texBrackets: RegEx = #"[{}\[\]]"#
    
    static let texOperators: RegEx = #"[+\-=^_()|&]"#
    
    static let texEnvironments: RegEx = #"(?:[^\\]|^)\\begin\{([a-zA-Z]+\*?)\}[\s\S]*?[^\\]\\end\{(\1)\}"#
    
    private init() {}
    
}
