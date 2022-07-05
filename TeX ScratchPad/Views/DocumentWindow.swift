//
//  DocumentWindow.swift
//  TeX-ScratchPad
//
//  Created by Bingyi Billy Li on 2021/3/5.
//

import Cocoa
import WebKit
import JavaScriptCore
import UniformTypeIdentifiers

@objcMembers
class DocumentWindow: NSWindowController {
    
    var editor: Editor {
        return (self.document as! ScratchPad).editor
    }
    
    lazy var exportPanel: NSSavePanel = {
        let savePanel = NSSavePanel()
        
        savePanel.message = "Specify where and how you wish to export..."
        savePanel.nameFieldLabel = "Export As:"
        savePanel.canCreateDirectories = true
        savePanel.isExtensionHidden = false
        savePanel.showsTagField = true
        
        // get and set accessory view
        let exportAccessoryVC = NSViewController(nibName: "ExportAccessoryView", bundle: mainBundle)
        savePanel.accessoryView = exportAccessoryVC.view
        
        // get popup and bind its value to observe change
        let fileTypePopup = savePanel.accessoryView!.subviews[0].subviews.first(where: { $0.identifier?.rawValue == "fileTypePopup" }) as! NSPopUpButton
        fileTypePopup.bind(.selectedValue, to: self, withKeyPath: "self.selectedExportFileType")
        
        savePanel.allowedContentTypes = [UTType(fileTypePopup.item(withTitle: self.selectedExportFileType)!.identifier!.rawValue)!]
        
        return savePanel
    }()
    
    dynamic var selectedExportFileType = "PDF" {
        didSet {
            let fileTypePopup = self.exportPanel.accessoryView!.subviews[0].subviews.first(where: { $0.identifier?.rawValue == "fileTypePopup" }) as! NSPopUpButton
            let contentType = UTType(fileTypePopup.selectedItem!.identifier!.rawValue)!
            self.exportPanel.allowedContentTypes = [contentType]
        }
    }
    
    @IBAction func toggleSidebar(_ sender: Any) {
        // MARK: can be adapted
        (self.contentViewController as! MainSplitView).toggleSidebar(nil)
    }
    
    // toolbar item action
    @IBAction func renderContent(_ sender: Any) {
        self.editor.renderText()
    }
    
    func export() {
        self.exportPanel.beginSheetModal(for: self.window!) { response in
            if response == .OK {
                let saveURL = self.exportPanel.url!
                switch self.exportPanel.allowedContentTypes.first! {
                case .pdf:
                    self.editor.katexView.createPDF { result in
                        switch result {
                        case .success(let pdfData):
                            do {
                                try pdfData.write(to: saveURL)
                            } catch {
                                let alert = NSAlert(error: error)
                                alert.beginSheetModal(for: self.window!)
                            }
                        case .failure(let error):
                            let alert = NSAlert(error: error)
                            alert.beginSheetModal(for: self.window!)
                        }
                    }
                case .png:
                    // TODO: Support PNG exporting
                    break
                case .jpeg:
                    // TODO: Support JPEG exporting
                    break
                case .webArchive:
                    self.editor.katexView.createWebArchiveData { result in
                        switch result {
                        case .success(let webArchiveData):
                            do {
                                try webArchiveData.write(to: saveURL)
                            } catch {
                                let alert = NSAlert(error: error)
                                alert.beginSheetModal(for: self.window!)
                            }
                        case .failure(let error):
                            let alert = NSAlert(error: error)
                            alert.beginSheetModal(for: self.window!)
                        }
                    }
                case .html:
                    self.editor.katexView.evaluateJavaScript("document.documentElement.outerHTML;") { output, _ in
                        let htmlString = output as! String
                        let fileData = htmlString.data(using: .utf8)!
                        do {
                            try fileData.write(to: saveURL)
                        } catch {
                            let alert = NSAlert(error: error)
                            alert.beginSheetModal(for: self.window!)
                        }
                    }
                    break
                case .init(filenameExtension: "tex")!:
                    // TODO: Support TeX plain-text file exporting
                    break
                default:
                    return
                }
            }
        }
    }
    
    @IBAction func insert(_ sender: Any) {
        guard let command = (sender as? NSPopUpButton)?.titleOfSelectedItem ?? (sender as? NSMenuItem)?.title else {
            return
        }
        let vc = self.editor
        
        func insertItem(_ item: String, _ backspace: Int, _ length: Int = 0) {
            let oldCursor = vc.contentTextView.selectedRange()
            vc.contentTextView.insertText(item, replacementRange: oldCursor)
            let newCursor = vc.contentTextView.selectedRange()
            let newRange = NSRange(location: newCursor.location - backspace, length: length)
            vc.contentTextView.setSelectedRange(newRange)
        }
        
        guard let tag = (sender as? NSMenuItem)?.tag, tag != 1 else {
            let symbolCommand = "\\\(command.replacingOccurrences(of: ")", with: "").components(separatedBy: "(").last!)"
            insertItem(symbolCommand, 0)
            return
        }
        
        func encapsulateItem(_ left: String, _ right: String, _ backspace: Int? = nil, _ forwardspace: Int = 0) {
            let selectedRange = vc.contentTextView.selectedRange()
            var insertRange = NSRange(location: selectedRange.upperBound, length: 0)
            vc.contentTextView.insertText(right, replacementRange: insertRange)
            insertRange = NSRange(location: selectedRange.location, length: 0)
            vc.contentTextView.insertText(left, replacementRange: insertRange)
            if let count = backspace {
                insertRange = NSRange(location: insertRange.location + left.count + selectedRange.length + right.count - count, length: 0)
            } else {
                insertRange = NSRange(location: insertRange.location + left.count + forwardspace, length: forwardspace == 0 ? selectedRange.length : 0)
            }
            vc.contentTextView.setSelectedRange(insertRange)
        }
        
        let selectedRange = vc.contentTextView.selectedRange()
        
        switch command {
        case "Fraction":
            insertItem("\\frac{}{}", 3)
        case "Exponent":
            guard selectedRange.length > 0 else {
                insertItem("^{}", 1)
                return
            }
            encapsulateItem("{", "}^{}", 1)
        case "Square Root":
            guard selectedRange.length > 0 else {
                insertItem("\\sqrt{}", 1)
                return
            }
            encapsulateItem("\\sqrt{", "}")
        case "Root":
            guard selectedRange.length > 0 else {
                insertItem("\\sqrt[]{}", 3)
                return
            }
            encapsulateItem("\\sqrt[]{", "}", nil, -2)
        case "Smart Parentheses":
            guard selectedRange.length > 0 else {
                insertItem("\\left(\\right)", 7)
                return
            }
            encapsulateItem("\\left(", "\\right)")
        case "Indefinite Integral":
            guard selectedRange.length > 0 else {
                insertItem("\\int{}", 1)
                return
            }
            encapsulateItem("\\int{", "}")
        case "Definite Integral":
            insertItem("\\int_{}^{}", 4)
        case "Sum":
            insertItem("\\sum_{}^{}", 4)
        case "Product":
            insertItem("\\prod_{}^{}", 4)
        case "Limit":
            insertItem("\\lim_{}", 1)
        case "Binomial":
            insertItem("\\binom{}{}", 3)
        case "Aligned":
            guard selectedRange.length > 0 else {
                let env = "\\begin{aligned}\n\t\n\\end{aligned}"
                insertItem(env, 14)
                return
            }
            encapsulateItem("\\begin{aligned}\n\t", "\n\\end{aligned}")
        case "Array":
            let env = "\\begin{array}{cc}\n\t\n\\end{array}"
            insertItem(env, 12)
        case "Matrix":
            let env = "\\begin{matrix}\n\t\n\\end{matrix}"
            insertItem(env, 13)
        case "Parenthesis Matrix":
            let env = "\\begin{pmatrix}\n\t\n\\end{pmatrix}"
            insertItem(env, 14)
        case "Bracket Matrix":
            let env = "\\begin{bmatrix}\n\t\n\\end{bmatrix}"
            insertItem(env, 14)
        case "Braces Matrix":
            let env = "\\begin{Bmatrix}\n\t\n\\end{Bmatrix}"
            insertItem(env, 14)
        case "Vertical Matrix":
            let env = "\\begin{vmatrix}\n\t\n\\end{vmatrix}"
            insertItem(env, 14)
        case "Double-Vertical Matrix":
            let env = "\\begin{Vmatrix}\n\t\n\\end{Vmatrix}"
            insertItem(env, 14)
        case "Cases":
            let env = "\\begin{cases}\n\ta & \\text{if } b \\\\\n\tc & \\text{if } d\n\\end{cases}"
            insertItem(env, 50, 38)
        case "Table":
            let env = "\\def\\arraystretch{1.5}\n\\begin{array}{c|c:c}\n\ta & b & c \\\\ \\hline\n\td & e & f \\\\ \\hdashline\n\tg & h & i\n\\end{array}"
            insertItem(env, 69, 57)
        case "Cancel (Left)":
            guard selectedRange.length > 0 else {
                insertItem("\\cancel{}", 1)
                return
            }
            encapsulateItem("\\cancel{", "}")
        case "Cancel (Right)":
            guard selectedRange.length > 0 else {
                insertItem("\\bcancel{}", 1)
                return
            }
            encapsulateItem("\\bcancel{", "}")
        case "Cancel (X)":
            guard selectedRange.length > 0 else {
                insertItem("\\xcancel{}", 1)
                return
            }
            encapsulateItem("\\xcancel{", "}")
        case "Strike Through":
            guard selectedRange.length > 0 else {
                insertItem("\\sout{}", 1)
                return
            }
            encapsulateItem("\\sout{", "}")
        case "Overline":
            guard selectedRange.length > 0 else {
                insertItem("\\overline{}", 1)
                return
            }
            encapsulateItem("\\overline{", "}")
        case "Underline":
            guard selectedRange.length > 0 else {
                insertItem("\\underline{}", 1)
                return
            }
            encapsulateItem("\\underline{", "}")
        case "Overbrace":
            guard selectedRange.length > 0 else {
                insertItem("\\overbrace{}^{}", 4)
                return
            }
            encapsulateItem("\\overbrace{", "}^{}", 1)
        case "Underbrace":
            guard selectedRange.length > 0 else {
                insertItem("\\underbrace{}^{}", 4)
                return
            }
            encapsulateItem("\\underbrace{", "}^{}", 1)
        case "Over Left Arrow":
            guard selectedRange.length > 0 else {
                insertItem("\\overleftarrow{}", 1)
                return
            }
            encapsulateItem("\\overleftarrow{", "}")
        case "Over Right Arrow":
            guard selectedRange.length > 0 else {
                insertItem("\\overrightarrow{}", 1)
                return
            }
            encapsulateItem("\\overrightarrow{", "}")
        case "Vector":
            guard selectedRange.length > 0 else {
                insertItem("\\vec{}", 1)
                return
            }
            encapsulateItem("\\vec{", "}")
        case "Hat":
            guard selectedRange.length > 0 else {
                insertItem("\\hat{}", 1)
                return
            }
            encapsulateItem("\\hat{", "}")
        case "Bar":
            guard selectedRange.length > 0 else {
                insertItem("\\bar{}", 1)
                return
            }
            encapsulateItem("\\bar{", "}")
        case "Box":
            guard selectedRange.length > 0 else {
                insertItem("\\boxed{}", 1)
                return
            }
            encapsulateItem("\\boxed{", "}")
        case "Toggle Mode":
            guard selectedRange.length > 0 else {
                insertItem("$$", 1)
                return
            }
            encapsulateItem("$", "$")
        default:
            print("Unknown command.")
            return
        }
        vc.renderText()
    }
    
}
