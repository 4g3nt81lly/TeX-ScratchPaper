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
class OutputView: WKWebView, EditorControllable {
    
    private var renderer: TeXRenderer = TeXRenderer()
    
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
    func initializeView() {
        let path = Bundle.main.path(forResource: "renderer/index", ofType: "html")!
        
        var templateHTMLString = try! String(contentsOfFile: path, encoding: .utf8)
        
        // initialize with an appearance that matches the system appearance
        templateHTMLString = templateHTMLString
            .replacingOccurrences(of: "STYLE",
                                  with: "\(self.isDarkMode ? "background-color: rgb(32, 32, 32); color: rgb(255, 255, 255);" : "")")
        
        self.loadHTMLString(templateHTMLString, baseURL: URL(fileURLWithPath: path))
        
        // initialize renderer
        self.renderer.initialize(self.document)
    }
    
    func preprocess(with outline: Outline) {
        self.renderer.preprocess(with: outline)
    }
    
    func render() {
        self.renderer.render(in: self)
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

