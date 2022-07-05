//
//  KatexMathView.swift
//
//  Created by rajeswari on 5/7/19.
//  Copyright © 2019 Rajeswari Ratala. All rights reserved.
//

import Cocoa
import WebKit
import JavaScriptCore

class KatexMathView: WKWebView {
    
    var document = ScratchPad()
    
    var lineMap: [Range<Int>] = []
    var rangeMap: OrderedDictionary<NSRange, String> = [:]
    
    override var acceptsFirstResponder: Bool {
        return false
    }
    
    func initializeView() {
        let path = Bundle.main.path(forResource: "katex/index", ofType: "html")!
                
        self.configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        
        let templateHTMLString = try! String(contentsOfFile: path, encoding: .utf8)
        
        self.loadHTMLString(templateHTMLString, baseURL: URL(fileURLWithPath: path))
    }
    
    func preprocess(_ katexString: String, options: RenderConfig) -> String {
        let delimiter = "$"
        let startLineTag = #"<div class="line">"#
        let endLineTag = "</div><br>"
        let startTexTag = #"<span class="tex">"#
        let endTexTag = "</span>"
        
        let displayStylePrefix = options.displayStyle ? #"\displaystyle "# : ""
        
        var formattedKatex = ""
        self.lineMap = []
        self.rangeMap = [:]
        
        if options.renderMode == 0 {
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
                self.lineMap.append(lineRange)
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
            
            if options.displayStyle {
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
                self.lineMap.append(lineRange)
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
    
    func render(_ katexString: String, options: RenderConfig) {
        let preprocessed = self.preprocess(katexString, options: options)
        
        let script = """
document.getElementById('output').innerHTML = String.raw`\(preprocessed)`;
renderText(\(options.displayMode));
"""
        
        self.evaluateJavaScript(script) { _, _ in
            var appendixScript = ""
            if !options.lineCorrespondence && options.lockToBottom {
                appendixScript = "scrollLineToVisible(\(self.lineMap.endIndex - 1), \(options.lockToRight));"
            } else if options.lockToRight {
                appendixScript = "scrollToRight();"
            }
            self.evaluateJavaScript(appendixScript)
            
            let sidebar = self.document.sidebar
            
            // fetch errors
            self.evaluateJavaScript("errorMessages") { output, _ in
                sidebar!.handleError(output)
            }
        }
        
    }
    
    
}

