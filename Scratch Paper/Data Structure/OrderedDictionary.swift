//
//  OrderedDictionary.swift
//  Scratch Paper
//
//  Created by Bingyi Billy Li on 2022/2/14.
//

import Cocoa

/// An ordered collection of key-value pairs in the form of a dictionary.
struct OrderedDictionary<Key: Hashable, Value> : Sequence, IteratorProtocol, ExpressibleByDictionaryLiteral, ExpressibleByArrayLiteral, CustomStringConvertible {
    
    typealias Element = (Key, Value)
    
    typealias ArrayLiteralElement = Element
    
    /// An array of key-value pairs.
    private var orderedPairs: [(Key, Value)]
    
    /// An array of the keys of the dictionary.
    var keys: [Key] {
        return self.orderedPairs.map({ $0.0 })
    }
    
    public var count: Int {
        return self.orderedPairs.count
    }
    
    public var isEmpty: Bool {
        return self.orderedPairs.isEmpty
    }
    
    var description: String {
        return "\(self.orderedPairs)"
    }
    
    public func reversed() -> [Element] {
        return self.orderedPairs.reversed()
    }
    
    /// A counter for the iterator.
    private var counter = 0
    
    mutating func next() -> (Key, Value)? {
        guard self.counter < self.orderedPairs.count else {
            return nil
        }
        let element = self.orderedPairs[self.counter]
        self.counter += 1
        return element
    }
    
    func makeIterator() -> Self {
        return Self(keyValuePairs: self.orderedPairs)
    }
    
    subscript(key: Key, default: Key? = nil) -> Value? {
        get {
            return self.orderedPairs.first(where: { $0.0 == key })?.1 ?? self.orderedPairs.first(where: { $0.0 == `default` })?.1
        }
        set {
            if let index = self.orderedPairs.firstIndex(where: { $0.0 == key }) {
                self.orderedPairs[index].1 = newValue!
            } else {
                self.orderedPairs += [(key, newValue!)]
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
        self.orderedPairs.removeAll(where: { $0.0 == key })
    }
    
    init(keyValuePairs pairs: [(Key, Value)]) {
        self.orderedPairs = pairs
    }
    
    init(dictionaryLiteral elements: (Key, Value)...) {
        self.init(keyValuePairs: elements)
    }
    
    init(arrayLiteral elements: Element...) {
        self.init(keyValuePairs: elements)
    }
    
}
