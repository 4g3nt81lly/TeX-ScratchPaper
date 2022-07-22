//
//  DocumentWindow.swift
//  Scratch Paper
//
//  Created by Bingyi Billy Li on 2021/3/5.
//

import Cocoa
import SwiftUI
import WebKit
import UniformTypeIdentifiers

/**
 Document window controller.
 
 It is used for the following:
 1. Supports file export.
 2. Manages toolbar.
 */
class DocumentWindow: NSWindowController {
    
    /**
     Reference to its `Editor` object.
     
     A computed property that gets editor object on-demand.
     */
    var editor: Editor {
        return (self.document as! Document).editor
    }
    
    /**
     Selected file type for export by `exportPanel`.
     
     The default value is `.pdf`.
     */
    var exportFileType: ExportAccessoryView.ExportFileType = .pdf
    
    /**
     Resolution for file export when user selects `.png`, `.jpeg`, or `.tiff` in the export panel.
     
     The default value is `256.0`.
     */
    var resolution = 256.0
    
    /**
     Export panel for file export.
     
     This is loaded and stored on-demand. The accessory view is added to provide options for file export.
     The accessory view updates the `exportPanel`'s `allowedContentTypes` when user changes the file format.
     */
    lazy var exportPanel: NSSavePanel = {
        let savePanel = NSSavePanel()
        
        savePanel.message = "Specify where and how you wish to export..."
        savePanel.nameFieldLabel = "Export As:"
        savePanel.canCreateDirectories = true
        savePanel.isExtensionHidden = false
        savePanel.showsTagField = true
        
        let accessoryView = ExportAccessoryView(window: self)
        let exportAccessoryView = NSHostingView(rootView: accessoryView)
        
        let customView = NSView(frame: NSRect(x: 0, y: 0, width: 300, height: 60))
        customView.addSubview(exportAccessoryView)
        
        // use my own constraints
        exportAccessoryView.translatesAutoresizingMaskIntoConstraints = false
        
        exportAccessoryView.topAnchor.constraint(equalTo: customView.topAnchor).isActive = true
        exportAccessoryView.bottomAnchor.constraint(equalTo: customView.bottomAnchor).isActive = true
        
        exportAccessoryView.leadingAnchor.constraint(greaterThanOrEqualTo: customView.leadingAnchor).isActive = true
        exportAccessoryView.trailingAnchor.constraint(greaterThanOrEqualTo: customView.trailingAnchor).isActive = true
        
        exportAccessoryView.centerXAnchor.constraint(equalTo: customView.centerXAnchor).isActive = true
        
        exportAccessoryView.widthAnchor.constraint(equalTo: customView.widthAnchor).isActive = true
        exportAccessoryView.heightAnchor.constraint(greaterThanOrEqualTo: customView.heightAnchor).isActive = true
        
        savePanel.accessoryView = customView
        
        savePanel.allowedContentTypes = [UTType(self.exportFileType.rawValue)!]
        
        return savePanel
    }()
    
    /**
     Action sent when the user interacts with the toolbar items and the "render" button.
     
     Marks the document as "edited" (change done) and renders the content.
     */
    @IBAction func toolbarConfigChanged(_ sender: Any) {
        self.editor.document.updateChangeCount(.changeDone)
        self.editor.renderText()
    }
    
    /**
     Opens the `exportPanel` for file export.
     
     It loads and opens up the `exportPanel` as a sheel modal, and handles export logic for various file formats case by case.
     */
    @objc func export() {
        self.exportPanel.beginSheetModal(for: self.window!) { response in
            if response == .OK {
                let saveURL = self.exportPanel.url!
                
                switch self.exportFileType {
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
                    let configuration = WKSnapshotConfiguration()
                    configuration.snapshotWidth = self.resolution as NSNumber
                    
                    self.editor.katexView.takeSnapshot(with: configuration) { image, error in
                        guard error == nil, let img = image else {
                            let alert = NSAlert(error: error!)
                            alert.beginSheetModal(for: self.window!)
                            return
                        }
                        let cgImage = img.cgImage(forProposedRect: nil, context: nil, hints: nil)!
                        let imageRep = NSBitmapImageRep(cgImage: cgImage)
                        let data = imageRep.representation(using: .png, properties: [:])!
                        do {
                            try data.write(to: saveURL)
                        } catch {
                            let alert = NSAlert(error: error)
                            alert.beginSheetModal(for: self.window!)
                        }
                    }
                case .jpeg:
                    let configuration = WKSnapshotConfiguration()
                    configuration.snapshotWidth = self.resolution as NSNumber
                    
                    self.editor.katexView.takeSnapshot(with: configuration) { image, error in
                        guard error == nil, let img = image else {
                            let alert = NSAlert(error: error!)
                            alert.beginSheetModal(for: self.window!)
                            return
                        }
                        let cgImage = img.cgImage(forProposedRect: nil, context: nil, hints: nil)!
                        let imageRep = NSBitmapImageRep(cgImage: cgImage)
                        let data = imageRep.representation(using: .jpeg, properties: [:])!
                        do {
                            try data.write(to: saveURL)
                        } catch {
                            let alert = NSAlert(error: error)
                            alert.beginSheetModal(for: self.window!)
                        }
                    }
                case .tiff:
                    let configuration = WKSnapshotConfiguration()
                    configuration.snapshotWidth = self.resolution as NSNumber
                    
                    self.editor.katexView.takeSnapshot(with: configuration) { image, error in
                        guard error == nil, let img = image else {
                            let alert = NSAlert(error: error!)
                            alert.beginSheetModal(for: self.window!)
                            return
                        }
                        let cgImage = img.cgImage(forProposedRect: nil, context: nil, hints: nil)!
                        let imageRep = NSBitmapImageRep(cgImage: cgImage)
                        let data = imageRep.representation(using: .tiff, properties: [:])!
                        do {
                            try data.write(to: saveURL)
                        } catch {
                            let alert = NSAlert(error: error)
                            alert.beginSheetModal(for: self.window!)
                        }
                    }
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
                        do {
                            try htmlString.write(to: saveURL, atomically: true, encoding: .unicode)
                        } catch {
                            let alert = NSAlert(error: error)
                            alert.beginSheetModal(for: self.window!)
                        }
                    }
                    break
                case .tex, .txt:
                    do {
                        try self.editor.document.content.contentString.write(to: saveURL, atomically: true, encoding: .unicode)
                    } catch {
                        let alert = NSAlert(error: error)
                        alert.beginSheetModal(for: self.window!)
                    }
                }
            }
        }
    }
    
    deinit {
        self.window?.toolbar?.items.forEach({ item in
            if item.itemIdentifier.rawValue == "displayMode" {
                item.unbind(.value)
            } else if item.itemIdentifier.rawValue == "renderMode" {
                item.unbind(.selectedIndex)
            }
        })
    }
    
}

extension DocumentWindow: NSToolbarDelegate {
    
    /// Specifies allowed toolbar items (by identifiers).
    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return [NSToolbarItem.Identifier("sidebar"),
                NSToolbarItem.Identifier("displayMode"),
                NSToolbarItem.Identifier("renderMode"),
                NSToolbarItem.Identifier("render"),
                .space, .flexibleSpace]
    }
    
    /// Specifies default visible toolbar items.
    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return [NSToolbarItem.Identifier("sidebar"),
                NSToolbarItem.Identifier("render"), .flexibleSpace,
                NSToolbarItem.Identifier("displayMode"),
                NSToolbarItem.Identifier("renderMode")]
    }
    
    /**
     Generates the toolbar items in a custom manner.
     
     This implementation, along with the entire `NSToolbarDelegate` extension, serves but one purpose: to add a render button as a toolbar item with an attached menu (`NSMenuToolbarItem`).
     The other toolbar items are returned directly from `toolbar.items` as they already exist (created in the interface builder).
    */
    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        if itemIdentifier.rawValue == "render" {
            let renderItem = NSMenuToolbarItem(itemIdentifier: NSToolbarItem.Identifier("render"))
            renderItem.image = NSImage(systemSymbolName: "paintbrush.fill", accessibilityDescription: nil)
            renderItem.label = "Render"
            renderItem.paletteLabel = "Render"
            
            let menu = NSMenu()
            let configItem = NSMenuItem(title: "Configuration", action: #selector(self.presentConfigView), keyEquivalent: "")
            configItem.image = NSImage(systemSymbolName: "gearshape.fill", accessibilityDescription: nil)
            menu.addItem(configItem)
            
            renderItem.menu = menu
            renderItem.action = #selector(self.toolbarConfigChanged(_:))
            
            renderItem.autovalidates = true
            renderItem.isBordered = true
            renderItem.isNavigational = true
            
            return renderItem
        } else {
            return toolbar.items.first(where: { $0.itemIdentifier == itemIdentifier })!
        }
    }
    
    /**
     An intermediate method that receives action from the "Configuration" menu item and calls `Editor.presentConfigView()`.
     
     This method is defined here and marked Objective-C to serve as an action selector for the "Configuration" menu item that is always available regardless.
     
     - Note: The reason why the "Configuration" menu item's action selector is not pointing directly to the destination method (`Editor.presentConfigView()`) is because in doing so, the menu item becomes actionable only when the first responder is the main text view _(somehow for reasons not yet understood)_.
     */
    @objc func presentConfigView() {
        self.editor.presentConfigView()
    }
    
}

extension DocumentWindow: NSWindowDelegate {
    
    func windowWillClose(_ notification: Notification) {
        // unbind all toolbar items
        for item in self.window!.toolbar!.items {
            if item.itemIdentifier.rawValue == "displayMode" {
                (item.view as! NSButton).unbind(.value)
            } else if item.itemIdentifier.rawValue == "renderMode" {
                (item.view as! NSSegmentedControl).unbind(.selectedIndex)
            }
        }
    }
    
    // MARK: Backtracing for troubleshooting.
    
    /*
    
    override func windowWillLoad() {
        super.windowWillLoad()
        print("[Window] Window will load with document \(String(describing: self.document)) and content \(String(describing: (self.document as? Document)?.content)).")
    }
    
    override func windowDidLoad() {
        super.windowDidLoad()
        print("[Window \(self.window!)] Window did load with document \(String(describing: self.document)) and content \(String(describing: (self.document as? Document)?.content)).")
    }
    
    func windowWillClose(_ notification: Notification) {
        print("[Window \(self.window!)] Window will close with document \(String(describing: self.document)) and content \(String(describing: (self.document as? Document)?.content)).")
    }
     
     */
    
}
