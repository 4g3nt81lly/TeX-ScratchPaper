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
class DocumentWindow: NSWindowController, ObservableObject {
    
    /**
     Reference to its `EditorVC` object.
     
     A computed property that gets editor object on-demand.
     */
    var editor: EditorVC {
        return (document as! Document).editor
    }
    
    // MARK: - Export Panel
    
    /**
     Selected file type for export by `exportPanel`.
     
     The default value is `.pdf`.
     */
    @Published var exportFileType: UTType = .pdf
    
    /**
     Resolution for file export when user selects `.png`, `.jpeg`, or `.tiff` in the export panel.
     
     The default value is `256.0`.
     */
    @Published var resolution = 256.0
    
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
        
        exportAccessoryView.topAnchor
            .constraint(equalTo: customView.topAnchor).isActive = true
        exportAccessoryView.bottomAnchor
            .constraint(equalTo: customView.bottomAnchor).isActive = true
        
        exportAccessoryView.leadingAnchor
            .constraint(greaterThanOrEqualTo: customView.leadingAnchor).isActive = true
        exportAccessoryView.trailingAnchor
            .constraint(greaterThanOrEqualTo: customView.trailingAnchor).isActive = true
        
        exportAccessoryView.centerXAnchor
            .constraint(equalTo: customView.centerXAnchor).isActive = true
        
        exportAccessoryView.widthAnchor
            .constraint(equalTo: customView.widthAnchor).isActive = true
        exportAccessoryView.heightAnchor
            .constraint(greaterThanOrEqualTo: customView.heightAnchor).isActive = true
        
        savePanel.accessoryView = customView
        
        savePanel.allowedContentTypes = [exportFileType]
        
        return savePanel
    }()
    
    /**
     Action sent when the user interacts with the toolbar items and the "render" button.
     
     Marks the document as "edited" (change done) and renders the content.
     */
    @IBAction func toolbarConfigChanged(_ sender: Any) {
        document!.updateChangeCount(.changeDone)
        editor.renderText()
    }
    
    // - MARK: - File Export
    
    /**
     Opens the `exportPanel` for file export.
     
     It loads and opens up the `exportPanel` as a sheel modal, and handles export logic for various
     file formats case by case.
     */
    @objc func export() {
        exportPanel.beginSheetModal(for: window!) { response in
            if (response == .OK) {
                let url = self.exportPanel.url!
                
                let export: [UTType : (URL) -> Void] = [
                    .pdf : self.exportPDF(to:),
                    .png : self.exportPNG(to:),
                    .jpeg : self.exportJPEG(to:),
                    .tiff : self.exportTIFF(to:),
                    .webArchive : self.exportWebArchive(to:),
                    .html : self.exportHTML(to:),
                    .tex : self.exportPlainText(to:),
                    .txt : self.exportPlainText(to:)
                ]
                
                export[self.exportFileType]!(url)
            }
        }
    }
    
    private func exportPDF(to url: URL) {
        editor.outputView.createPDF { result in
            switch result {
            case .success(let pdfData):
                do {
                    try pdfData.write(to: url)
                } catch {
                    let alert = NSAlert(error: error)
                    alert.beginSheetModal(for: self.window!)
                }
            case .failure(let error):
                let alert = NSAlert(error: error)
                alert.beginSheetModal(for: self.window!)
            }
        }
    }
    
    private func exportPNG(to url: URL) {
        let configuration = WKSnapshotConfiguration()
        configuration.snapshotWidth = resolution as NSNumber
        
        editor.outputView.takeSnapshot(with: configuration) { image, error in
            guard error == nil, let img = image else {
                let alert = NSAlert(error: error!)
                alert.beginSheetModal(for: self.window!)
                return
            }
            let cgImage = img.cgImage(forProposedRect: nil, context: nil, hints: nil)!
            let imageRep = NSBitmapImageRep(cgImage: cgImage)
            let data = imageRep.representation(using: .png, properties: [:])!
            do {
                try data.write(to: url)
            } catch {
                let alert = NSAlert(error: error)
                alert.beginSheetModal(for: self.window!)
            }
        }
    }
    
    private func exportJPEG(to url: URL) {
        let configuration = WKSnapshotConfiguration()
        configuration.snapshotWidth = self.resolution as NSNumber
        
        self.editor.outputView.takeSnapshot(with: configuration) { image, error in
            guard error == nil, let img = image else {
                let alert = NSAlert(error: error!)
                alert.beginSheetModal(for: self.window!)
                return
            }
            let cgImage = img.cgImage(forProposedRect: nil, context: nil, hints: nil)!
            let imageRep = NSBitmapImageRep(cgImage: cgImage)
            let data = imageRep.representation(using: .jpeg, properties: [:])!
            do {
                try data.write(to: url)
            } catch {
                let alert = NSAlert(error: error)
                alert.beginSheetModal(for: self.window!)
            }
        }
    }
    
    private func exportTIFF(to url: URL) {
        let configuration = WKSnapshotConfiguration()
        configuration.snapshotWidth = resolution as NSNumber
        
        editor.outputView.takeSnapshot(with: configuration) { image, error in
            guard error == nil, let img = image else {
                let alert = NSAlert(error: error!)
                alert.beginSheetModal(for: self.window!)
                return
            }
            let cgImage = img.cgImage(forProposedRect: nil, context: nil, hints: nil)!
            let imageRep = NSBitmapImageRep(cgImage: cgImage)
            let data = imageRep.representation(using: .tiff, properties: [:])!
            do {
                try data.write(to: url)
            } catch {
                let alert = NSAlert(error: error)
                alert.beginSheetModal(for: self.window!)
            }
        }
    }
    
    private func exportWebArchive(to url: URL) {
        editor.outputView.createWebArchiveData { result in
            switch result {
            case .success(let webArchiveData):
                do {
                    try webArchiveData.write(to: url)
                } catch {
                    let alert = NSAlert(error: error)
                    alert.beginSheetModal(for: self.window!)
                }
            case .failure(let error):
                let alert = NSAlert(error: error)
                alert.beginSheetModal(for: self.window!)
            }
        }
    }
    
    private func exportHTML(to url: URL) {
        editor.outputView.evaluateJavaScript("document.documentElement.outerHTML;") { output, _ in
            let htmlString = output as! String
            do {
                try htmlString.write(to: url, atomically: true, encoding: .unicode)
            } catch {
                let alert = NSAlert(error: error)
                alert.beginSheetModal(for: self.window!)
            }
        }
    }
    
    private func exportPlainText(to url: URL) {
        do {
            try editor.document.content.contentString
                .write(to: url, atomically: true, encoding: .unicode)
        } catch {
            let alert = NSAlert(error: error)
            alert.beginSheetModal(for: window!)
        }
    }
    
    deinit {
        self.window!.toolbar!.items.forEach { item in
            if (item.itemIdentifier.rawValue == "displayMode") {
                item.unbind(.value)
            } else if (item.itemIdentifier.rawValue == "renderMode") {
                item.unbind(.selectedIndex)
            }
        }
    }
    
}

// MARK: - Toolbar Configuration

extension NSToolbarItem.Identifier: @retroactive ExpressibleByStringLiteral {
    
    public init(stringLiteral value: String) {
        self.init(value)
    }
    
}

extension DocumentWindow: NSToolbarDelegate {
    
    /// Specifies allowed toolbar items (by identifiers).
    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return ["sidebar", "displayMode", "renderMode", "render",
                .space, .flexibleSpace]
    }
    
    /// Specifies default visible toolbar items.
    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return ["sidebar", "render",
                .flexibleSpace,
                "displayMode", "renderMode"]
    }
    
    /**
     Generates the toolbar items in a custom manner.
     
     This implementation, along with the entire `NSToolbarDelegate` extension, serves but one
     purpose: to add a render button as a toolbar item with an attached menu (`NSMenuToolbarItem`).
     The other toolbar items are returned directly from `toolbar.items` as they already exist
     (created in the interface builder).
    */
    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
                 willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        if (itemIdentifier.rawValue == "render") {
            let renderItem = NSMenuToolbarItem(itemIdentifier: "render")
            renderItem.image = NSImage(systemSymbolName: "paintbrush.fill",
                                       accessibilityDescription: nil)
            renderItem.label = "Render"
            renderItem.paletteLabel = "Render"
            
            let menu = NSMenu()
            let configItem = NSMenuItem(title: "Configuration", action: #selector(editor.presentConfigurationView),
                                        keyEquivalent: "")
            configItem.image = NSImage(systemSymbolName: "gearshape.fill",
                                       accessibilityDescription: nil)
            menu.addItem(configItem)
            
            renderItem.menu = menu
            renderItem.action = #selector(toolbarConfigChanged(_:))
            
            renderItem.autovalidates = true
            renderItem.isBordered = true
            renderItem.isNavigational = true
            
            return renderItem
        } else {
            return toolbar.items.first(where: { $0.itemIdentifier == itemIdentifier })!
        }
    }
    
}

// MARK: - Window Events

extension DocumentWindow: NSWindowDelegate {
    
    func windowWillClose(_ notification: Notification) {
        // unbind all toolbar items
        for item in window!.toolbar!.items {
            if (item.itemIdentifier.rawValue == "displayMode") {
                (item.view as! NSButton).unbind(.value)
            } else if (item.itemIdentifier.rawValue == "renderMode") {
                (item.view as! NSSegmentedControl).unbind(.selectedIndex)
            }
        }
    }
    
    func windowDidDeminiaturize(_ notification: Notification) {
        // this document window was miniaturized before the application terminated previously, which
        //   is then restored, since in this case deminiaturizing does not trigger EditorVC's
        //   viewDidAppear() (weirdly enough), which leaves one no better option but to do so manually
        editor.viewDidAppear()
    }
    
    // MARK: - Backtracing for troubleshooting.
    
    /*
    
    override func windowWillLoad() {
        super.windowWillLoad()
        print("[Window] Window will load with document \(String(describing: document)) and content \(String(describing: (document as? Document)?.content)).")
    }
    
    override func windowDidLoad() {
        super.windowDidLoad()
        print("[Window \(window!)] Window did load with document \(String(describing: document)) and content \(String(describing: (self.document as? Document)?.content)).")
    }
    
    func windowWillClose(_ notification: Notification) {
        print("[Window \(window!)] Window will close with document \(String(describing: document)) and content \(String(describing: (document as? Document)?.content)).")
    }
     
     */
    
}
