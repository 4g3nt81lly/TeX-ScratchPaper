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
class OutputView: WKWebView {
    
    private var renderer = ContentRenderer()
    
    override var acceptsFirstResponder: Bool {
        return false
    }
    
    /**
     Initializes (and configures) the output view with the HTML template from the bundle.
     
     This method is invoked by `EditorVC` to initialize the KaTeX view from `viewDidAppear()` if
     not already initialized, which should never be invoked twice. After the web view has been
     initialized and loaded, the delegate method `webView(_:didFinish:)` will be called to finalize
     the initialization process.
     */
    func initialize() {
        let path = Bundle.main.path(forResource: "renderer/index", ofType: "html")!
        
        var templateHTMLString = try! String(contentsOfFile: path, encoding: .utf8)
        
        // initialize with an appearance that matches the system appearance
        let darkModeStyleString = "background-color: rgb(32, 32, 32); color: rgb(255, 255, 255);"
        templateHTMLString = templateHTMLString
            .replacingOccurrences(of: "STYLE",
                                  with: "\(NSApp.isInDarkMode ? darkModeStyleString : "")")
        
        loadHTMLString(templateHTMLString, baseURL: URL(fileURLWithPath: path))
    }
    
    func render(_ text: String, with outline: Structure, using configuration: Configuration,
                onError errorHandler: @escaping (Any?) -> Void) {
        renderer.render(text: text, with: outline, in: self, using: configuration, onError: errorHandler)
    }
    
    /// Method overriden to disable reload action in the web view's contextual menu.
    override func willOpenMenu(_ menu: NSMenu, with event: NSEvent) {
        if let reloadItem = menu.item(withTitle: "Reload") {
            menu.removeItem(reloadItem)
        }
    }
    
    /// Evaluates JavaScript script to change appearance accordingly when the system appearance changes.
    override func viewDidChangeEffectiveAppearance() {
        evaluateJavaScript("changeAppearance(\(NSApp.isInDarkMode));")
    }
    
}

