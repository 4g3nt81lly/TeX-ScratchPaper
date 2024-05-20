import SwiftUI
import UniformTypeIdentifiers

/// SwiftUI view for the export panel's accessory view.
struct ExportAccessoryView: View {
    
    @ObservedObject var window: DocumentWindow
    
    var body: some View {
        VStack(spacing: 12) {
            Picker(selection: $window.exportFileType, label: Text("Format:")) {
                Text("PDF").tag(UTType.pdf)
                Text("PNG").tag(UTType.png)
                Text("JPEG").tag(UTType.jpeg)
                Text("TIFF").tag(UTType.tiff)
                Divider()
                Text("Web Archive").tag(UTType.webArchive)
                Text("HTML").tag(UTType.html)
                Divider()
                Text("TXT").tag(UTType.txt)
                Text("TeX").tag(UTType.tex)
            }
            .aspectRatio(contentMode: .fit)
            .onReceive(window.$exportFileType) { newType in
                window.exportPanel.allowedContentTypes = [newType]
            }
            
            if ([.png, .jpeg, .tiff].contains(window.exportFileType)) {
                HStack(spacing: 10) {
                    Slider(value: $window.resolution, in: 128...1024,
                           label: { Text("Resolution:") })
                        .frame(width: 180)
                    Text("\(Int(window.resolution)) px")
                        .frame(width: 55, alignment: .leading)
                }
            }
        }
        .padding(.vertical, 15)
    }
}

extension UTType {
    
    static var txt = UTType(filenameExtension: "txt", conformingTo: .utf8PlainText)!
    
    static var tex = UTType(filenameExtension: "tex", conformingTo: .utf8PlainText)!
    
}
