import Cocoa

class TeXRenderer {
    
    private static let texDelimiter = "$"
    private static let texDelimiterRegex = {
        return try! NSRegularExpression(pattern: #"(?:^|[^\\])(\\#(texDelimiter))"#)
    }()
    private static let startLineTag = #"<div class="line">"#
    private static let endLineTag = "</div>"
    private static let startTexTag = #"<span class="tex">"#
    private static let endTexTag = "</span>"
    
    private weak var document: Document!
    
    private var processedString: String = ""
    
    func initialize(_ document: Document) {
        self.document = document
    }
    
    /**
     Preprocesses the file content from a parsed outline for rendering.
     
     Given a parsed outline object, this method preprocesses the file content and generates a renderable HTML string for injection.
     
     - Parameter outline: The outline object for parsing.
     */
    func preprocess(with outline: Outline) {
        let string = self.document.content.contentString
        let lines = string.components(separatedBy: "\n")
        
        let config = self.document.content.configuration
        
        let displayStylePrefix = config.displayStyle ? #"\displaystyle "# : ""
        
        let processedString: NSMutableString = ""
        
        if config.renderMode == 0 {
            // Markdown mode
            for entry in outline {
                let text = lines[entry.lineRange].joined(separator: "\n")
                processedString.append(TeXRenderer.startLineTag + text + TeXRenderer.endLineTag)
            }
            
            var left = true
            var texStartLocation = 0
            while let texDelimiterRange = TeXRenderer.texDelimiterRegex
                .matches(in: processedString.string, range: processedString.range).first?.range(at: 1) {
                
                let tagString = left ? TeXRenderer.startTexTag + displayStylePrefix : TeXRenderer.endTexTag
                processedString.replaceCharacters(in: texDelimiterRange, with: tagString)
                // proceed to remove all placeholder templates, replacing them with the placeholder string
                if left {
                    // left tag: set content start location
                    texStartLocation = texDelimiterRange.location + tagString.nsString.length
                } else {
                    // right tag: get tex content range and process content within
                    let texEndLocation = texDelimiterRange.location
                    let texContentRange = NSRange(location: texStartLocation,
                                                  length: texEndLocation - texStartLocation)
                    TextPlaceholder.pattern.replaceMatches(in: processedString, range: texContentRange, withTemplate: "$1")
                }
                left.toggle()
            }
            processedString.replaceOccurrences(of: "`", with: "\\`", range: processedString.range)
        } else {
            // math mode
            for entry in outline {
                let texString = lines[entry.lineRange].joined(separator: "\n")
                processedString.append(TeXRenderer.startLineTag + TeXRenderer.startTexTag
                                       + displayStylePrefix + texString
                                       + TeXRenderer.endTexTag + TeXRenderer.endLineTag)
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
        let config = self.document.content.configuration
        
        var trustArg = "true"
        if !config.trustAllCommands {
            let trustedCommands = config.trustedCommands.filter({ $0.trusted })
            if !trustedCommands.isEmpty {
                let commands = trustedCommands.map { command in
                    return "'\(command.name.replacingOccurrences(of: "\\", with: #"\\"#))'"
                }
                trustArg = "(context) => [\(commands.joined(separator: ", "))].includes(context.command)"
            } else {
                trustArg = "false"
            }
        }
        
        let script = "outputContainer.innerHTML = String.raw`\(self.processedString)`;\nrenderText("
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
            
            if !config.lineToLine && config.lockToBottom {
                appendixScript = "scrollToBottom(\(config.lockToRight));"
            } else if config.lockToRight {
                appendixScript = "scrollToRight();"
            }
            outputView.evaluateJavaScript(appendixScript)
            
            let sidebar = self.document.sidebar
            
            // fetch errors
            outputView.evaluateJavaScript("errorMessages") { output, _ in
                sidebar!.showError(output)
            }
        }
    }
    
}
