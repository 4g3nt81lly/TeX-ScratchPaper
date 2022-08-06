//
//  BookmarkEntry.swift
//  Scratch Paper
//
//  Created by Bingyi Billy Li on 2022/7/11.
//

import Cocoa

typealias Bookmarks = [BookmarkEntry]

/**
 An object that represents a bookmark entry.
 
 This object represents a bookmark added and saved in the document.
 
 - Note: Each document object can have multiple instances of this object.
 */
struct BookmarkEntry: Identifiable, Hashable {
    
    /// An unique identifier of the bookmark.
    var id = UUID()
    
    /// Name of the bookmark.
    var name = ""
    
    /**
     A boolean value indicating whether the bookmark is properly named.
     
     This property is managed by `BookmarksEditor` and should not be tampered with without context.
     */
    var unnamed = true
    
    /// A description of the bookmark.
    var description = ""
    
    /// Icon of the bookmark.
    var iconName = "bookmark.fill"
    
    /**
     Static ranges captured by the bookmark.
     
     The user is not given an option to alter this value.
     */
    var ranges: [NSRange]
    
    /**
     A dictionary representation of the object.
     
     This property is used for file-saving purposes.
     */
    var dictionary: [String : Any] {
        return ["id": self.id,
                "name": self.name,
                "unnamed": self.unnamed,
                "description": self.description,
                "icon": self.iconName,
                "ranges": self.ranges]
    }
    
    /**
     An empty bookmark.
     
     This should only be used as a placeholder.
     */
    static var empty = BookmarkEntry(ranges: [])
    
    /**
     A new bookmark entry with given ranges.
     
     - Parameter ranges: Selected ranges.
     
     - Returns: A new instance of the bookmark with the selected ranges.
     */
    static func new(_ ranges: [NSRange]) -> BookmarkEntry {
        return BookmarkEntry(ranges: ranges)
    }
    
}

extension Bookmarks {
    
    /**
     An array object of an array of bookmarkst.
     
     This property is used for file-saving purposes.
     */
    var arrayObject: NSArray {
        return self.map({ $0.dictionary as NSDictionary }) as NSArray
    }
    
}

extension Array where Element == NSRange {
    
    /**
     Computes an aggregate range for all the ranges in the receiver array.
     
     This method asserts that the array is not empty and thus expecting at least one range object in the receive array.
     
     - Warning: A fatal error will be thrown if the receiver array is empty as the method is attempting to get a range with the foremost position as the starting location for the aggregate range.
     
     - Returns: The aggregate range containing all the containing ranges of the receiver array, or the only range.
     */
    func aggregateRange() -> NSRange {
        assert(!self.isEmpty)
        if self.count == 1 {
            return self.first!
        }
        let firstLocation = self.map({ $0.location }).min()!
        let furthestRange = self.max(by: { $0.location < $1.location })!
        let aggregateLength = furthestRange.upperBound - firstLocation
        return NSMakeRange(firstLocation, aggregateLength)
    }
    
}
