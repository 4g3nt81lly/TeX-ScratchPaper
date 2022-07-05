//
//  FileContent.swift
//  TeX-ScratchPad
//
//  Created by Bingyi Billy Li on 2021/6/14.
//

import Cocoa

@objcMembers
class FileContent: NSObject {
    
    dynamic var contentString: String
    
    dynamic var renderMode = userDefaults.integer(forKey: "lastUsedRenderMode") {
        didSet {
            userDefaults.set(self.renderMode, forKey: "lastUsedRenderMode")
        }
    }
    dynamic var displayMode = userDefaults.bool(forKey: "lastUsedDisplayMode") {
        didSet {
            userDefaults.set(self.displayMode, forKey: "lastUsedDisplayMode")
        }
    }
    dynamic var lineCorrespondence = userDefaults.bool(forKey: "lineCorrespondence") {
        didSet {
            userDefaults.set(self.lineCorrespondence, forKey: "lineCorrespondence")
        }
    }
    dynamic var displayStyle = userDefaults.bool(forKey: "lastUsedDisplayStyle") {
        didSet {
            userDefaults.set(self.displayStyle, forKey: "lastUsedDisplayStyle")
        }
    }
    dynamic var lockToBottom = userDefaults.bool(forKey: "lockToBottom") {
        didSet {
            userDefaults.set(self.lockToBottom, forKey: "lockToBottom")
        }
    }
    dynamic var lockToRight = userDefaults.bool(forKey: "lockToRight") {
        didSet {
            userDefaults.set(self.lockToRight, forKey: "lockToRight")
        }
    }
    
    var cursorPosition = 0
    
    public init(_ contentString: String = "") {
        self.contentString = contentString
    }
    
    func data() -> Data {
        var configString = "#@!{[cursor=\(self.cursorPosition)][render=\(self.renderMode == 0 ? "text" : "math")]\(self.displayMode || self.displayStyle ? "[display" : "")"
        configString += self.displayMode ? "(mode)" : ""
        configString += self.displayStyle ? "(style)" : ""
        configString += self.displayMode || self.displayStyle ? "]" : ""
        configString += self.lineCorrespondence ? "[correspondence]" : ""
        configString += self.lockToBottom ? "[lockToBottom]" : ""
        configString += self.lockToRight ? "[lockToRight]" : ""
        configString += "}"
        return [configString, self.contentString].joined(separator: "\n").data(using: .utf8)!
    }
    
    func read(_ fromData: Data) {
        let content = String(data: fromData, encoding: .utf8)!
        
        var contentComponents = content.components(separatedBy: "\n")
        let configString = contentComponents[0]
        let configRange = NSRange(location: 0, length: (configString as NSString).length)
        
        if #available(macOS 13.0, *) {
            // using new Regex feature
            
            let configMatches = configString.matches(of: /#@!\{[A-Za-z0-9=\(\)\[\]]+\}/)
            guard configMatches.count == 1 else {
                // invalid config header
                contentComponents.removeFirst()
                self.contentString = contentComponents.joined(separator: "\n")
                return
            }
            
            let cursorMatches = configString.matches(of: /\[cursor=(\d+)\]/)
            if cursorMatches.count == 1 {
                let (_, position) = cursorMatches.first!.output
                self.cursorPosition = Int(position)!
            }
            
            let renderMatches = configString.matches(of: /\[render=(text|math)\]/)
            if renderMatches.count == 1 {
                let (_, renderMode) = renderMatches.first!.output
                self.renderMode = (renderMode == "math").intValue
            }
            
            let displayMatches = configString.matches(of: /\[display(\((mode|style)\))+\]/)
            if displayMatches.count == 1 {
                let (string, _, _) = displayMatches.first!.output
                self.displayMode = string.contains("mode")
                self.displayStyle = string.contains("style")
            }
        } else {
            // fallback on earlier versions
            let configParser = try! NSRegularExpression(pattern: #"#@!\{[A-Za-z0-9=\(\)\[\]]+\}"#)
            guard configParser.numberOfMatches(in: configString, range: configRange) == 1 else {
                contentComponents.removeFirst()
                self.contentString = contentComponents.joined(separator: "\n")
                return
            }
            
            // matches [cursor=(number)] for cursor position
            let cursorConfig = try! NSRegularExpression(pattern: #"\[cursor=\d+\]"#)
            if cursorConfig.numberOfMatches(in: configString, range: configRange) == 1 {
                let range = cursorConfig.rangeOfFirstMatch(in: configString, range: configRange)
                let matchedString = (configString as NSString).substring(with: range)
                self.cursorPosition = Int(matchedString.trimmingCharacters(in: CharacterSet(charactersIn: "]")).components(separatedBy: "=").last!)!
            }
            
            // matches [render=(text|math)] for render mode
            let renderConfig = try! NSRegularExpression(pattern: #"\[render=(text|math)\]"#)
            if renderConfig.numberOfMatches(in: configString, range: configRange) == 1 {
                let range = renderConfig.rangeOfFirstMatch(in: configString, range: configRange)
                let matchedString = (configString as NSString).substring(with: range)
                self.renderMode = matchedString.contains("text") ? 0 : 1
            }
            
            // matches [display(mode|style)] for display mode/style
            let displayConfig = try! NSRegularExpression(pattern: #"\[display(\((mode|style)\))+\]"#)
            if displayConfig.numberOfMatches(in: configString, range: configRange) == 1 {
                let range = displayConfig.rangeOfFirstMatch(in: configString, range: configRange)
                let matchedString = (configString as NSString).substring(with: range)
                self.displayMode = matchedString.contains("mode")
                self.displayStyle = matchedString.contains("style")
            }
        }
        
        self.lineCorrespondence = configString.contains("[correspondence]")
        self.lockToRight = configString.contains("[lockToRight]")
        self.lockToBottom = configString.contains("[lockToBottom]")
        
        contentComponents.removeFirst()
        self.contentString = contentComponents.joined(separator: "\n")
    }
    
}
