import Cocoa

/**
 An object that represents the application settings.
 
 This object manages the app settings.
 
 - Note: No more than one unique instance of this object should be created.
 */
@objcMembers
final class AppSettings: NSObject, NSSecureCoding, Reflective {
    
    static var shared: AppSettings = {
        if let pathURL = Scratch_Paper.fileManager.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first?.appendingPathComponent("config"),
           let data = try? Data(contentsOf: pathURL),
           let appSettings = try? NSKeyedUnarchiver.unarchivedObject(ofClass: AppSettings.self, from: data) {
            return appSettings
        }
        return AppSettings()
    }()
    
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
        
        config.renderMode = renderMode
        
        config.displayMode = displayMode
        config.displayStyle = displayStyle
        
        config.lineToLine = lineToLine
        
        config.lockToBottom = lockToBottom
        config.lockToRight = lockToRight
        
        config.liveRender = liveRender
        
        config.renderError = renderError
        config.errorColorString = errorColorString
        
        config.minLineThicknessEnabled = minLineThicknessEnabled
        config.minLineThickness = minLineThickness
        
        config.leftJustifyTags = leftJustifyTags
        
        config.sizeLimitEnabled = sizeLimitEnabled
        config.sizeLimit = sizeLimit
        
        config.maxExpansionEnabled = maxExpansionEnabled
        config.maxExpansion = maxExpansion
        
        config.trustAllCommands = trustAllCommands
        config.trustedCommands = trustedCommands
        
        return config
    }
    
    /**
     Saves the app settings to drive as file.
     
     This method makes an attempt to save the receive app settings object to file.
     
     - Note: No fallback solution (like using user defaults) implemented yet.
     */
    func save() {
        if let pathURL = Scratch_Paper.fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?.appendingPathComponent("config") {
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
    
    override private init() {
        super.init()
    }
    
    static var supportsSecureCoding = true
    
    func encode(with coder: NSCoder) {
        for key in properties {
            switch key {
            case "trustedCommands":
                coder.encode(trustedCommands.arrayObject, forKey: key)
            default:
                if let number = self[key] as? NSNumber {
                    coder.encode(number, forKey: key)
                } else if let string = self[key] as? NSString {
                    coder.encode(string, forKey: key)
                }
            }
        }
    }
    
    required init?(coder: NSCoder) {
        super.init()
        for key in properties {
            switch key {
            case "trustedCommands":
                if let array = coder.decodeObject(of: [NSArray.self, NSNumber.self],
                                                  forKey: key) as? NSArray,
                   let commandsArray = Array(array) as? [NSNumber],
                   commandsArray.count == trustedCommands.count {
                    for index in 0..<trustedCommands.count {
                        trustedCommands[index].trusted = commandsArray[index].boolValue ?? false
                    }
                }
            default:
                if let _ = self[key] as? NSNumber,
                   let value = coder.decodeObject(of: NSNumber.self, forKey: key) {
                    self[key] = value
                } else if let _ = self[key] as? NSString,
                          let value = coder.decodeObject(of: NSString.self, forKey: key) {
                    self[key] = value
                }
            }
        }
    }
    
}
