import Cocoa
import WebKit

final class TeX2SVGRenderer: NSObject, WKNavigationDelegate {
    
    static let shared = TeX2SVGRenderer()
    
    private let webview: WKWebView

    private let semaphore: DispatchSemaphore
    
    private override init() {
        self.webview = WKWebView()
        let page = Bundle.main.path(forResource: "tex-svg/tex-svg", ofType: "html")!
        let htmlString = try! String(contentsOfFile: page)
        self.semaphore = DispatchSemaphore(value: 0)
        super.init()
        self.webview.navigationDelegate = self
        self.webview.loadHTMLString(htmlString, baseURL: URL(fileURLWithPath: page))
    }
    
    func render(_ texString: String, _ handler: @escaping (String) -> ()) {
        DispatchQueue(label: "texSVGRenderer", qos: .default).async {
            self.semaphore.wait()
            let script = "texContainer.innerHTML = String.raw`$$\(texString)$$`;\n"
                        + "MathJax.typeset();\n"
                        + "texContainer.querySelector('mjx-container.MathJax > svg').outerHTML;"
            DispatchQueue.main.sync {
                self.webview.evaluateJavaScript(script) { value, error in
                    if let value = value as? String {
                        handler(value)
                    }
                    if let error = error as? WKError {
                        print(error)
                    }
                    self.semaphore.signal()
                }
            }
        }
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        webView.evaluateJavaScript("document.readyState") { (complete, _) in
            if complete != nil {
                self.semaphore.signal()
            }
        }
    }
    
}
