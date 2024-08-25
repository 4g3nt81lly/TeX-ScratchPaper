import Cocoa

class ContentRenderer {
    
    static let texDelimiter = "$"
    
    private static let startLineTag = #"<div class="line">"#
    private static let endLineTag = "</div>"
    private static let startTexTag = #"<span class="tex">"#
    private static let endTexTag = "</span>"
    
    /**
     Preprocesses the file content from a parsed outline for rendering.
     
     Given a parsed outline object, this method preprocesses the file content and generates a
     renderable HTML string for injection.
     
     - Parameter outline: The outline object for parsing.
     */
    private func preprocess(_ text: String, to processedString: NSMutableString,
                            with outline: Structure, using configuration: Configuration) {
        let lines = text.components(separatedBy: "\n")
        
        let displayStylePrefix = configuration.displayStyle ? #"\displaystyle "# : ""
        
        if (configuration.renderMode == 0) {
            // Markdown mode
            for entry in outline {
                let text = lines[entry.lineRange].joined(separator: "\n")
                processedString.append(Self.startLineTag + text + Self.endLineTag)
            }
            
            var left = true
            var texStartLocation = 0
            while let texDelimiterRange = Patterns.texDelimiter
                .firstMatch(in: processedString.string, range: processedString.range)?.range {
                
                let tagString = left ? Self.startTexTag + displayStylePrefix : Self.endTexTag
                processedString.replaceCharacters(in: texDelimiterRange, with: tagString)
                // proceed to remove all placeholder templates, replacing them with the placeholder string
                if (left) {
                    // left tag: set content start location
                    texStartLocation = texDelimiterRange.location + tagString.nsString.length
                } else {
                    // right tag: get tex content range and process content within
                    let texEndLocation = texDelimiterRange.location
                    let texContentRange = NSMakeRange(texStartLocation, texEndLocation - texStartLocation)
                    
                    // convert special characters &, <, > to character reference for TeX tags
                    //   this is required for setting innerHTML to work properly
                    //   (e.g. < and > won't be recognized as part of an HTML tag)
                    processedString.replaceOccurrences(of: "&", with: "&amp;", range: texContentRange)
                    processedString.replaceOccurrences(of: "<", with: "&lt;", range: texContentRange)
                    processedString.replaceOccurrences(of: ">", with: "&gt;", range: texContentRange)
                }
                left.toggle()
            }
            // replace all non-escaped backtick characters to a JavaScript string interpolation segment
            // this ensures that backtick characters (if any) won't be parsed as an early closer of the JavaScript
            //   multi-line string syntax (i.e. String.raw`...`)
            Patterns.backticks.replaceMatches(in: processedString, range: processedString.range,
                                              withTemplate: #"${"`"}"#)
        } else {
            // math mode
            // TODO: redesign math mode rendering to render only math blocks in content
            for entry in outline {
                let texString = lines[entry.lineRange].joined(separator: "\n")
                processedString.append(Self.startLineTag + Self.startTexTag
                                       + displayStylePrefix + texString
                                       + Self.endTexTag + Self.endLineTag)
            }
        }
    }
    
    /**
     Renders the preprocessed text.
     
     Rendering is done by evaluating a JavaScript script that injects the preprocessed renderable HTML string into the loaded
     HTML template with desired configurations. This method also executes follow-up JavaScript scripts for features such as
     "lock to bottom" and "lock to right" to always scroll the content to the bottom/right of the page.
     
     - Parameter outputView: The output view to be rendered in.
     */
    func render(text: String, with outline: Structure, in outputView: OutputView, using config: Configuration,
                onError handleError: @escaping (Any?) -> Void) {
        let processedString: NSMutableString = ""
        
        preprocess(text, to: processedString, with: outline, using: config)
        
        var trustArg = "true"
        if (!config.trustAllCommands) {
            let trustedCommands = config.trustedCommands.filter { $0.trusted }
            if (!trustedCommands.isEmpty) {
                let commands = trustedCommands.map { command in
                    return "'\(command.name.replacingOccurrences(of: #"\"#, with: #"\\"#))'"
                }
                trustArg = "(context) => [\(commands.joined(separator: ", "))].includes(context.command)"
            } else {
                trustArg = "false"
            }
        }
        
        let script = "outputContainer.innerHTML = String.raw`\(processedString)`;\nrenderText("
            + "\(config.displayMode), "
            + "\(config.renderError), "
            + "'#\(config.errorColorString)', "
            + "\(config.minLineThicknessEnabled ? config.minLineThickness : -1), "
            + "\(config.leftJustifyTags), "
            + "\(config.sizeLimitEnabled ? String(config.sizeLimit) : "Infinity"), "
            + "\(config.maxExpansionEnabled ? config.maxExpansion : 1000), "
            + "\(trustArg)"
            + ");"
        
        outputView.evaluateJavaScript(script) { _, error in
            var appendixScript = ""
            
            if (!config.lineToLine && config.lockToBottom) {
                appendixScript = "scrollToBottom(\(config.lockToRight));"
            } else if (config.lockToRight) {
                appendixScript = "scrollToRight();"
            }
            outputView.evaluateJavaScript(appendixScript)
            
            // fetch errors
            outputView.evaluateJavaScript("errorMessages") { output, _ in
                handleError(output)
            }
        }
    }
    
}
