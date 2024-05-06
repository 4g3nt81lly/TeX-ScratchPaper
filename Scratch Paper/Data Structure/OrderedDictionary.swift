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
        return self.orderedPairs.count
    }
    
    public var isEmpty: Bool {
        return self.orderedPairs.isEmpty
    }
    
    var description: String {
        return "\(self.orderedPairs)"
    }
    
    init(keyValuePairs pairs: [Element]) {
        for (index, (key, value)) in pairs.enumerated() {
            self.orderedPairs.append((key, value))
            self.keys.append(key)
            self.map[key] = (index, value)
        }
    }
    
    init(dictionaryLiteral elements: (Key, Value)...) {
        self.init(keyValuePairs: elements)
    }
    
    init(arrayLiteral elements: Element...) {
        self.init(keyValuePairs: elements)
    }
    
    mutating func next() -> Element? {
        guard self.counter < self.count else {
            return nil
        }
        let element = self.orderedPairs[self.counter]
        self.counter += 1
        return element
    }
    
    func makeIterator() -> Self {
        return Self(keyValuePairs: self.orderedPairs)
    }
    
    public func reversed() -> [Element] {
        return self.orderedPairs.reversed()
    }
    
    subscript(key: Key, default defaultKey: Key? = nil) -> Value? {
        get {
            if let defaultKey {
                return (self.map[key] ?? self.map[defaultKey])?.value
            }
            return self.map[key]?.value
        }
        set {
            if let (index, _) = self.map[key] {
                self.orderedPairs[index].value = newValue!
                self.map[key]!.value = newValue!
            } else {
                self.map[key] = (self.count, newValue!)
                self.orderedPairs.append((key, newValue!))
                self.keys.append(key)
            }
        }
    }
    
    subscript(index: Int) -> Element? {
        get {
            return self.orderedPairs.indices.contains(index) ? self.orderedPairs[index] : nil
        }
        set {
            guard index >= 0 && index < self.count else {
                fatalError("subscript setter index out of bound")
            }
            if let (newKey, newValue) = newValue {
                self.orderedPairs[index] = (newKey, newValue)
                let oldKey = self.keys[index]
                if newKey != oldKey {
                    // update key
                    self.keys[index] = newKey
                    self.map.removeValue(forKey: oldKey)
                }
                self.map[newKey] = (index, newValue)
            } else {
                // the new value is nil, remove key-value pair
                self.orderedPairs.remove(at: index)
                let removedKey = self.keys.remove(at: index)
                self.map.removeValue(forKey: removedKey)
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
        if let (index, _) = self.map.removeValue(forKey: key) {
            self.keys.remove(at: index)
            self.orderedPairs.remove(at: index)
        }
    }
    
}
