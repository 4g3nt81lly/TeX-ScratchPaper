import Foundation

extension Bool {
    
    /// Integer representation of the receiver's value.
    var intValue: Int {
        return self ? 1 : 0
    }
    
}

extension NSNumber {
    
    /// An exact integer value of the `NSNumber` object.
    var intValue: Int? {
        return Int(exactly: self)
    }
    
    /// An exact boolean value of the `NSNumber` object.
    var boolValue: Bool? {
        return Bool(exactly: self)
    }
    
    /// An exact double value of the `NSNumber` object.
    var doubleValue: Double? {
        return Double(exactly: self)
    }
    
}
