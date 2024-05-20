import Cocoa

/// An ordered collection of key-value pairs in the form of a dictionary.
struct OrderedDictionary<Key: Hashable, Value> : Sequence, IteratorProtocol,
                                                 ExpressibleByDictionaryLiteral, ExpressibleByArrayLiteral, CustomStringConvertible {
    
    typealias Element = (key: Key, value: Value)
    
    typealias ArrayLiteralElement = Element
    
    /// An array of key-value pairs.
    private var orderedPairs: [Element] = []
    
    private var map: [Key : (index: Int, value: Value)] = [:]
    
    /// An ordered array of keys of the dictionary.
    public var keys: [Key] = []
    
    /// A counter for the iterator.
    private var counter = 0
    
    public var count: Int {
        return orderedPairs.count
    }
    
    public var isEmpty: Bool {
        return orderedPairs.isEmpty
    }
    
    var description: String {
        return "\(orderedPairs)"
    }
    
    init(keyValuePairs pairs: [Element]) {
        for (index, (key, value)) in pairs.enumerated() {
            orderedPairs.append((key, value))
            keys.append(key)
            map[key] = (index, value)
        }
    }
    
    init(dictionaryLiteral elements: (Key, Value)...) {
        self.init(keyValuePairs: elements)
    }
    
    init(arrayLiteral elements: Element...) {
        self.init(keyValuePairs: elements)
    }
    
    mutating func next() -> Element? {
        guard counter < count else {
            return nil
        }
        let element = orderedPairs[counter]
        counter += 1
        return element
    }
    
    func makeIterator() -> Self {
        return Self(keyValuePairs: orderedPairs)
    }
    
    public func reversed() -> [Element] {
        return orderedPairs.reversed()
    }
    
    subscript(key: Key, default defaultKey: Key? = nil) -> Value? {
        get {
            if let defaultKey {
                return (map[key] ?? map[defaultKey])?.value
            }
            return map[key]?.value
        }
        set {
            if let (index, _) = map[key] {
                orderedPairs[index].value = newValue!
                map[key]!.value = newValue!
            } else {
                map[key] = (count, newValue!)
                orderedPairs.append((key, newValue!))
                keys.append(key)
            }
        }
    }
    
    subscript(index: Int) -> Element? {
        get {
            return orderedPairs.indices.contains(index) ? orderedPairs[index] : nil
        }
        set {
            guard (index >= 0 && index < count) else {
                fatalError("subscript setter index out of bound")
            }
            if let (newKey, newValue) = newValue {
                orderedPairs[index] = (newKey, newValue)
                let oldKey = keys[index]
                if newKey != oldKey {
                    // update key
                    keys[index] = newKey
                    map.removeValue(forKey: oldKey)
                }
                map[newKey] = (index, newValue)
            } else {
                // the new value is nil, remove key-value pair
                orderedPairs.remove(at: index)
                let removedKey = keys.remove(at: index)
                map.removeValue(forKey: removedKey)
            }
        }
    }
    
    /**
     Sets a value by key.
     
     - Parameters:
        - key: The key by which the value is set.
        - value: The value to be set.
     */
    mutating func set(_ key: Key, value: Value) {
        self[key] = value
    }
    
    /**
     Removes a value by key.
     
     - Parameter key: The key of the value to be removed.
     */
    mutating func remove(byKey key: Key) {
        if let (index, _) = map.removeValue(forKey: key) {
            keys.remove(at: index)
            orderedPairs.remove(at: index)
        }
    }
    
}
