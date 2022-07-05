//
//  Editor.swift
//  TeX-ScratchPad
//
//  Created by Bingyi Billy Li on 2021/3/3.
//

import Cocoa
import WebKit

@objcMembers
class Editor: NSViewController {
    
    @IBOutlet weak var contentTextView: TextView!
    
    @IBOutlet weak var katexView: KatexMathView!
    
    dynamic var document = ScratchPad()
    
    var sidebar: Sidebar {
        return self.document.sidebar
    }
    
    var previousCorrespondenceLine = 0
    var isKatexViewInitialized = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.contentTextView.font = .monospacedSystemFont(ofSize: 14.0, weight: .regular)
        self.contentTextView.isAutomaticTextCompletionEnabled = false
        self.contentTextView.isAutomaticTextReplacementEnabled = false
        self.contentTextView.isAutomaticQuoteSubstitutionEnabled = false
        self.contentTextView.isAutomaticDashSubstitutionEnabled = false
        self.contentTextView.isAutomaticLinkDetectionEnabled = false
        
        self.contentTextView.setUpLineNumberView()
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        if let items = self.view.window?.toolbar?.visibleItems {
            for item in items {
                if item.itemIdentifier.rawValue == "displayMode" {
                    (item.view as! NSButton).bind(.value, to: self, withKeyPath: "self.document.content.displayMode", options: [.raisesForNotApplicableKeys : true])
                } else if item.itemIdentifier.rawValue == "renderMode" {
                    (item.view as! NSSegmentedControl).bind(.selectedIndex, to: self, withKeyPath: "self.document.content.renderMode", options: [.raisesForNotApplicableKeys : true])
                }
            }
        }
        self.katexView.document = self.document
        
        if !self.isKatexViewInitialized {
            self.katexView.initializeView()
            self.isKatexViewInitialized = true
        }
        self.view.window?.makeFirstResponder(self.contentTextView)
    }
    
    @IBAction func applyConfig(_ sender: Any) {
        self.renderText()
    }
    
    func renderText(registerChange: Bool = true) {
        let text = self.document.content.contentString
        
        if registerChange {
            self.document.updateChangeCount(.changeDone)
        }
        
        self.katexView.render(text, options: RenderConfig(self))
        
        self.loadOutlineEntries()
    }
    
    func loadOutlineEntries() {
        let outlinePane = self.sidebar.panes["outline"] as! OutlinePane
        var entries: [OutlineEntry] = []
        for (index, (range, string)) in self.katexView.rangeMap.enumerated() {
            var content = string.trimmingCharacters(in: ["\n", " "])
            if content == "" {
                content = "(EMPTY LINE)"
            }
            let outlineEntry = OutlineEntry(text: content, lineRange: self.katexView.lineMap[index], selectableRange: range)
            entries.append(outlineEntry)
        }
        outlinePane.entries = entries
    }
    
    func indicate(_ range: NSRange, index: Int) {
        self.contentTextView.scrollRangeToCenter(range, animated: true) {
            self.contentTextView.showFindIndicator(for: range)
        }
        self.katexView.evaluateJavaScript("indicate(\(index));")
    }
    
}

extension Editor: TextViewDelegate, WKNavigationDelegate {
    
    func textDidChange(_ notification: Notification) {
        if self.contentTextView.string.last != "\n" {
            let previousRange = self.contentTextView.selectedRange()
            self.contentTextView.string += "\n"
            self.contentTextView.setSelectedRange(previousRange)
        }
        self.renderText()
    }
    
    // when text view is clicked or typed
    func textView(_ textView: TextView, didClick selectedRange: NSRange) {
        var correspondingRange: NSRange?
        for (index, (range, _)) in self.katexView.rangeMap.enumerated() {
            if range.contains(selectedRange.location) || selectedRange.location == range.upperBound {
                // if it's within the line range
                correspondingRange = range
                // print("\(selectedRange) is in line range \(range)")
            } else if selectedRange.location > range.upperBound {
                // else if it's beyond the line range
                // move on to the next line
                // print("\(selectedRange) is beyond the range \(range), move on to next line range: \(self.katexView.rangeMap.keys[index + 1])")
                continue
            } else if selectedRange.location < range.location {
                // else if not in the next line range
                // set to corresponding range to the previous
                correspondingRange = self.katexView.rangeMap.keys[index - 1]
                // print("\(selectedRange) does not reach the range \(range), take the previous range \(correspondingRange)")
            }
            // print("break using range \(correspondingRange)")
            break
        }
        guard let range = correspondingRange,
              let index = self.katexView.rangeMap.keys.firstIndex(of: range) else {
            return
        }
        // select row without highlighting
        let outlinePane = self.sidebar.panes["outline"] as! OutlinePane
        outlinePane.bypassIndicateOnSelectionChange = true
        outlinePane.outlineTableView.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
        outlinePane.outlineTableView.scrollRowToVisible(index)
        
        let contentObject = self.document.content
        
        contentObject.cursorPosition = selectedRange.location
        NSDocumentController.shared.currentDocument!.updateChangeCount(.changeDone)
        
        guard contentObject.lineCorrespondence else {
            return
        }
        self.katexView.evaluateJavaScript(index == self.previousCorrespondenceLine ? "scrollLineToVisible(\(index));" : "indicate(\(index));")
        self.previousCorrespondenceLine = index
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        let contentObject = self.document.content
        
        let cursorRange = NSRange(location: contentObject.cursorPosition, length: 0)
        self.contentTextView.setSelectedRange(cursorRange)
        
        (self.contentTextView.delegate as? TextViewDelegate)?.textView(self.contentTextView, didClick: cursorRange)
        
        self.renderText(registerChange: false)
        
        webView.evaluateJavaScript("document.readyState", completionHandler: { (complete, _) in
            if complete != nil {
                webView.evaluateJavaScript("document.body.scrollHeight", completionHandler: { (height, _) in
                    webView.frame.size.height = height as! CGFloat
                    webView.layoutSubtreeIfNeeded()
                })
            }
        })
    }
    
}
