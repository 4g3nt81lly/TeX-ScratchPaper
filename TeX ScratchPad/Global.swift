//
//  Global.swift
//  TeX-ScratchPad
//
//  Created by Bingyi Billy Li on 2022/7/4.
//

import Cocoa

let userDefaults = UserDefaults.standard
let appDelegate = NSApp.delegate as! AppDelegate
let mainStoryboard = NSStoryboard.main!
let mainBundle = Bundle.main

extension String {
    
    func count(_ item: String) -> Int {
        return self.components(separatedBy: item).count - 1
    }
    
    func components() -> [String] {
        var components: [String] = []
        for char in self {
            components.append(String(char))
        }
        return components
    }
    
    subscript(_ range: Range<Int>) -> String {
        get {
            let characters = self.components()
            return characters[range].joined()
        }
    }
    
    subscript(_ index: Int) -> String {
        get {
            let characters = self.components()
            return characters[index]
        }
    }
    
}

extension Bool {
    
    public var intValue: Int {
        return self ? 1 : 0
    }
    
}
