//
//  KatexMathView.swift
//
//  Created by rajeswari on 5/7/19.
//  Copyright © 2019 Rajeswari Ratala. All rights reserved.
//

import Cocoa
import WebKit
import JavaScriptCore

/**
 A custom subclass of `WKWebView`.
 
 1. Creates and manages line and range mappings between the editor content and the rendered content.
 2. Preprocesses and renders the content.
 3. Configures the web view.
 4. Supports dark mode.
 */
class KatexMathView: WKWebView {
    
    /**
     Reference to the associated document object.
     
     Implicitly unwrapped optional is used rather than creating a dummy document object to avoid redundant calls.
     
     - Note: This is set by its superview `Editor` as it initializes the KaTeX view from `viewDidAppear()`.
     */
    var document: ScratchPaper!
    
    /**
     An array keeping track of the line ranges.
     
     Each line range is an open range with its lower bound being the beginning line number of a section (sections are separated by two line breaks `\n\n`) and its upper bound being the ending line number.
     */
    var lineRanges: [Range<Int>] = []
    
    /**
     A mapping between the sections' selectable ranges and their corresponding content as an ordered dictionary.
     
     The keys should be unique selectable ranges.
     */
    var rangeMap: OrderedDictionary<NSRange, String> = [:]
    
    override var acceptsFirstResponder: Bool {
        return false
    }
    
    /// A boolean value indicating whether the system is in dark mode.
    var isDarkMode: Bool {
        return self.effectiveAppearance.name == .darkAqua
    }
    
    /**
     Initializes the web view with the HTML template from the bundle and configures it.
     
     This method is invoked by `Editor` to initialize the KaTeX view from `viewDidAppear()` if not already initialized, which should never be invoked twice. After the web view has been initialized and loaded, the delegate method `webView(_:didFinish:)` will be called to finalize the initialization process.
     */
    func initializeView() {
        let path = Bundle.main.path(forResource: "katex/index", ofType: "html")!
        
        var templateHTMLString = try! String(contentsOfFile: path, encoding: .utf8)
        
        // initialize with an appearance that matches the system appearance
        templateHTMLString = templateHTMLString.replacingOccurrences(of: "STYLE", with: "\(self.isDarkMode ? "background-color: rgb(32, 32, 32); color: rgb(255, 255, 255);" : "")")
        
        self.loadHTMLString(templateHTMLString, baseURL: URL(fileURLWithPath: path))
    }
    
    /**
     Preprocesses the KaTeX string for rendering.
     
     This method preprocesses the KaTeX string and generates a renderable HTML string for injection. It also creates the mappings for line ranges and selectable ranges.
     
     - Returns: A renderable HTML string, which is discardable when the caller only wants to create the mappings for line ranges and selectable ranges.
     */
    @discardableResult
    func preprocess() -> String {
        let katexString = self.document.content.contentString
        let config = self.document.content.configuration
        
        let delimiter = "$"
        let startLineTag = #"<div class="line">"#
        let endLineTag = "</div><br>"
        let startTexTag = #"<span class="tex">"#
        let endTexTag = "</span>"
        
        let displayStylePrefix = config.displayStyle ? #"\displaystyle "# : ""
        
        var formattedKatex = ""
        self.lineRanges = []
        self.rangeMap = [:]
        
        if config.renderMode == 0 {
            // text-based mode
            var firstLine = 0
            var searchRange = NSRange(location: 0, length: (katexString as NSString).length)
            for component in katexString.components(separatedBy: "\n\n") {
                defer {
                    // update search range
                    let step = (component as NSString).length + 2
                    searchRange.location += step
                    searchRange.length -= step
                    
                    formattedKatex += "\(startLineTag)\(component.components(separatedBy: "\n").joined(separator: "<br>"))\(endLineTag)"
                }
                
                // create line mapping
                let lines = component.count("\n") + 1
                let lineRange = firstLine..<firstLine + lines
                self.lineRanges.append(lineRange)
                firstLine += lines + 1
                
                // create selectable range mapping
                guard component != "" else {
                    let range = NSRange(location: searchRange.location, length: 0)
                    self.rangeMap[range] = ""
                    continue
                }
                let range = (katexString as NSString).range(of: component, range: searchRange)
                self.rangeMap[range] = component
            }
            // remove last line break
            var components = formattedKatex.components(separatedBy: "<br>")
            components.removeLast()
            formattedKatex = components.joined(separator: "<br>")
            
            if config.displayStyle {
                var left = true
                while formattedKatex.contains(delimiter) {
                    if let range = formattedKatex.range(of: delimiter) {
                        formattedKatex = formattedKatex.replacingOccurrences(of: delimiter, with: left ? "@\(displayStylePrefix)" : "@", options: .literal, range: range)
                    }
                    left.toggle()
                }
                formattedKatex = formattedKatex.replacingOccurrences(of: "@", with: "$")
            }
        } else {
            // math mode
            var firstLine = 0
            var searchRange = NSRange(location: 0, length: (katexString as NSString).length)
            for component in katexString.components(separatedBy: "\n\n") {
                defer {
                    // update search range
                    let step = (component as NSString).length + 2
                    searchRange.location += step
                    searchRange.length -= step
                    
                    formattedKatex += "\(startLineTag)$\(displayStylePrefix)\(component)$\(endLineTag)"
                }
                
                // create line mapping
                let lines = component.count("\n") + 1
                let lineRange = firstLine..<firstLine + lines
                self.lineRanges.append(lineRange)
                firstLine += lines + 1
                
                // create selectable range mapping
                guard component != "" else {
                    let range = NSRange(location: searchRange.location, length: 0)
                    self.rangeMap[range] = ""
                    continue
                }
                let range = (katexString as NSString).range(of: component, range: searchRange)
                self.rangeMap[range] = component
            }
        }
        
        var first = true
        
        while formattedKatex.contains(delimiter) {
            let tag: String = first ? startTexTag : endTexTag
            if let range = formattedKatex.range(of: delimiter) {
                formattedKatex = formattedKatex.replacingOccurrences(of: delimiter, with: tag, options: .literal, range: range)
            }
            first.toggle()
        }
        
        return formattedKatex
    }
    
    /**
     Renders the preprocessed KaTeX string.
     
     This method invokes `preprocess()` to preprocess the text for rendering if not already preprocessed. Rendering is done by evaluating a JavaScript scripts that injects the preprocessed renderable HTML string into the loaded HTML template with desired configurations. This method also executes follow-up JavaScript scripts for features such as "lock to bottom" and "lock to right" to always scroll the content to the bottom/right of the page.
     
     - Parameter preprocessed: A preprocessed renderable HTML string. If this is specified, the method no longer makes attempt to preprocess the text prior to the injection.
     */
    func render(preprocessed: String? = nil) {
        let config = self.document.content.configuration
        let htmlText = preprocessed ?? self.preprocess()
        
        var trustArg = "true"
        if !config.trustAllCommands {
            let trustedCommands = config.trustedCommands.filter({ $0.trusted })
            if trustedCommands.count > 0 {
                let commands = trustedCommands.map({ "'\($0.name.replacingOccurrences(of: "\\", with: "\\\\"))'" })
                trustArg = "(context) => [\(commands.joined(separator: ", "))].includes(context.command)"
            } else {
                trustArg = "false"
            }
        }
        
        let script = """
document.getElementById('output').innerHTML = String.raw`\(htmlText)`;
renderText(\(config.displayMode), \(config.renderError), '#\(config.errorColorString)', \(config.minLineThicknessEnabled ? config.minLineThickness : -1), \(config.leftJustifyTags), \(config.sizeLimitEnabled ? String(config.sizeLimit) : "Infinity"), \(config.maxExpansionEnabled ? config.maxExpansion : 1000), \(trustArg));
"""
        
        self.evaluateJavaScript(script) { _, error in
            var appendixScript = ""
            
            if !config.lineToLine && config.lockToBottom {
                appendixScript = "scrollLineToVisible(\(self.lineRanges.endIndex - 1), \(config.lockToRight));"
            } else if config.lockToRight {
                appendixScript = "scrollToRight();"
            }
            self.evaluateJavaScript(appendixScript)
            
            let sidebar = self.document.sidebar
            
            // fetch errors
            self.evaluateJavaScript("errorMessages") { output, _ in
                sidebar!.showError(output)
            }
        }
        
    }
    
    /// Method overriden to disable reload action in the web view's contextual menu.
    override func willOpenMenu(_ menu: NSMenu, with event: NSEvent) {
        if let reloadItem = menu.item(withTitle: "Reload") {
            menu.removeItem(reloadItem)
        }
    }
    
    /// Evaluates JavaScript script to change appearance accordingly when the system appearance changes.
    override func viewDidChangeEffectiveAppearance() {
        self.evaluateJavaScript("changeAppearance(\(self.isDarkMode));")
    }
    
}

