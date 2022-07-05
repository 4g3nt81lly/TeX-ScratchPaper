//
//  NavigatorVC.swift
//  ScratchPaper
//
//  Created by Bingyi Billy Li on 2021/6/12.
//

import Cocoa

class NavigatorVC: NSViewController {
    
    var navigationVCs: [String : NSViewController] = [:]
    
    @IBOutlet weak var navigatorView: NSView!
    
    var editorVC: EditorVC {
        return (self.view.window!.contentViewController as! NSSplitViewController).splitViewItems[1].viewController as! EditorVC
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        for name in ["outline", "error", "configuration"] {
            self.navigationVCs[name] = mainStoryboard.instantiateController(withIdentifier: "\(name)Navigator") as? NSViewController
        }
        self.navigate(to: "outline")
    }
    
    @IBAction func navigate(_ sender: NSButton) {
        let navigatorName = sender.identifier!.rawValue
        
        sender.state = .on
        for view in self.view.subviews {
            guard let button = view as? NSButton, button.identifier!.rawValue != navigatorName else {
                continue
            }
            button.state = .off
        }
        
        self.navigate(to: navigatorName)
    }
    
    func navigate(to name: String) {
        for view in self.view.subviews {
            guard let button = view as? NSButton else {
                continue
            }
            if button.identifier!.rawValue == name {
                button.state = .on
            } else {
                button.state = .off
            }
        }
        
        let navigator = self.navigationVCs[name]!.view
        self.navigatorView.subviews = []
        self.navigatorView.addSubview(navigator)
        navigator.setFrameSize(.init(width: self.navigatorView.frame.width, height: self.navigatorView.frame.height))
        
        let topConstraint = NSLayoutConstraint(item: navigator, attribute: .top, relatedBy: .equal, toItem: self.navigatorView, attribute: .top, multiplier: 1, constant: 0)
        let bottomConstraint = NSLayoutConstraint(item: navigator, attribute: .bottom, relatedBy: .equal, toItem: self.navigatorView, attribute: .bottom, multiplier: 1, constant: 0)
        let leadingConstraint = NSLayoutConstraint(item: navigator, attribute: .leading, relatedBy: .equal, toItem: self.navigatorView, attribute: .leading, multiplier: 1, constant: 0)
        let trailingConstraint = NSLayoutConstraint(item: navigator, attribute: .trailing, relatedBy: .equal, toItem: self.navigatorView, attribute: .trailing, multiplier: 1, constant: 0)
        
        self.navigatorView.addConstraints([topConstraint, bottomConstraint, leadingConstraint, trailingConstraint])
    }
    
    func handleError(messageContent content: Any?) {
        if let content = content as? [String : [String : String]] {
            var entries: [ErrorEntry] = []
            
            for (line, errors) in content {
                for (group, message) in errors {
                    entries.append(ErrorEntry(line: line, group: group, message: message))
                }
            }
            defer {
                // navigate to error pane and set error entries
                let vc = self.navigationVCs["error"] as! ErrorPaneVC
                vc.entries = entries
            }
            guard !entries.isEmpty else {
                return
            }
            entries.sort(by: { $0.lineNumber == $1.lineNumber ? ($0.groupNumber < $1.groupNumber) : ($0.lineNumber < $1.lineNumber) })
            
            /*
            
            let editorVC = self.editorVC
            let contentObject = editorVC.representedObject as! Content
            
            // reset ranges to be highlighted
            editorVC.inputTextView.highlightRanges = []
            
            for error in entries {
                // get line range
                var range = editorVC.katexView.rangeMap.keys[error.lineNumber]
//                let string = editorVC.katexView.rangeMap[range]!
                
                range.length += 1
                editorVC.inputTextView.highlightRanges.append(range)
            }
            
            // redraw text view to highlight the error ranges
            editorVC.inputTextView.needsDisplay = true
            
            */
            
            self.navigate(to: "error")
        }
    }
    
}
