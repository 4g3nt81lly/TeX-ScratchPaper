//
//  TeXCommand.swift
//  Scratch Paper
//
//  Created by Bingyi Billy Li on 2022/7/9.
//

import Cocoa

typealias TeXCommands = [TeXCommand]

/// An object, representing an input TeX command that is untrusted by default.
struct TeXCommand: Identifiable {
    
    /// An unique identifier of the TeX command.
    var id = UUID()
    
    /// Name of the TeX command.
    var name: String
    
    /// A boolean value indicating whether the input TeX command is trusted.
    var trusted: Bool = false
    
    init(name: String) {
        self.name = name
    }
}

extension TeXCommands {
    
    /**
     An array object of an array of TeX commands.
     
     This property is used for file-saving purposes.
     */
    var arrayObject: NSArray {
        return self.map({ $0.trusted }) as NSArray
    }
    
}
