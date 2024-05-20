import Cocoa

class RegEx: NSRegularExpression, ExpressibleByStringInterpolation, RawRepresentable {
    
    var rawValue: String {
        return pattern
    }
    
    required init?(rawValue: String) {
        try? super.init(pattern: rawValue)
    }
    
    required init(stringLiteral value: String) {
        try! super.init(pattern: value)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}
