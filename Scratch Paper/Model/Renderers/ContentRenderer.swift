import Cocoa

class ContentRenderer {
    
    static let texDelimiter = "$"
    
    private static let startLineTag = #"<div class="line">"#
    private static let endLineTag = "</div>"
    private static let startTexTag = #"<span class="tex">"#
    private static let endTexTag = "</span>"
    
    private unowned var document: Document!
    
    private var processedString: String = ""
    
    func initialize(with document: Document) {
        self.document = document
    }
    
    /**
     Preprocesses the file content from a parsed outline for rendering.
     
     Given a parsed outline object, this method preprocesses the file content and generates a
     renderable HTML string for injection.
     
     - Parameter outline: The outline object for parsing.
     */
    func preprocess(with outline: Structure) {
        let string = document.content.contentString
        let lines = string.components(separatedBy: "\n")
        
        let config = document.content.configuration
        
        let displayStylePrefix = config.displayStyle ? #"\displaystyle "# : ""
        
        let processedString: NSMutableString = ""
        
        if (config.renderMode == 0) {
            // Markdown mode
            for entry in outline {
                let text = lines[entry.lineRange].joined(separator: "\n")
                processedString.append(Self.startLineTag + text + Self.endLineTag)
            }
            Patterns.textPlaceholder
                .replaceMatches(in: processedString, range: processedString.range, withTemplate: "$1")
            
            var left = true
            var texStartLocation = 0
            while let texDelimiterRange = Patterns.texDelimiter
                .matches(in: processedString.string, range: processedString.range).first?.range(at: 1) {
                
                let tagString = left ? Self.startTexTag + displayStylePrefix : Self.endTexTag
                processedString.replaceCharacters(in: texDelimiterRange, with: tagString)
                // proceed to remove all placeholder templates, replacing them with the placeholder string
                if (left) {
                    // left tag: set content start location
                    texStartLocation = texDelimiterRange.location + tagString.nsString.length
                } else {
                    // right tag: get tex content range and process content within
                    let texEndLocation = texDelimiterRange.location
                    let texContentRange = NSRange(location: texStartLocation,
                                                  length: texEndLocation - texStartLocation)
                    Patterns.textPlaceholder.replaceMatches(in: processedString,
                                                            range: texContentRange, withTemplate: "$1")
                    processedString.replaceOccurrences(of: "&", with: "&amp;", range: texContentRange)
                    processedString.replaceOccurrences(of: "<", with: "&lt;", range: texContentRange)
                    processedString.replaceOccurrences(of: ">", with: "&gt;", range: texContentRange)
                }
                left.toggle()
            }
            processedString.replaceOccurrences(of: "`", with: "\\`", range: processedString.range)
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
        
        self.processedString = processedString.string
    }
    
    /**
     Renders the preprocessed text.
     
     Rendering is done by evaluating a JavaScript script that injects the preprocessed renderable HTML string into the loaded
     HTML template with desired configurations. This method also executes follow-up JavaScript scripts for features such as
     "lock to bottom" and "lock to right" to always scroll the content to the bottom/right of the page.
     
     - Parameter outputView: The output view to be rendered in.
     */
    func render(in outputView: OutputView) {
        let config = document.content.configuration
        
        var trustArg = "true"
        if (!config.trustAllCommands) {
            let trustedCommands = config.trustedCommands.filter { $0.trusted }
            if (!trustedCommands.isEmpty) {
                let commands = trustedCommands.map { command in
                    return "'\(command.name.replacingOccurrences(of: "\\", with: #"\\"#))'"
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
                self.document.editor.sidebar.showError(output)
            }
        }
    }
    
}
