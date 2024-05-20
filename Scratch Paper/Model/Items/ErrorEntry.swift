import Cocoa

/**
 An object that represents an error entry.
 
 This object represents an error catched from the KaTeX renderer.
 
 - Note: Each document object can have multiple instances of this object depending on the errors.
 */
class ErrorEntry: NSObject {
    
    /// The line number at which the error occurred.
    var lineNumber: Int
    
    /// The section number at which the error occurred.
    var groupNumber: Int
    
    /// The character position at which the error occurred, if any.
    var charPosition: Int?
    
    /// The error message.
    @objc dynamic var summary: String
    
    override var description: String {
        return summary
    }
    
    init(line: String, group: String, message: String) {
        self.lineNumber = Int(line.components(separatedBy: "_")[1])!
        self.groupNumber = Int(group.components(separatedBy: "_")[1])!
        self.summary = message
        var parsed = message.components(separatedBy: " at position ")
        parsed.removeFirst()
        if let position = parsed.first?.components(separatedBy: ":").first {
            self.charPosition = Int(position)!
        }
    }
    
}
