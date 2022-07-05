//
//  OrderedDictionary.swift
//  Genetic Algorithm Tool
//
//  Created by Bingyi Billy Li on 2022/2/14.
//

import Cocoa

// ExpressibleByDictionaryLiteral: can be declared using a dictionary literal
// Sequence & IteratorProtocol: iterating through ordered elements
// Hashable keys for a dictionary-like object
struct OrderedDictionary<Key : Hashable, Value> : ExpressibleByDictionaryLiteral & Sequence & IteratorProtocol {
    
    // Sequence protocol stub: Element type
    typealias Element = (Key, Value)
    
    // order pairs in array of tuples
    private var orderedPairs: [(Key, Value)]
    
    // computed property: keys getter
    var keys: [Key] {
        return self.orderedPairs.map({ $0.0 })
    }
    
    // counter for iterator
    private var counter = 0
    
    // protocol stub: next value of the iteration
    mutating func next() -> (Key, Value)? {
        guard self.counter < self.orderedPairs.count else {
            return nil
        }
        let element = self.orderedPairs[self.counter]
        self.counter += 1
        return element
    }
    
    // make iterator
    func makeIterator() -> Self {
        return Self(keyValuePairs: self.orderedPairs)
    }
    
    // getter/setter subscript using key
    subscript(key: Key) -> Value? {
        get {
            return self.orderedPairs.first(where: { $0.0 == key })?.1
        }
        set {
            if let index = self.orderedPairs.firstIndex(where: { $0.0 == key }) {
                self.orderedPairs[index].1 = newValue!
            } else {
                self.orderedPairs += [(key, newValue!)]
            }
        }
    }
    
    // set value by key
    mutating func set(_ key: Key, value: Value) {
        self[key] = value
    }
    
    // remove pair by key
    mutating func remove(byKey key: Key) {
        self.orderedPairs.removeAll(where: { $0.0 == key })
    }
    
    init(keyValuePairs pairs: [(Key, Value)]) {
        self.orderedPairs = pairs
    }
    
    // protocol stub required by ExpressibleByDictionaryLiteral
    init(dictionaryLiteral elements: (Key, Value)...) {
        self.init(keyValuePairs: elements)
    }
    
}
