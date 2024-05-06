import Cocoa
import SwiftUI
import Combine

/**
 An object that represents a document's configuration.
 
 This object manages a document's configuration.
 
 - Note: Each document object should have no more than one instance of this object.
 */
class Configuration: NSObject, NSCopying, ObservableObject, Reflective, LoopSafe {
    
    /// Document's last cursor position.
    var cursorPosition = 0
    
    /**
     KaTeX render mode.
     
     `0` for text-based rendering and `1` for math-based rendering.
     */
    @objc dynamic var renderMode = 0
    
    /**
     A boolean value indicating whether display mode is enabled.
     
     Set this to `true` to enable display mode.
     */
    @objc dynamic var displayMode = false
    
    /**
     A boolean value indicating whether display style rendering is enabled.
     
     Set this to `true` to enable display style rendering.
     */
    @objc dynamic var displayStyle = false
    
    /**
     A boolean value indicating whether line-to-line editing mode is enabled.
     
     Set this to `true` to enable line-to-line editing mode.
     */
    @objc dynamic var lineToLine = false
    
    /**
     A boolean value indicating whether lock-to-bottom is enabled.
     
     Set this to `true` to lock the KaTeX view to the bottom of its view content.
     */
    @objc dynamic var lockToBottom = false
    
    /**
     A boolean value indicating whether lock-to-right is enabled.
     
     Set this to `true` to lock the KaTeX view to the right of its view content.
     */
    @objc dynamic var lockToRight = false
    
    /**
     A boolean value indicating whether live rendering is enabled.
     
     Set this to `true` to enable live rendering.
     */
    @Published var liveRender = true
    
    /**
     A boolean value indicating whether error rendering is enabled.
     
     Set this to `false` to disable error rendering in KaTeX view.
     */
    @Published var renderError = true
    
    /**
     Error rendering color.
     
     Set this to the hex string representation of a color to always render error in this color in KaTeX view. This property is linked to `errorColor` which captures the actual color object the hex string represents.
     
     - Note: This is ignored if `renderError` is `false`.
     */
    @Published var errorColorString = "CC0000" {
        didSet {
            doNotLoop {
                loopSafe {
                    self.errorColor = Color(hex: self.errorColorString)!
                }
            }
        }
    }
    
    /**
     Error rendering color.
     
     This property is linked to `errorColorString`. It stores the actual color object by which the hex string represents.
     */
    @Published var errorColor = Color(hex: "CC0000")! {
        didSet {
            doNotLoop {
                loopSafe {
                    self.errorColorString = self.errorColor.hex!
                }
            }
        }
    }
    
    /**
     A boolean value indicating whether minimum line thickness constraint is enabled.
     
     Set this to `true` to enable minimum line thickness constraint for rendering.
     */
    @Published var minLineThicknessEnabled = false
    
    /**
     Minimum line thickness constraint.
     
     Set this to a value as the minimum line thickness constraint for rendering.
     
     - Note: This is ignored if `minLineThicknessEnabled` is `false`.
     */
    @Published var minLineThickness = 0.04
    
    /**
     A boolean value indicating whether or not to left justify tags.
     
     Set this to `true` to left justify all tags in KaTeX view.
     */
    @Published var leftJustifyTags = false
    
    /**
     A boolean value indicating whether size constraint is enabled.
     
     Set this to `true` to enable size constraint for rendering.
     */
    @Published var sizeLimitEnabled = false
    
    /**
     Size constraint.
     
     Set this to a value as the maximum size for rendering.
     
     - Note: This is ignored if `sizeLimiteEnabled` is `false`.
     */
    @Published var sizeLimit = 500.0
    
    /// Number formatter for size constraint.
    let sizeLimitFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimum = 0.01
        formatter.maximum = Double.infinity as NSNumber
        formatter.maximumFractionDigits = 2
        return formatter
    }()
    
    /**
     A boolean value indicating whether macro expansion constraint is enabled.
     
     Set this to `true` to enable macro expansion constraint for rendering.
     */
    @Published var maxExpansionEnabled = false
    
    /**
     Maximum number of macro expansions allowed.
     
     Set this to a value as the maximum number of macro expansions allowed for rendering.
     
     - Note: This is ignored if `maxExpansionEnabled` is `false`.
     */
    @Published var maxExpansion = 1000.0
    
    /// Number formatter for macro expansion constraint.
    let maxExpansionFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimum = 1
        formatter.maximum = Double.infinity as NSNumber
        return formatter
    }()
    
    /**
     A boolean value indicating whether all input commands are trusted.
     
     Set this to `true` to trust all input commands when rendering.
     
     - Note: This is only `true` when all commands in `trustedCommands` are trusted (`trusted = true`).
     */
    @Published var trustAllCommands = false {
        didSet {
            doNotLoop {
                loopSafe {
                    for index in 0..<self.trustedCommands.count {
                        self.trustedCommands[index].trusted = self.trustAllCommands
                    }
                }
            }
        }
    }
    
    /**
     An array of input commands with trust status.
     
     Set `trusted` to `true` for specific commands to trust them when rendering.
     
     - Note: When all the commands are trusted, `trustAllCommands` is updated to `true`.
     */
    @Published var trustedCommands = [
        TeXCommand(name: "\\url"),
        TeXCommand(name: "\\href"),
        TeXCommand(name: "\\htmlClass"),
        TeXCommand(name: "\\htmlId"),
        TeXCommand(name: "\\htmlStyle"),
        TeXCommand(name: "\\htmlData"),
        TeXCommand(name: "\\includegraphics")
    ] {
        didSet {
            doNotLoop {
                loopSafe {
                    self.trustAllCommands = self.trustedCommands.map({ $0.trusted }).all
                }
                for index in 0..<self.trustedCommands.count {
                    appSettings.trustedCommands[index].trusted = self.trustedCommands[index].trusted
                }
            }
        }
    }
    
    /**
     Saves the configuration as default app settings.
     
     This method updates the default app settings with the receiver configuration object so that new documents will be opened with the same configuration.
     */
    func saveToSettings() {
        for property in self.properties.filter({ $0.first != "_" }) {
            appSettings.setValue(self[property], forKey: property)
        }
        appSettings.liveRender = self.liveRender
        
        appSettings.renderError = self.renderError
        appSettings.errorColorString = self.errorColorString
        
        appSettings.minLineThicknessEnabled = self.minLineThicknessEnabled
        appSettings.minLineThickness = self.minLineThickness
        
        appSettings.leftJustifyTags = self.leftJustifyTags
        
        appSettings.sizeLimitEnabled = self.sizeLimitEnabled
        appSettings.sizeLimit = self.sizeLimit
        
        appSettings.maxExpansionEnabled = self.maxExpansionEnabled
        appSettings.maxExpansion = self.maxExpansion
        
        appSettings.trustAllCommands = self.trustAllCommands
        for index in 0..<self.trustedCommands.count {
            appSettings.trustedCommands[index].trusted = self.trustedCommands[index].trusted
        }
    }
    
    override init() {
        super.init()
    }
    
    /**
     Creates a new copy of the receiver configuration object.
     
     This method is used whenever a discardable configuration object is needed for user-initiated modification.
     */
    func copy(with zone: NSZone? = nil) -> Any {
        let config = Configuration()
        config.cursorPosition = self.cursorPosition
        
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
     Inherited from `NSObject` - Defines the rules by which the configuration object is compared.
     
     This method is primarily used to determine whether there exists a change in the configuration by comparing the document's configuration object with its temporary potentially-modified copy.
     */
    override func isEqual(to object: Any?) -> Bool {
        guard let obj = object as? Configuration else { return false }
        let gates = [self.cursorPosition == obj.cursorPosition,
                     self.renderMode == obj.renderMode,
                     self.displayMode == obj.displayMode,
                     self.displayStyle == obj.displayStyle,
                     self.lineToLine == obj.lineToLine,
                     self.lockToBottom == obj.lockToBottom,
                     self.lockToRight == obj.lockToRight,
                     self.liveRender == obj.liveRender,
                     self.renderError == obj.renderError,
                     self.errorColorString == obj.errorColorString,
                     self.errorColor == obj.errorColor,
                     self.minLineThicknessEnabled == obj.minLineThicknessEnabled,
                     self.minLineThickness == obj.minLineThickness,
                     self.leftJustifyTags == obj.leftJustifyTags,
                     self.sizeLimitEnabled == obj.sizeLimitEnabled,
                     self.sizeLimit == obj.sizeLimit,
                     self.maxExpansionEnabled == obj.maxExpansionEnabled,
                     self.maxExpansion == obj.maxExpansion,
                     self.trustAllCommands == obj.trustAllCommands,
                     self.trustedCommands.map({ $0.trusted }) == obj.trustedCommands.map({ $0.trusted })
        ]
        return gates.all
    }
    
    var loopLock: BinaryState = .off
    
    var screens = ["loopLock", "cursorPosition", "sizeLimitFormatter", "maxExpansionFormatter"]
    
}
