//
//  KatexMathView.swift
//
//  Created by rajeswari on 5/7/19.
//  Copyright © 2019 Rajeswari Ratala. All rights reserved.
//

import Cocoa
import WebKit
import JavaScriptCore

struct RenderConfiguration {
    var renderMode = 0
    var displayMode = false
    var displayStyle = false
    var lineCorrespondence = false
    var lockToRight = false
    var lockToBottom = false
    
    init(_ editor: EditorVC) {
        let contentObject = editor.representedObject as! Content
        self.renderMode = contentObject.renderMode
        self.displayMode = contentObject.displayMode
        self.displayStyle = contentObject.displayStyle
        self.lineCorrespondence = contentObject.lineCorrespondence
        self.lockToRight = contentObject.lockToRight
        self.lockToBottom = contentObject.lockToBottom
    }
}

class KatexMathView: WKWebView {
    
    var lineMap: [Range<Int>] = []
    var rangeMap: OrderedDictionary<NSRange, String> = [:]
//    var rangeMap: [NSRange] = []
    var mathMap: [NSRange] = []
    
    override var acceptsFirstResponder: Bool {
        return false
    }
    
    func initializeView() {
        let path = Bundle.main.path(forResource: "katex/index", ofType: "html")!
                
        self.configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        
        let templateHTMLString = try! String(contentsOfFile: path, encoding: .utf8)
        
        self.loadHTMLString(templateHTMLString, baseURL: URL(fileURLWithPath: path))
    }
    
    func preprocess(_ katexString: String, options: RenderConfiguration) -> String {
        let delimiter = "$"
        let startLineTag = #"<div class="line">"#
        let endLineTag = "</div><br>"
        let startTexTag = #"<span class="tex">"#
        let endTexTag = "</span>"
        
        let displayStylePrefix = options.displayStyle ? #"\displaystyle "# : ""
        
        var formattedKatex = ""
        self.lineMap = []
        self.rangeMap = [:]
        self.mathMap = []
        
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
                var range = (katexString as NSString).range(of: component, range: searchRange)
                self.rangeMap[range] = component
                
                // create math range mapping
                for (index, group) in component.components(separatedBy: "$").enumerated() {
                    if index % 2 == 1 {
                        // math mode
                        guard group != "" else {
                            continue
                        }
                        let mathRange = (katexString as NSString).range(of: "$\(group)$", range: range)
                        self.mathMap.append(mathRange)
                    } else {
                        // if not math mode, add range by length
                        let length = (group as NSString).length
                        range.location += length
                        range.length -= length
                    }
                }
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
                var range = (katexString as NSString).range(of: component, range: searchRange)
                self.rangeMap[range] = component
                
                // create plain-text range mapping
                for (index, group) in component.components(separatedBy: "$").enumerated() {
                    if index % 2 == 1 {
                        // math mode
                        guard group != "" else {
                            continue
                        }
                        let plainTextRange = (katexString as NSString).range(of: "$\(group)$", range: range)
                        self.mathMap.append(plainTextRange)
                    } else {
                        // if not math mode, add range by length
                        let length = (group as NSString).length
                        range.location += length
                        range.length -= length
                    }
                }
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
    
    func render(_ katexString: String, options: RenderConfiguration) {
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
            
            let navigatorVC = (self.window!.contentViewController as! NSSplitViewController).splitViewItems[0].viewController as! NavigatorVC
            
            // fetch errors
            self.evaluateJavaScript("errorMessages") { output, _ in
                navigatorVC.handleError(messageContent: output)
            }
        }
        
    }
    
    
}

