//
//  AppSettings.swift
//  Scratch Paper
//
//  Created by Bingyi Billy Li on 2022/7/9.
//

import Cocoa

/**
 An object that represents the application settings.
 
 This object manages the app settings.
 
 - Note: No more than one unique instance of this object should be created.
 */
@objcMembers
class AppSettings: NSObject, NSSecureCoding, Reflectable {
    
    static var editorFont: NSFont = .monospacedSystemFont(ofSize: 14.0, weight: .regular)
    
    /**
     Default KaTeX render mode.
     
     `0` for text-based rendering and `1` for math-based rendering.
     */
    var renderMode = 0
    
    /**
     Default display mode enabled.
     
     Set this to `true` to enable display mode by default.
     */
    var displayMode = false
    
    /**
     Default display style rendering enabled.
     
     Set this to `true` to enable display style rendering by default.
     */
    var displayStyle = false
    
    /**
     Default line-to-line editing mode enabled.
     
     Set this to `true` to enable line-to-line editing mode by default.
     */
    var lineToLine = false
    
    /**
     Default lock-to-bottom enabled.
     
     Set this to `true` to lock the KaTeX view to the bottom of its view content by default.
     */
    var lockToBottom = false
    
    /**
     Default lock-to-right enabled.
     
     Set this to `true` to lock the KaTeX view to the right of its view content by default.
     */
    var lockToRight = false
    
    /**
     Default live rendering enabled.
     
     Set this to `true` to enable live rendering by default.
     */
    var liveRender = true
    
    /**
     Default error rendering enabled.
     
     Set this to `false` to disable error rendering by default in KaTeX view.
     */
    var renderError = true
    
    /**
     Default error rendering color.
     
     Set this to the hex string representation of a color to always render error in this color by default in KaTeX view.
     
     - Note: This is ignored if `renderError` is `false`.
     */
    var errorColorString = "CC0000"
    
    /**
     Default minimum line thickness constraint enabled.
     
     Set this to `true` to enable minimum line thickness constraint by default for rendering.
     */
    var minLineThicknessEnabled = false
    
    /**
     Default minimum line thickness constraint.
     
     Set this to a value as the default minimum line thickness constraint for rendering.
     
     - Note: This is ignored if `minLineThicknessEnabled` is `false`.
     */
    var minLineThickness = 0.04
    
    /**
     Default left justifying tags enabled.
     
     Set this to `true` to left justify all tags by default in KaTeX view.
     */
    var leftJustifyTags = false
    
    /**
     Default size constraint enabled.
     
     Set this to `true` to enable size constraint by default for rendering.
     */
    var sizeLimitEnabled = false
    
    /**
     Default size constraint.
     
     Set this to a value as the default maximum size for rendering.
     
     - Note: This is ignored if `sizeLimiteEnabled` is `false`.
     */
    var sizeLimit = 500.0
    
    /**
     Default macro expansion constraint enabled.
     
     Set this to `true` to enable macro expansion constraint by default for rendering.
     */
    var maxExpansionEnabled = false
    
    /**
     Default maximum number of macro expansions allowed.
     
     Set this to a value as the default maximum number of macro expansions allowed for rendering.
     
     - Note: This is ignored if `maxExpansionEnabled` is `false`.
     */
    var maxExpansion = 1000.0
    
    /**
     Default trust status of all input commands enabled.
     
     Set this to `true` to trust all input commands by default when rendering.
     
     - Note: This should only be `true` when all commands in `trustedCommands` are trusted (`trusted = true`).
     */
    var trustAllCommands = false
    
    /**
     Default trust status of individual input command.
     
     Set `trusted` to `true` for specific commands to trust them by default when rendering.
     
     - Note: When all the commands are trusted, `trustAllCommands` should be updated to `true`.
     */
    var trustedCommands = [
        TeXCommand(name: "\\url"),
        TeXCommand(name: "\\href"),
        TeXCommand(name: "\\htmlClass"),
        TeXCommand(name: "\\htmlId"),
        TeXCommand(name: "\\htmlStyle"),
        TeXCommand(name: "\\htmlData"),
        TeXCommand(name: "\\includegraphics")
    ]
    
    /**
     Creates a configuration object from the app settings for new documents.
     
     - Returns: A configuration object created using the default app settings.
     */
    func configuration() -> Configuration {
        let config = Configuration()
        
        config.renderMode = self.renderMode
        
        config.displayMode = self.displayMode
        config.displayStyle = self.displayStyle
        
        config.lineToLine = self.lineToLine
        
        config.lockToBottom = self.lockToBottom
        config.lockToRight = self.lockToRight
        
        config.liveRender = self.liveRender
        
        config.renderError = self.renderError
        config.errorColorString = self.errorColorString
        
        config.minLineThicknessEnabled = self.minLineThicknessEnabled
        config.minLineThickness = self.minLineThickness
        
        config.leftJustifyTags = self.leftJustifyTags
        
        config.sizeLimitEnabled = self.sizeLimitEnabled
        config.sizeLimit = self.sizeLimit
        
        config.maxExpansionEnabled = self.maxExpansionEnabled
        config.maxExpansion = self.maxExpansion
        
        config.trustAllCommands = self.trustAllCommands
        config.trustedCommands = self.trustedCommands
        
        return config
    }
    
    /**
     Saves the app settings to drive as file.
     
     This method makes an attempt to save the receive app settings object to file.
     
     - Note: No fallback solution (like using user defaults) implemented yet.
     */
    func save() {
        if let pathURL = Scratch_Paper.fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?.appendingPathComponent("config") {
            do {
                let data = try NSKeyedArchiver.archivedData(withRootObject: self, requiringSecureCoding: true)
                try data.write(to: pathURL)
            } catch {
                NSLog("An error has occurred while saving default configuration: \(String(describing: error))")
            }
        } else {
            NSLog("Failed to get path URL.")
        }
    }
    
    override init() {
        super.init()
    }
    
    static var supportsSecureCoding = true
    
    func encode(with coder: NSCoder) {
        coder.encode(self.renderMode as NSNumber, forKey: "renderMode")
        coder.encode(self.displayMode as NSNumber, forKey: "displayMode")
        coder.encode(self.displayStyle as NSNumber, forKey: "displayStyle")
        coder.encode(self.lineToLine as NSNumber, forKey: "lineToLine")
        coder.encode(self.lockToBottom as NSNumber, forKey: "lockToBottom")
        coder.encode(self.lockToRight as NSNumber, forKey: "lockToRight")
        
        coder.encode(self.liveRender as NSNumber, forKey: "liveRender")
        
        coder.encode(self.renderError as NSNumber, forKey: "renderError")
        coder.encode(self.errorColorString as NSString, forKey: "errorColorString")
        
        coder.encode(self.minLineThicknessEnabled as NSNumber, forKey: "minLineThicknessEnabled")
        coder.encode(self.minLineThickness as NSNumber, forKey: "minLineThickness")
        
        coder.encode(self.leftJustifyTags as NSNumber, forKey: "leftJustifyTags")
        
        coder.encode(self.sizeLimitEnabled as NSNumber, forKey: "sizeLimitEnabled")
        coder.encode(self.sizeLimit as NSNumber, forKey: "sizeLimit")
        
        coder.encode(self.maxExpansionEnabled as NSNumber, forKey: "maxExpansionEnabled")
        coder.encode(self.maxExpansion as NSNumber, forKey: "maxExpansion")
        
        coder.encode(self.trustAllCommands as NSNumber, forKey: "trustAllCommands")
        coder.encode(self.trustedCommands.arrayObject, forKey: "trustedCommands")
    }
    
    required init?(coder: NSCoder) {
        self.renderMode = coder.decodeObject(of: NSNumber.self, forKey: "renderMode")?.intValue ?? 0
        
        self.displayMode = coder.decodeObject(of: NSNumber.self, forKey: "displayMode")?.boolValue ?? false
        self.displayStyle = coder.decodeObject(of: NSNumber.self, forKey: "displayStyle")?.boolValue ?? false
        
        self.lineToLine = coder.decodeObject(of: NSNumber.self, forKey: "lineToLine")?.boolValue ?? false
        
        self.lockToBottom = coder.decodeObject(of: NSNumber.self, forKey: "lockToBottom")?.boolValue ?? false
        self.lockToRight = coder.decodeObject(of: NSNumber.self, forKey: "lockToRight")?.boolValue ?? false
        
        self.liveRender = coder.decodeObject(of: NSNumber.self, forKey: "liveRender")?.boolValue ?? true
        
        self.renderError = coder.decodeObject(of: NSNumber.self, forKey: "renderError")?.boolValue ?? true
        self.errorColorString = coder.decodeObject(of: NSString.self, forKey: "errorColorString")?.string ?? "CC0000"
        
        self.minLineThicknessEnabled = coder.decodeObject(of: NSNumber.self, forKey: "minLineThicknessEnabled")?.boolValue ?? false
        self.minLineThickness = coder.decodeObject(of: NSNumber.self, forKey: "minLineThickness")?.doubleValue ?? 0.04
        
        self.leftJustifyTags = coder.decodeObject(of: NSNumber.self, forKey: "leftJustifyTags")?.boolValue ?? false
        
        self.sizeLimitEnabled = coder.decodeObject(of: NSNumber.self, forKey: "sizeLimitEnabled")?.boolValue ?? false
        self.sizeLimit = coder.decodeObject(of: NSNumber.self, forKey: "sizeLimit")?.doubleValue ?? 500.0
        
        self.maxExpansionEnabled = coder.decodeObject(of: NSNumber.self, forKey: "maxExpansionEnabled")?.boolValue ?? false
        self.maxExpansion = coder.decodeObject(of: NSNumber.self, forKey: "maxExpansion")?.doubleValue ?? 1000.0
        
        self.trustAllCommands = coder.decodeObject(of: NSNumber.self, forKey: "trustAllCommands")?.boolValue ?? false
        if let commandsArray = coder.decodeObject(of: [NSArray.self, NSNumber.self], forKey: "trustedCommands") as? NSArray {
            if let array = Array(commandsArray) as? [NSNumber], array.count == self.trustedCommands.count {
                for index in 0..<self.trustedCommands.count {
                    self.trustedCommands[index].trusted = array[index].boolValue ?? false
                }
            }
        }
        
        super.init()
    }
    
    var screens: [String] = []
    
}
