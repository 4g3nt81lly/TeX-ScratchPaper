//
//  EditorVC.swift
//  ScratchPaper
//
//  Created by Bingyi Billy Li on 2021/3/3.
//

import Cocoa
import WebKit

@objcMembers
class EditorVC: NSViewController {
    
    @IBOutlet weak var inputTextView: TextView!
    
    @IBOutlet weak var katexView: KatexMathView!
    
    var previousCorrespondenceLine = 0
    
    var isKatexViewInitialized = false
    
    var isDarkMode: Bool {
        return [NSAppearance.Name.darkAqua, NSAppearance.Name.vibrantDark].contains(self.view.effectiveAppearance.name)
    }
    
    var navigatorVC: NavigatorVC {
        return (self.view.window!.contentViewController as! NSSplitViewController).splitViewItems[0].viewController as! NavigatorVC
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.inputTextView.font = .monospacedSystemFont(ofSize: 14.0, weight: .regular)
        self.inputTextView.isAutomaticTextCompletionEnabled = false
        self.inputTextView.isAutomaticTextReplacementEnabled = false
        self.inputTextView.isAutomaticQuoteSubstitutionEnabled = false
        self.inputTextView.isAutomaticDashSubstitutionEnabled = false
        self.inputTextView.isAutomaticLinkDetectionEnabled = false
        
        self.inputTextView.setUpLineNumberView()
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        if let items = self.view.window?.toolbar?.visibleItems {
            for item in items {
                if item.itemIdentifier.rawValue == "displayMode" {
                    (item.view as! NSButton).bind(.value, to: self, withKeyPath: "self.representedObject.displayMode", options: [.raisesForNotApplicableKeys : true])
                } else if item.itemIdentifier.rawValue == "renderMode" {
                    (item.view as! NSSegmentedControl).bind(.selectedIndex, to: self, withKeyPath: "self.representedObject.renderMode", options: [.raisesForNotApplicableKeys : true])
                }
            }
        }
        if !self.isKatexViewInitialized {
            self.katexView.initializeView()
            self.isKatexViewInitialized = true
        }
        self.view.window?.makeFirstResponder(self.inputTextView)
    }
    
    @IBAction func applyConfig(_ sender: Any) {
        self.renderText()
    }
    
    func renderText(registerChange: Bool = true) {
        let text = (self.representedObject as! Content).contentString
        
        if registerChange {
            NSDocumentController.shared.currentDocument!.updateChangeCount(.changeDone)
        }
        
        self.katexView.render(text, options: RenderConfiguration(self))
        
        self.loadOutlineEntries()
    }
    
    func loadOutlineEntries() {
        let navigatorVC = self.navigatorVC
        let outlineVC = navigatorVC.navigationVCs["outline"] as! OutlinePaneVC
        var entries: [OutlineEntry] = []
        for (index, (range, string)) in self.katexView.rangeMap.enumerated() {
            var content = string.trimmingCharacters(in: CharacterSet(charactersIn: "\n "))
            if content == "" {
                content = "(EMPTY LINE)"
            }
            let outlineEntry = OutlineEntry(text: content, lineRange: self.katexView.lineMap[index], selectableRange: range)
            entries.append(outlineEntry)
        }
        outlineVC.entries = entries
    }
    
    /*
    func highlightSyntax() {
        let contentObject = self.representedObject as! Content
        
        // remove all highlighting attributes
        let fullRange = NSRange(location: 0, length: (self.inputTextView.string as NSString).length)
        self.inputTextView.setFont(NSFont.monospacedSystemFont(ofSize: 14.0, weight: .regular), range: fullRange)
        self.inputTextView.setTextColor(NSColor.textColor, range: fullRange)
        self.inputTextView.textStorage?.removeAttribute(.backgroundColor, range: fullRange)
        
//        self.inputTextView.setSelectedRanges(self.katexView.highlightMap as [NSValue], affinity: .downstream, stillSelecting: true)
        
        if contentObject.renderMode == 0 {
            for range in self.katexView.mathMap {
                defer {
                    let dollarRegex = try! NSRegularExpression(pattern: #"\$"#)
                    for match in dollarRegex.matches(in: self.inputTextView.string, range: fullRange) {
                        self.inputTextView.setFont(NSFont.monospacedSystemFont(ofSize: 14.0, weight: .bold), range: match.range)
                        self.inputTextView.textStorage?.addAttribute(.foregroundColor, value: NSColor(red: 0, green: 0.45, blue: 0, alpha: 1), range: match.range)
                    }
                }
                guard range.location != NSNotFound else {
                    continue
                }
                self.inputTextView.textStorage?.addAttribute(.backgroundColor, value: NSColor(red: 0, green: 0.7, blue: 0, alpha: 0.05), range: range)
                
                let controlRegex = try! NSRegularExpression(pattern: #"\\([A-Za-z]+|$|[\s\\\{\}\[\]])?(?=$|[\{\[\(\)_\^\s\\\$])"#)
                for match in controlRegex.matches(in: self.inputTextView.string, range: range) {
                    self.inputTextView.setFont(NSFont.monospacedSystemFont(ofSize: 14.0, weight: .medium), range: match.range)
                    self.inputTextView.textStorage?.addAttribute(.foregroundColor, value: NSColor.systemOrange, range: match.range)
                }
                let bracesRegex = try! NSRegularExpression(pattern: #"[\{\}]"#)
                for match in bracesRegex.matches(in: self.inputTextView.string, range: range) {
                    self.inputTextView.textStorage?.addAttribute(.foregroundColor, value: NSColor.systemGray, range: match.range)
                }
            }
        } else {
            let controlRegex = try! NSRegularExpression(pattern: #"\\([A-Za-z]+|$|[\s\\\{\}\[\]])?(?=$|[\{\[\(\)_\^\s\\\$])"#)
            for match in controlRegex.matches(in: self.inputTextView.string, range: fullRange) {
                self.inputTextView.setFont(NSFont.monospacedSystemFont(ofSize: 14.0, weight: .medium), range: match.range)
                self.inputTextView.textStorage?.addAttribute(.foregroundColor, value: NSColor.systemOrange, range: match.range)
            }
            let bracesRegex = try! NSRegularExpression(pattern: #"[\{\}]"#)
            for match in bracesRegex.matches(in: self.inputTextView.string, range: fullRange) {
                self.inputTextView.textStorage?.addAttribute(.foregroundColor, value: NSColor.systemGray, range: match.range)
            }
            // remove highlighting outside of math mode
            for range in self.katexView.mathMap {
                self.inputTextView.setFont(NSFont.monospacedSystemFont(ofSize: 14.0, weight: .regular), range: range)
                self.inputTextView.textStorage?.addAttribute(.foregroundColor, value: NSColor.textColor, range: range)
                // add background color
                self.inputTextView.textStorage?.addAttribute(.backgroundColor, value: NSColor(red: 0, green: 0, blue: 0.8, alpha: 0.05), range: range)
            }
            // highlight last because the previous block clears
            // its highlight as $ is part of the math range
            let dollarRegex = try! NSRegularExpression(pattern: #"\$"#)
            for match in dollarRegex.matches(in: self.inputTextView.string, range: fullRange) {
                self.inputTextView.setFont(NSFont.monospacedSystemFont(ofSize: 14.0, weight: .bold), range: match.range)
                self.inputTextView.textStorage?.addAttribute(.foregroundColor, value: NSColor(red: 0, green: 0, blue: 0.9, alpha: 1), range: match.range)
            }
        }
    }
    */
    
    func indicate(_ range: NSRange, index: Int) {
        self.inputTextView.scrollRangeToCenter(range, animated: true) {
            self.inputTextView.showFindIndicator(for: range)
        }
        self.katexView.evaluateJavaScript("indicate(\(index));")
    }
    
}

extension EditorVC: TextViewDelegate, WKNavigationDelegate {
    
    func textDidChange(_ notification: Notification) {
        if self.inputTextView.string.last != "\n" {
            let previousRange = self.inputTextView.selectedRange()
            self.inputTextView.string += "\n"
            self.inputTextView.setSelectedRange(previousRange)
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
        let outlineVC = self.navigatorVC.navigationVCs["outline"] as! OutlinePaneVC
        outlineVC.bypassIndicateOnSelectionChange = true
        outlineVC.outlineTableView.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
        outlineVC.outlineTableView.scrollRowToVisible(index)
        
        let contentObject = self.representedObject as! Content
        
        contentObject.cursorPosition = selectedRange.location
        NSDocumentController.shared.currentDocument!.updateChangeCount(.changeDone)
        
        guard contentObject.lineCorrespondence else {
            return
        }
        self.katexView.evaluateJavaScript(index == self.previousCorrespondenceLine ? "scrollLineToVisible(\(index));" : "indicate(\(index));")
        self.previousCorrespondenceLine = index
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        let contentObject = self.representedObject as! Content
        
        let cursorRange = NSRange(location: contentObject.cursorPosition, length: 0)
        self.inputTextView.setSelectedRange(cursorRange)
        
        (self.inputTextView.delegate as? TextViewDelegate)?.textView(self.inputTextView, didClick: cursorRange)
        
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
