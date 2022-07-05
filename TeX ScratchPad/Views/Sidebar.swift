//
//  Navigator.swift
//  TeX-ScratchPad
//
//  Created by Bingyi Billy Li on 2021/6/12.
//

import Cocoa

class Sidebar: NSViewController {
    
    var panes: [String : NSViewController] = [:]
    
    @IBOutlet weak var sidebarView: NSView!
    
    var document = ScratchPad() {
        didSet {
            for child in self.children {
                child.representedObject = self.document
            }
        }
    }
    
    var editor: Editor {
        return self.document.editor
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        for name in ["outline", "error", "configuration"] {
            let pane = mainStoryboard.instantiateController(withIdentifier: "\(name)Pane") as! NSViewController
            self.addChild(pane)
            self.panes[name] = pane
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
        
        let pane = self.panes[name]!.view
        self.sidebarView.subviews = []
        self.sidebarView.addSubview(pane)
        pane.setFrameSize(.init(width: self.sidebarView.frame.width, height: self.sidebarView.frame.height))
        
        let topConstraint = NSLayoutConstraint(item: pane, attribute: .top, relatedBy: .equal, toItem: self.sidebarView, attribute: .top, multiplier: 1, constant: 0)
        let bottomConstraint = NSLayoutConstraint(item: pane, attribute: .bottom, relatedBy: .equal, toItem: self.sidebarView, attribute: .bottom, multiplier: 1, constant: 0)
        let leadingConstraint = NSLayoutConstraint(item: pane, attribute: .leading, relatedBy: .equal, toItem: self.sidebarView, attribute: .leading, multiplier: 1, constant: 0)
        let trailingConstraint = NSLayoutConstraint(item: pane, attribute: .trailing, relatedBy: .equal, toItem: self.sidebarView, attribute: .trailing, multiplier: 1, constant: 0)
        
        self.sidebarView.addConstraints([topConstraint, bottomConstraint, leadingConstraint, trailingConstraint])
    }
    
    func handleError(_ messageContent: Any?) {
        if let content = messageContent as? [String : [String : String]] {
            var entries: [ErrorEntry] = []
            
            for (line, errors) in content {
                for (group, message) in errors {
                    entries.append(ErrorEntry(line: line, group: group, message: message))
                }
            }
            defer {
                // navigate to error pane and set error entries
                (self.panes["error"] as! ErrorPane).entries = entries
            }
            guard !entries.isEmpty else {
                return
            }
            entries.sort(by: { $0.lineNumber == $1.lineNumber ? ($0.groupNumber < $1.groupNumber) : ($0.lineNumber < $1.lineNumber) })
            
            self.navigate(to: "error")
        }
    }
    
}
