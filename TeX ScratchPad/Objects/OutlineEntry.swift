//
//  OutlineEntry.swift
//  TeX-ScratchPad
//
//  Created by Bingyi Billy Li on 2022/7/4.
//

import Cocoa

@objcMembers
class OutlineEntry: NSObject {
    
    dynamic var content: String
    var lineRange: Range<Int>
    var selectableRange: NSRange
    
    init(text: String, lineRange: Range<Int>, selectableRange: NSRange) {
        self.content = text
        self.lineRange = lineRange
        self.selectableRange = selectableRange
    }
    
}
