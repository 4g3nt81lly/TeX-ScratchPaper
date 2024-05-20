import Foundation

extension Array {
    
    /**
     Counts the number of elements that satisfy a given predicate within the receiver array.
     
     - Parameter predicate: A custom predicate.
     
     - Returns: The number of elements that satisfy the given predicate.
     */
    func count(_ predicate: (Self.Element) -> Bool) -> Int {
        return filter(predicate).count
    }
    
}

extension Sequence where Element: Numeric {
    
    /**
     Sums up all the elements by their value in a numeric sequence.
     
     - Returns: The total sum of all the numeric elements.
     */
    func sum() -> Self.Element {
        var sum: Self.Element = .zero
        forEach { element in
            sum += element
        }
        return sum
    }
    
}

extension Array where Element == Bool {
    
    /// A boolean value indicating whether any of the array is true.
    var any: Bool {
        return contains(true)
    }
    
    /// A boolean value indicating whether all of the array is true.
    var all: Bool {
        return !contains(false)
    }
    
}
