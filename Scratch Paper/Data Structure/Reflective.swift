import Cocoa

/// A protocol that implements introspective member-lookup mechanism.
protocol Reflective {
    
    /// An array of property names to be ignored by the member-lookup.
    var screens: [String] { get set }
    
}

extension Reflective {
    
    var screens: [String] {
        get { return [] }
        set {}
    }
    
    /// An array of the receiver's property names.
    var properties: [String] {
        let mirror = Mirror(reflecting: self)
        return mirror.children.compactMap { item in
            if let label = item.label,
               label != "screens",
               !self.screens.contains(label) {
                return label
            }
            return nil
        }
    }
    
    subscript(key: String) -> Any? {
        get {
            if let object = self as? NSObject {
                return object.value(forKey: key)
            }
            let mirror = Mirror(reflecting: self)
            return mirror.children.first(where: { $0.label == key })?.value
        }
        nonmutating set {
            if let object = self as? NSObject,
               self.properties.contains(key) {
                object.setValue(newValue, forKey: key)
            } else {
                NSLog("Unable to set property through subscript notation on an non-NSObject object.")
            }
        }
    }
}
