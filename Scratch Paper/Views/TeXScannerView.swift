import SwiftUI
import SVGView
import SwiftUIIntrospect
import UniformTypeIdentifiers

fileprivate func chooseImage() -> NSImage? {
    let openPanel = NSOpenPanel()
    openPanel.title = "Choose an image file to scan..."
    openPanel.allowedContentTypes = [.png, .jpeg]
    let modalResponse = openPanel.runModal()
    if modalResponse == .OK, let url = openPanel.url,
       let image = NSImage(contentsOf: url) {
        return image
    }
    return nil
}

fileprivate func handleImageDrop(from providers: [NSItemProvider],
                                 _ completionHandler: @escaping (NSImage) -> Void) -> Bool {
    guard providers.count == 1, let provider = providers.first else {
        return false
    }
    let type = provider.registeredTypeIdentifiers[0]
    _ = provider.loadDataRepresentation(forTypeIdentifier: type) { data, _ in
        if let data, let image = NSImage(data: data) {
            completionHandler(image)
        }
    }
    return true
}

struct TeXScannerDropZone: View {
    
    @State private var dropInRegion = false
    
    let editor: EditorVC
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Rectangle()
                    .strokeBorder(style: StrokeStyle(lineWidth: geometry.size.width * 0.01,
                                                     lineCap: .round, lineJoin: .round,
                                                     dash: [geometry.size.width * 0.05]))
                VStack(spacing: geometry.size.height * 0.05) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .resizable()
                        .scaledToFit()
                        .frame(width: geometry.size.width * 0.3, height: geometry.size.height * 0.3)
                    Text("Drop an image file here to scan...")
                        .font(.system(size: 14, weight: .semibold))
                }
            }
            .foregroundStyle(self.dropInRegion ? Color.accentColor : .gray)
            .animation(.easeInOut, value: self.dropInRegion)
            .contentShape(Rectangle())
            .onTapGesture {
                Task {
                    if let image = chooseImage() {
                        self.editor.dismissTeXScannerDropZone()
                        self.editor.presentTeXScannerView(with: image)
                    }
                }
            }
            .onDrop(of: [.png, .jpeg], isTargeted: $dropInRegion) { providers in
                return handleImageDrop(from: providers) { image in
                    DispatchQueue.main.async {
                        self.editor.dismissTeXScannerDropZone()
                        self.editor.presentTeXScannerView(with: image)
                    }
                }
            }
            .padding(geometry.size.width * 0.05)
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }
    
}

struct TeXScannerView: View {
    
    @State private var image: NSImage
    @State private var isConverting = false
    @State private var errorMessage: String? = nil
    
    @ObservedObject private var textEditorObject = TextEditorContent()
    
    let editor: EditorVC
    
    init(image: NSImage, editor: EditorVC) {
        self.image = image
        self.editor = editor
    }
    
    func convertFromImage() async {
        self.textEditorObject.disableEditing()
        self.isConverting = true
        do {
            let texString = try await Image2TexEngine.shared.getTexString(from: image)
            self.textEditorObject.texString = texString
            self.textEditorObject.render()
            self.errorMessage = nil
        } catch Image2TexEngine.ConversionError.networkError(let message),
                Image2TexEngine.ConversionError.dataError(let message) {
            self.errorMessage = message
        } catch {
            print(error)
            self.errorMessage = error.localizedDescription
        }
        self.isConverting = false
        self.textEditorObject.enableEditing()
    }
    
    private func saveSVG() {
        let savePanel = NSSavePanel()
        savePanel.title = "Export SVG file as..."
        savePanel.allowedContentTypes = [.svg]
        let response = savePanel.runModal()
        if response == .OK, let url = savePanel.url {
            do {
                try self.textEditorObject.svgString
                    .write(to: url, atomically: true, encoding: .utf8)
            } catch {
                let alert = NSAlert(error: error)
                alert.runModal()
            }
        }
    }
    
    private func getSVGItemProvider() -> NSItemProvider {
        var itemProvider = NSItemProvider()
        let currentHomeDir = FileManager.default.homeDirectoryForCurrentUser
        // attempt to create a temporary SVG file for drag and drop
        if var tempFileDir = try? FileManager.default
            .url(for: .itemReplacementDirectory, in: .userDomainMask,
                 appropriateFor: currentHomeDir, create: true) {
            tempFileDir.appendPathComponent("exported.svg", conformingTo: .svg)
            try? self.textEditorObject.svgString
                .write(to: tempFileDir, atomically: true, encoding: .utf8)
            if let tempFileProvider = NSItemProvider(contentsOf: tempFileDir) {
                itemProvider = tempFileProvider
            }
        }
        return itemProvider
    }
    
    private var svgView: some View {
        SVGView(string: self.textEditorObject.svgString)
    }
    
    @ViewBuilder
    private func loadedImagePane(_ geometry: GeometryProxy) -> some View {
        Group {
            VStack {
                HStack(spacing: 0) {
                    Spacer()
                    Image(nsImage: self.image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .padding(geometry.size.width * 0.05)
                        .if(!self.isConverting) { content in
                            content.onDrop(of: [.png, .jpeg], isTargeted: nil) { providers in
                                return handleImageDrop(from: providers) { image in
                                    self.image = image
                                    Task {
                                        await self.convertFromImage()
                                    }
                                }
                            }
                        }
                    Spacer()
                    VStack(spacing: geometry.size.width * 0.03) {
                        Button {
                            if let image = chooseImage() {
                                self.image = image
                                Task {
                                    await self.convertFromImage()
                                }
                            }
                        } label: {
                            Text("Reselect…")
                                .if(!self.isConverting) { content in
                                    content.onDrop(of: [.png, .jpeg], isTargeted: nil) { providers in
                                        return handleImageDrop(from: providers) { image in
                                            self.image = image
                                            Task {
                                                await self.convertFromImage()
                                            }
                                        }
                                    }
                                }
                                .frame(maxWidth: .infinity)
                        }
                        Button {
                            Task {
                                await self.convertFromImage()
                            }
                        } label: {
                            Text("Retry")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(self.isConverting)
                    .padding(geometry.size.width * 0.02)
                    .frame(width: geometry.size.width * 0.25)
                }
            }
        }
    }
    
    @ViewBuilder
    private func texEditorPane(_ geometry: GeometryProxy) -> some View {
        VStack {
            TextEditor(text: $textEditorObject.texString)
                .introspect(.textEditor, on: .macOS(.v12, .v13, .v14), customize: { textView in
                    // override delegate object and configure the underlying NSTextView
                    if let currentDelegate = textView.delegate as? NSObject,
                       currentDelegate != self.textEditorObject {
                        textView.delegate = self.textEditorObject
                        // initial text view configurations
                        textView.backgroundColor = .clear
                        textView.isRichText = false
                        textView.isAutomaticTextCompletionEnabled = false
                        textView.isAutomaticTextReplacementEnabled = false
                        // initialize delegate object's reference to the underlying NSTextView
                        self.textEditorObject.textView = textView
                        // initially set the text view as read-only
                        self.textEditorObject.disableEditing()
                    }
                })
                .font(.system(size: AppSettings.editorFont.pointSize).monospaced())
                .frame(maxWidth: geometry.size.width * 0.7)
            if self.isConverting {
                ProgressView()
                    .progressViewStyle(.linear)
                    .padding(.horizontal, geometry.size.width * 0.01)
                    .padding(.vertical, 1)
            } else if let errorMessage = self.errorMessage {
                HStack(spacing: min(geometry.size.width * 0.02, 10)) {
                    Image(systemName: "exclamationmark.triangle")
                        .resizable()
                        .scaledToFit()
                        .frame(width: max(min(geometry.size.width * 0.05, 30), 15),
                               height: max(min(geometry.size.height * 0.05, 30), 15))
                    Text(errorMessage)
                        .font(.system(size: 16, weight: .regular))
                    Spacer()
                }
                .foregroundStyle(.red)
            }
        }
        .padding(geometry.size.width * 0.03)
    }
    
    @ViewBuilder
    private func svgPreviewPane(_ geometry: GeometryProxy) -> some View {
        VStack {
            Color.white
                .overlay {
                    self.svgView
                        .padding(geometry.size.width * 0.01)
                }
                .if(!self.textEditorObject.svgString.isEmpty) { content in
                    content.onDrag {
                        return self.getSVGItemProvider()
                    } preview: {
                        self.svgView
                    }
                }
            HStack(spacing: geometry.size.width * 0.01) {
                Button {
                    self.editor.dismissTeXScannerView()
                } label: {
                    Text("Cancel")
                }
                .keyboardShortcut(.escape)
                
                Spacer()
                
                Group {
                    Button {
                        self.saveSVG()
                    } label: {
                        Text("Export SVG…")
                    }
                    Button {
                        self.editor.dismissTeXScannerView(with: self.textEditorObject.texString)
                    } label: {
                        Text("Insert")
                    }
                    .keyboardShortcut(.return)
                }
                .disabled(self.textEditorObject.svgString.isEmpty)
            }
            .padding(.vertical, geometry.size.height * 0.02)
        }
        .frame(minWidth: geometry.size.width * 0.3, maxWidth: geometry.size.width * 0.5)
        .padding(.horizontal, geometry.size.width * 0.03)
        .padding(.top, geometry.size.width * 0.03)
    }
    
    var body: some View {
        GeometryReader { geometry in
            VSplitView {
                self.loadedImagePane(geometry)
                    .frame(minHeight: geometry.size.height * 0.3)
                
                HSplitView {
                    self.texEditorPane(geometry)
                    self.svgPreviewPane(geometry)
                }
                .frame(minHeight: geometry.size.height * 0.3)
            }
            .padding(.horizontal)
            .padding(.bottom)
            .ignoresSafeArea()
        }
        .onLoad {
            Task {
                await self.convertFromImage()
            }
        }
    }
}

fileprivate class TextEditorContent: NSObject, ObservableObject, NSTextViewDelegate {
    
    var texString: String = ""
    
    @Published var svgString: String = ""
    
    private var timer: Timer?
    
    var textView: NSTextView!
    
    func render() {
        TeX2SVGRenderer.shared.render(self.texString) { svgString in
            self.svgString = svgString
        }
    }
    
    func disableEditing() {
        self.textView.isEditable = false
    }
    
    func enableEditing() {
        self.textView.isEditable = true
    }
    
    func textDidChange(_ notification: Notification) {
        self.texString = self.textView.string
        if let timer = self.timer {
            // timer exists, invalidate and create new timer
            timer.invalidate()
        }
        self.timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: false, block: { timer in
            self.render()
            timer.invalidate()
            self.timer = nil
        })
    }
    
    deinit {
        self.timer?.invalidate()
    }
    
}
