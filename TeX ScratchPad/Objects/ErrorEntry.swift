//
//  ErrorEntry.swift
//  TeX-ScratchPad
//
//  Created by Bingyi Billy Li on 2022/7/4.
//

import Cocoa

class ErrorEntry: NSObject {
    
    var lineNumber: Int
    var groupNumber: Int
    var charPosition: Int?
    @objc dynamic var summary: String
    
    override var description: String {
        return summary
    }
    
    init(line: String, group: String, message: String) {
        self.lineNumber = Int(line.components(separatedBy: "_")[1])!
        self.groupNumber = Int(group.components(separatedBy: "_")[1])!
        self.summary = message
        var parsed = message.components(separatedBy: " at position ")
        parsed.removeFirst()
        if let position = parsed.first?.components(separatedBy: ":").first {
            self.charPosition = Int(position)!
        }
    }
    
}
