//
//  OutlineEntry.swift
//  Scratch Paper
//
//  Created by Bingyi Billy Li on 2022/7/4.
//

import Cocoa

/**
 An object that represents an outline entry.
 
 This object represents a section of the main content.
 
 - Note: Each document object can have multiple instances of this object depending on the content.
 */
class OutlineEntry: NSObject {
    
    /// A visible portion of the section.
    @objc dynamic var content: String
    
    /// The line range covered by the section.
    var lineRange: Range<Int>
    
    /// The selectable range of the section.
    var selectableRange: NSRange
    
    init(text: String, lineRange: Range<Int>, selectableRange: NSRange) {
        self.content = text
        self.lineRange = lineRange
        self.selectableRange = selectableRange
    }
    
}
