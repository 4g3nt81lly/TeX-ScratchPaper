//
//  ExportAccessoryView.swift
//  Scratch Paper
//
//  Created by Bingyi Billy Li on 2022/7/5.
//

import SwiftUI
import UniformTypeIdentifiers

/// SwiftUI view for the export panel's accessory view.
struct ExportAccessoryView: View {
    
    /// An unowned reference to the main document window controller.
    unowned var window: DocumentWindow!
    
    /// Supported export file type.
    enum ExportFileType: String, Identifiable {
        
        var id: Self {
            return self
        }
        
        /// PDF (Portable Document Format) format.
        case pdf = "com.adobe.pdf"
        
        /// PNG (Portable Network Graphics) format.
        case png = "public.png"
        
        /// JPEG, JPG (Joint Photographic Experts Group) format.
        case jpeg = "public.jpeg"
        
        /// TIFF (Tag Image File Format) format.
        case tiff = "public.tiff"
        
        /// Webarchive (Safari's web archive) format.
        case webArchive = "com.apple.webarchive"
        
        /// HTML (Hypertext Markdown Language) format.
        case html = "public.html"
        
        /// TeX format.
        case tex = "org.tug.tex"
        
        /// Plain text format
        case txt = "public.plain-text"
        
    }
    
    /// Selected export file type.
    @State private var selectedExportFileType: ExportFileType = .pdf
    
    /// Resolution for image formats.
    @State private var resolution = 256.0
    
    var body: some View {
        VStack(spacing: 12) {
            Picker(selection: $selectedExportFileType, label: Text("Format:")) {
                Text("PDF").tag(ExportFileType.pdf)
                Text("PNG").tag(ExportFileType.png)
                Text("JPEG").tag(ExportFileType.jpeg)
                Text("TIFF").tag(ExportFileType.tiff)
                Divider()
                Text("Web Archive").tag(ExportFileType.webArchive)
                Text("HTML").tag(ExportFileType.html)
                Divider()
                Text("TXT").tag(ExportFileType.txt)
                Text("TeX").tag(ExportFileType.tex)
            }
            .padding(.horizontal, 20)
            .aspectRatio(contentMode: .fit)
            
            if [ExportFileType.png, ExportFileType.jpeg, ExportFileType.tiff].contains(selectedExportFileType) {
                HStack {
                    Slider(value: $resolution, in: 128...1024,
                           label: { Text("Resolution:") })
                        .frame(width: 210)
                    Text("\(Int(resolution)) px")
                        .frame(width: 55, alignment: .leading)
                        .padding(.leading, 5)
                }
                .padding(.leading, 30)
            }
        }
        .padding(.vertical, 15)
        .onChange(of: selectedExportFileType) { newValue in
            self.window.exportFileType = newValue
            self.window.exportPanel.allowedContentTypes = [UTType(newValue.rawValue)!]
        }
        .onChange(of: resolution) { newValue in
            self.window.resolution = self.resolution
        }
    }
}
