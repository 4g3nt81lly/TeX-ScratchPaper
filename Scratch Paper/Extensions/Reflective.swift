import Cocoa

/// A protocol that implements introspective member-lookup mechanism.
protocol Reflective {
    
    /// An array of property names to be ignored by the member-lookup.
    var screens: [String] { get }
    
}

extension Reflective {
    
    static var staticProperties: [String]? {
        guard let `self` = self as? NSObject.Type else {
            return nil
        }
        var count: UInt32 = 0
        guard let propertyList = class_copyPropertyList(object_getClass(self), &count) else {
            return nil
        }
        var properties: [String] = []
        for index in 0..<count {
            let name = property_getName(propertyList.advanced(by: Int(index)).pointee)
            if let key = String(cString: name, encoding: .utf8) {
                properties.append(key)
            }
        }
        free(propertyList)
        return properties
    }
    
    var screens: [String] {
        get { return [] }
        set {}
    }
    
    /// An array of the receiver's property names.
    var properties: [String] {
        let mirror = Mirror(reflecting: self)
        return mirror.children.compactMap { item in
            if let label = item.label,
               label != "screens", !screens.contains(label) {
                return label
            }
            return nil
        }
    }
    
    var items: [String : Any] {
        let mirror = Mirror(reflecting: self)
        var items: [String : Any] = [:]
        mirror.children.forEach { (label, value) in
            if let key = label,
               key != "screens", !screens.contains(key) {
                items[key] = value
            }
        }
        return items
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
               properties.contains(key) {
                object.setValue(newValue, forKey: key)
            } else {
                NSLog("Unable to set property through subscript notation on an non-NSObject object.")
            }
        }
    }
}
