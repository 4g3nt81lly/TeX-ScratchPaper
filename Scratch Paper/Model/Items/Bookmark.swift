import Cocoa

/**
 An object that represents a bookmark entry.
 
 This object represents a bookmark added and saved in the document.
 
 - Note: Each document object can have multiple instances of this object.
 */
struct Bookmark: Identifiable, Hashable, Reflective {
    
    /// An unique identifier of the bookmark.
    var id: UUID
    
    /// Name of the bookmark.
    var name: String
    
    /// A description of the bookmark.
    var description: String
    
    /// Icon of the bookmark.
    var icon: String
    
    var ranges: [NSRange]
    
    var attributeID: String {
        return id.uuidString
    }
    
    /**
     A dictionary representation of the object.
     
     This property is used for file-saving purposes.
     */
    var dictionary: [String : Any] {
        return items
    }
    
    init(at ranges: [NSValue]) {
        self.init(from: ["ranges": ranges])
    }
    
    init(from dictionary: [String : Any]) {
        self.id = (dictionary["id"] as? UUID) ?? UUID()
        self.name = (dictionary["name"] as? String) ?? ""
        self.description = (dictionary["description"] as? String) ?? ""
        self.icon = (dictionary["icon"] as? String) ?? "bookmark.fill"
        self.ranges = (dictionary["ranges"] as? [NSRange]) ?? []
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Bookmark, rhs: Bookmark) -> Bool {
        return lhs.id == rhs.id
    }
    
}

extension NSAttributedString.Key {
    
    static func bookmark(with bookmark: Bookmark) -> NSAttributedString.Key {
        return .init("bookmark_\(bookmark.id)")
    }
    
}

extension Collection where Element == NSRange {
    
    /**
     Computes an aggregate range for all the ranges in the receiver array.
     
     - Returns: The aggregate range containing all the ranges in the receiver array. An empty range if
                the array is empty.
     */
    func aggregateRange() -> NSRange {
        guard (!isEmpty) else {
            return .zero
        }
        if (count > 1) {
            let firstLocation = map({ $0.location }).min()!
            let furthestRange = self.max(by: { $0.location < $1.location })!
            let aggregateLength = furthestRange.upperBound - firstLocation
            return NSRange(location: firstLocation, length: aggregateLength)
        }
        return first!
    }
    
    var totalLength: Int {
        return reduce(0) { partialResult, range in
            partialResult + range.length
        }
    }
    
}

extension Array where Element == NSRange {
    
    func optimized() -> Self {
        var contiguousRanges: [NSRange] = []
        var contiguousRange = self[0]
        if (count > 1) {
            for range in self[1...] {
                if (range.location == contiguousRange.upperBound) {
                    // combine contiguous ranges
                    contiguousRange.length += range.length
                } else {
                    contiguousRanges.append(contiguousRange)
                    contiguousRange = range
                }
            }
        }
        contiguousRanges.append(contiguousRange)
        return contiguousRanges
    }
    
}
