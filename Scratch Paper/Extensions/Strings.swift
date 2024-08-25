import Foundation

extension String {
    
    /**
     Counts the occurrences of a pattern within the receiver string.
     
     - Parameter item: A pattern by which a string is counted.
     
     - Returns: The number of occurrences of the given pattern.
     */
    func count(_ item: String) -> Int {
        return components(separatedBy: item).count - 1
    }
    
    /**
     Separate the receiver string character by character.
     
     - Returns: An array of separated characters in strings.
     */
    func components() -> [String] {
        var components: [String] = []
        for char in self {
            components.append(String(char))
        }
        return components
    }
    
    /**
     Get a character at an index in the receiver string as string.
     
     Swift does not come with native support to subscript a string, this method does just that by
     separating the receiver string character by character by invoking `components()` and returning
     the string element at the given index.
     
     - Precondition: The index must be within the valid range, otherwise this will raise an exception.
     
     - Parameter index: The index of a character.
     
     - Returns: A character at the given index as string.
     */
    subscript(_ index: Int) -> String {
        get {
            let characters = components()
            return characters[index]
        }
    }
    
    /**
     Slices the receiver string with a given range.
     
     Along with string subscript, Swift also does not come with native support to slice a string,
     this method does just that by separating the receiver string character by character by
     invoking `components()` and returning the joined array slice.
     
     - Precondition: The range must be within the valid range, otherwise this will raise an exception.
     
     - Parameter range: A range for slicing.
     
     - Returns: A substring sliced at the given range as a string.
     */
    subscript(_ range: Range<Int>) -> String {
        get {
            let characters = components()
            return characters[range].joined()
        }
    }
    
    var range: NSRange {
        return nsString.range
    }
    
    var nsString: NSString {
        return self as NSString
    }
    
    func rangeForLines(at lineRange: Range<Int>) -> NSRange {
        var range: NSRange = .zero
        let lines = components(separatedBy: .newlines)
        for i in 0..<lineRange.lowerBound {
            range.location += lines[i].nsString.length + 1
        }
        for i in lineRange {
            range.length += lines[i].nsString.length + 1
        }
        return range
    }
    
    func matches(pattern: RegEx) -> Bool {
        return range(of: pattern.pattern, options: .regularExpression) != nil
    }
    
}

extension NSString {
    
    /// Swift String value of the `NSString` object.
    var string: String {
        return self as String
    }
    
    var range: NSRange {
        return NSMakeRange(0, length)
    }
    
}

extension NSAttributedString {
    
    var range: NSRange {
        return NSMakeRange(0, length)
    }
    
}

extension NSMutableAttributedString {
    
    func addAttributes(_ attributes: [NSAttributedString.Key : Any]) {
        addAttributes(attributes, range: range)
    }
    
    func addAttribute(_ name: NSAttributedString.Key, value: Any) {
        addAttribute(name, value: value, range: range)
    }
    
    func removeAttribute(_ name: NSAttributedString.Key) {
        removeAttribute(name, range: range)
    }
    
}
