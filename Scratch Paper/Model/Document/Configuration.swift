import Cocoa
import SwiftUI
import Combine

/**
 An object that represents a document's configuration.
 
 This object manages a document's configuration.
 
 - Note: Each document object should have no more than one instance of this object.
 */
class Configuration: NSObject, NSSecureCoding, NSCopying, ObservableObject, LoopSafe {
    
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
                    errorColor = Color(hex: errorColorString)!
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
                    errorColorString = errorColor.hex!
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
                    for index in 0..<trustedCommands.count {
                        trustedCommands[index].trusted = trustAllCommands
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
                    trustAllCommands = trustedCommands.map({ $0.trusted }).all
                }
                for index in 0..<trustedCommands.count {
                    appSettings.trustedCommands[index].trusted = trustedCommands[index].trusted
                }
            }
        }
    }
    
    override init() {
        super.init()
    }
    
    /**
     Saves the configuration as default app settings.
     
     This method updates the default app settings with the receiver configuration object so that new documents will be opened with the same configuration.
     */
    func saveToSettings() {
        for property in properties.filter({ $0.first != "_" }) {
            appSettings.setValue(self[property], forKey: property)
        }
        appSettings.liveRender = liveRender
        
        appSettings.renderError = renderError
        appSettings.errorColorString = errorColorString
        
        appSettings.minLineThicknessEnabled = minLineThicknessEnabled
        appSettings.minLineThickness = minLineThickness
        
        appSettings.leftJustifyTags = leftJustifyTags
        
        appSettings.sizeLimitEnabled = sizeLimitEnabled
        appSettings.sizeLimit = sizeLimit
        
        appSettings.maxExpansionEnabled = maxExpansionEnabled
        appSettings.maxExpansion = maxExpansion
        
        appSettings.trustAllCommands = trustAllCommands
        for index in 0..<trustedCommands.count {
            appSettings.trustedCommands[index].trusted = trustedCommands[index].trusted
        }
    }
    
    // MARK: - Secure Coding
    
    private enum Key: String {
        case cursorPosition
        case renderMode
        case displayMode
        case displayStyle
        case lineToLine
        case lockToBottom
        case lockToRight
        case liveRender
        case renderError
        case errorColorString
        case minLineThicknessEnabled
        case minLineThickness
        case leftJustifyTags
        case sizeLimitEnabled
        case sizeLimit
        case maxExpansionEnabled
        case maxExpansion
        case trustAllCommands
        case trustedCommands
    }
    
    static var supportsSecureCoding: Bool = true
    
    func encode(with coder: NSCoder) {
        coder.encode(cursorPosition as NSNumber,
                     forKey: Key.cursorPosition.rawValue)
        coder.encode(renderMode as NSNumber,
                     forKey: Key.renderMode.rawValue)
        coder.encode(displayMode as NSNumber,
                     forKey: Key.displayMode.rawValue)
        coder.encode(displayStyle as NSNumber,
                     forKey: Key.displayStyle.rawValue)
        coder.encode(lineToLine as NSNumber,
                     forKey: Key.lineToLine.rawValue)
        coder.encode(lockToBottom as NSNumber,
                     forKey: Key.lockToBottom.rawValue)
        coder.encode(lockToRight as NSNumber,
                     forKey: Key.lockToRight.rawValue)
        
        coder.encode(liveRender as NSNumber,
                     forKey: Key.liveRender.rawValue)
        
        coder.encode(renderError as NSNumber,
                     forKey: Key.renderError.rawValue)
        coder.encode(errorColorString as NSString,
                     forKey: Key.errorColorString.rawValue)
        
        coder.encode(minLineThicknessEnabled as NSNumber,
                     forKey: Key.minLineThicknessEnabled.rawValue)
        coder.encode(minLineThickness as NSNumber,
                     forKey: Key.minLineThickness.rawValue)
        
        coder.encode(leftJustifyTags as NSNumber,
                     forKey: Key.leftJustifyTags.rawValue)
        
        coder.encode(sizeLimitEnabled as NSNumber,
                     forKey: Key.sizeLimitEnabled.rawValue)
        coder.encode(sizeLimit as NSNumber,
                     forKey: Key.sizeLimit.rawValue)
        
        coder.encode(maxExpansionEnabled as NSNumber,
                     forKey: Key.maxExpansionEnabled.rawValue)
        coder.encode(maxExpansion as NSNumber,
                     forKey: Key.maxExpansion.rawValue)
        
        coder.encode(trustAllCommands as NSNumber,
                     forKey: Key.trustAllCommands.rawValue)
        coder.encode(trustedCommands.arrayObject,
                     forKey: Key.trustedCommands.rawValue)
    }
    
    required init?(coder: NSCoder) {
        super.init()
        decode(from: coder)
    }
    
    func decode(from coder: NSCoder) {
        cursorPosition = coder
            .decodeInteger(for: Key.cursorPosition.rawValue, 0)
        
        renderMode = coder
            .decodeInteger(for: Key.renderMode.rawValue, 0)
        
        displayMode = coder
            .decodeBool(for: Key.displayMode.rawValue, false)
        displayStyle = coder
            .decodeBool(for: Key.displayStyle.rawValue, false)
        
        lineToLine = coder
            .decodeBool(for: Key.lineToLine.rawValue, false)
        
        lockToBottom = coder
            .decodeBool(for: Key.lockToBottom.rawValue, false)
        lockToRight = coder
            .decodeBool(for: Key.lockToRight.rawValue, false)
        
        liveRender = coder
            .decodeBool(for: Key.liveRender.rawValue, true)
        
        renderError = coder
            .decodeBool(for: Key.renderError.rawValue, true)
        errorColorString = coder
            .decodeString(for: Key.errorColorString.rawValue, "CC0000")
        
        minLineThicknessEnabled = coder
            .decodeBool(for: Key.minLineThicknessEnabled.rawValue, false)
        minLineThickness = coder
            .decodeDouble(for: Key.minLineThickness.rawValue, 0.04)
        
        leftJustifyTags = coder
            .decodeBool(for: Key.leftJustifyTags.rawValue, false)
        
        sizeLimitEnabled = coder
            .decodeBool(for: Key.sizeLimitEnabled.rawValue, false)
        sizeLimit = coder
            .decodeDouble(for: Key.sizeLimit.rawValue, 500.0)
        
        maxExpansionEnabled = coder
            .decodeBool(for: Key.maxExpansionEnabled.rawValue, false)
        maxExpansion = coder
            .decodeDouble(for: Key.maxExpansion.rawValue, 1000.0)
        
        trustAllCommands = coder
            .decodeBool(for: Key.trustAllCommands.rawValue, false)
        
        if let commandsArray = coder.decodeObject(
            of: [NSArray.self, NSNumber.self],
            forKey: "trustedCommands"
        ) as? NSArray {
            if let array = Array(commandsArray) as? [NSNumber],
               array.count == trustedCommands.count {
                for index in 0..<trustedCommands.count {
                    trustedCommands[index].trusted = array[index].boolValue ?? false
                }
            }
        }
    }
    
    // MARK: - Copying
    
    func copy() -> Configuration {
        return self.copy(with: nil) as! Configuration
    }
    
    /**
     Creates a new copy of the receiver configuration object.
     
     This method is used whenever a discardable configuration object is needed for user-initiated modification.
     */
    func copy(with zone: NSZone? = nil) -> Any {
        let config = Configuration()
        config.cursorPosition = cursorPosition
        
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
     Inherited from `NSObject` - Defines the rules by which the configuration object is compared.
     
     This method is primarily used to determine whether there exists a change in the configuration by comparing the document's configuration object with its temporary potentially-modified copy.
     */
    override func isEqual(to object: Any?) -> Bool {
        guard let obj = object as? Configuration else {
            return false
        }
        let gates = [cursorPosition == obj.cursorPosition,
                     renderMode == obj.renderMode,
                     displayMode == obj.displayMode,
                     displayStyle == obj.displayStyle,
                     lineToLine == obj.lineToLine,
                     lockToBottom == obj.lockToBottom,
                     lockToRight == obj.lockToRight,
                     liveRender == obj.liveRender,
                     renderError == obj.renderError,
                     errorColorString == obj.errorColorString,
                     errorColor == obj.errorColor,
                     minLineThicknessEnabled == obj.minLineThicknessEnabled,
                     minLineThickness == obj.minLineThickness,
                     leftJustifyTags == obj.leftJustifyTags,
                     sizeLimitEnabled == obj.sizeLimitEnabled,
                     sizeLimit == obj.sizeLimit,
                     maxExpansionEnabled == obj.maxExpansionEnabled,
                     maxExpansion == obj.maxExpansion,
                     trustAllCommands == obj.trustAllCommands,
                     trustedCommands.map { $0.trusted } == obj.trustedCommands.map { $0.trusted }
        ]
        return gates.all
    }
    
    var loopLock: BinaryState = .off
    
}

extension Configuration: Reflective {
    
    var screens: [String] {
        ["loopLock", "cursorPosition", "sizeLimitFormatter", "maxExpansionFormatter"]
    }
    
}

extension NSCoder {
    
    func decodeString(for key: String, _ default: String) -> String {
        return decodeObject(of: NSString.self, forKey: key)?.string ?? `default`
    }
    
    func decodeBool(for key: String, _ default: Bool) -> Bool {
        return decodeObject(of: NSNumber.self, forKey: key)?.boolValue ?? `default`
    }
    
    func decodeInteger(for key: String, _ default: Int) -> Int {
        return decodeObject(of: NSNumber.self, forKey: key)?.intValue ?? `default`
    }
    
    func decodeDouble(for key: String, _ default: Double) -> Double {
        return decodeObject(of: NSNumber.self, forKey: key)?.doubleValue ?? `default`
    }
    
}
