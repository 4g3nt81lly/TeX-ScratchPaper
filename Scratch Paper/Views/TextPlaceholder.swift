import Cocoa

class TextPlaceholder: NSTextAttachment {
    
    static let prefix = "<#"
    static let suffix = "#>"
    
    static let pattern = try! NSRegularExpression(pattern: "\(prefix)(.*?)\(suffix)")
    
    /// A type of action the user performed on a selected placeholder.
    enum UserAction {
        /// The user pressed the delete key while focused on a placeholder.
        case delete
        /// The user pressed the enter key while focused on a placeholder.
        case enter
        /// The user double clicked on a placeholder.
        case doubleClick
    }
    
    /// A type of replacement action the placeholder should perform.
    enum ReplacementAction {
        /// Replaces the selected placeholder with an empty string.
        case delete
        /// Replaces the selected placeholder with the text contents of the placeholder.
        case insert
        /// Does nothing.
        case none
    }
    
    /// The font that all placeholders use to display text.
    static var font: NSFont = .monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .bold)
    
    /// The color used to draw the placeholder's text.
    static var textColor: NSColor = #colorLiteral(red: 1, green: 1, blue: 1, alpha: 1)
    
    /// The color used to draw the placeholder's background.
    static var backgroundColor: NSColor = #colorLiteral(red: 0.7333333333, green: 0.7333333333, blue: 0.7333333333, alpha: 1)
    
    /// The color used to draw the placeholder's background when selected.
    static var highlightColor: NSColor = .controlAccentColor
    
    var placeholderString: String {
        return self.cell.attributedString.string
    }
    
    var replacementString: String?
    
    var attributedString: NSAttributedString {
        return NSAttributedString(attachment: self)
    }
    
    var cell: TextPlaceholderCell {
        return self.attachmentCell as! TextPlaceholderCell
    }
    
    var isSelected: Bool {
        return self.cell.isHighlighted
    }
    
    init(_ placeholderString: String, replacementString: String? = nil) {
        self.replacementString = replacementString
        super.init(data: nil, ofType: nil)
        self.attachmentCell = TextPlaceholderCell(textCell: placeholderString)
        self.contents = placeholderString.data(using: .unicode)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    func addAttribute(_ name: NSAttributedString.Key, value: Any) {
        self.cell.attributedString.addAttribute(name, value: value)
    }
    
    func removeAttribute(_ name: NSAttributedString.Key) {
        self.cell.attributedString.removeAttribute(name)
    }
    
}
