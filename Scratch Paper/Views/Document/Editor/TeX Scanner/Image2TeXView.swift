import SwiftUI
import SVGView
import SwiftUIIntrospect
import UniformTypeIdentifiers

func chooseImage() -> NSImage? {
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

func handleImageDrop(from providers: [NSItemProvider],
                     _ completionHandler: @escaping (NSImage) -> Void) -> Bool {
    guard providers.count == 1,
          let provider = providers.first else {
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

struct Image2TeXView: View {
    
    @State private var image: NSImage
    @State private var isConverting = false
    @State private var errorMessage: String?
    
    @ObservedObject private var textEditorObject = TextEditorContent()
    
    let dismiss: (String?) -> Void
    
    @State private var conversionTask: Task<(), Never>?
    
    init(image: NSImage, dismiss: @escaping (String?) -> Void) {
        self.image = image
        self.dismiss = dismiss
    }
    
    private func convert() {
        conversionTask = Task {
            await convertFromImage()
        }
    }
    
    private func convertFromImage() async {
        textEditorObject.disableEditing()
        isConverting = true
        do {
            let texString = try await Image2TexEngine.shared.getTexString(from: image)
            textEditorObject.texString = texString
            textEditorObject.render()
            errorMessage = nil
        } catch Image2TexEngine.ConversionError.networkError(let message),
                Image2TexEngine.ConversionError.dataError(let message) {
            errorMessage = message
        } catch {
            errorMessage = error.localizedDescription
        }
        isConverting = false
        textEditorObject.enableEditing()
    }
    
    private func saveSVG() {
        let savePanel = NSSavePanel()
        savePanel.title = "Export SVG file as..."
        savePanel.allowedContentTypes = [.svg]
        let response = savePanel.runModal()
        if response == .OK, let url = savePanel.url {
            do {
                try textEditorObject.svgString
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
            try? textEditorObject.svgString
                .write(to: tempFileDir, atomically: true, encoding: .utf8)
            if let tempFileProvider = NSItemProvider(contentsOf: tempFileDir) {
                itemProvider = tempFileProvider
            }
        }
        return itemProvider
    }
    
    private var svgView: some View {
        SVGView(string: textEditorObject.svgString)
    }
    
    @ViewBuilder
    private func loadedImagePane(_ geometry: GeometryProxy) -> some View {
        Group {
            VStack {
                HStack(spacing: 0) {
                    Spacer()
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .padding(geometry.size.width * 0.05)
                        .if(!isConverting) { content in
                            content.onDrop(of: [.png, .jpeg], isTargeted: nil) { providers in
                                return handleImageDrop(from: providers) { image in
                                    self.image = image
                                    convert()
                                }
                            }
                        }
                    Spacer()
                    VStack(spacing: geometry.size.width * 0.03) {
                        Button {
                            if let image = chooseImage() {
                                self.image = image
                                convert()
                            }
                        } label: {
                            Text("Reselect…")
                                .if(!isConverting) { content in
                                    content.onDrop(of: [.png, .jpeg], isTargeted: nil) { providers in
                                        return handleImageDrop(from: providers) { image in
                                            self.image = image
                                            convert()
                                        }
                                    }
                                }
                                .frame(maxWidth: .infinity)
                        }
                        Button {
                            convert()
                        } label: {
                            Text("Retry")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(isConverting)
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
                .introspect(.textEditor, on: .macOS(.v13, .v14)) { textView in
                    // override delegate object and configure the underlying NSTextView
                    if let currentDelegate = textView.delegate as? NSObject,
                       currentDelegate != textEditorObject {
                        textView.delegate = textEditorObject
                        // initial text view configurations
                        textView.backgroundColor = .clear
                        textView.isRichText = false
                        textView.isAutomaticTextCompletionEnabled = false
                        textView.isAutomaticTextReplacementEnabled = false
                        // initialize delegate object's reference to the underlying NSTextView
                        textEditorObject.textView = textView
                        // initially set the text view as read-only
                        textEditorObject.disableEditing()
                    }
                }
                .font(.system(size: EditorTheme.editorFont.pointSize).monospaced())
                .frame(maxWidth: geometry.size.width * 0.7)
            if (isConverting) {
                ProgressView()
                    .progressViewStyle(.linear)
                    .padding(.horizontal, geometry.size.width * 0.01)
                    .padding(.vertical, 1)
            } else if let errorMessage {
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
                    svgView
                        .padding(geometry.size.width * 0.01)
                }
                .if(!textEditorObject.svgString.isEmpty) { content in
                    content.onDrag {
                        return getSVGItemProvider()
                    } preview: {
                        svgView
                    }
                }
            HStack(spacing: geometry.size.width * 0.01) {
                Button {
                    conversionTask?.cancel()
                    dismiss(nil)
                } label: {
                    Text("Cancel")
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Group {
                    Button {
                        saveSVG()
                    } label: {
                        Text("Export SVG…")
                    }
                    Button {
                        conversionTask?.cancel()
                        dismiss(textEditorObject.texString)
                    } label: {
                        Text("Insert")
                    }
                    .keyboardShortcut(.defaultAction)
                }
                .disabled(textEditorObject.svgString.isEmpty)
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
                loadedImagePane(geometry)
                    .frame(minHeight: geometry.size.height * 0.3)
                
                HSplitView {
                    texEditorPane(geometry)
                    svgPreviewPane(geometry)
                }
                .frame(minHeight: geometry.size.height * 0.3)
            }
            .padding(.horizontal)
            .padding(.bottom)
            .ignoresSafeArea()
        }
        .onLoad {
            convert()
        }
    }
}

fileprivate class TextEditorContent: NSObject, ObservableObject, NSTextViewDelegate {
    
    var texString: String = ""
    
    @Published var svgString: String = ""
    
    private var timer: Timer?
    
    var textView: NSTextView!
    
    func render() {
        TeX2SVGRenderer.shared.render(texString) { svgString in
            self.svgString = svgString
        }
    }
    
    func disableEditing() {
        textView.isEditable = false
    }
    
    func enableEditing() {
        textView.isEditable = true
    }
    
    func textDidChange(_ notification: Notification) {
        texString = self.textView.string
        if let timer {
            // timer exists, invalidate and create new timer
            timer.invalidate()
        }
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: false) { timer in
            self.render()
            timer.invalidate()
            self.timer = nil
        }
    }
    
    deinit {
        timer?.invalidate()
    }
    
}

extension Image2TeXView: Presentable {
    
    var frameSize: NSSize? {
        NSSize(width: 700, height: 450)
    }
    
    var minSize: NSSize {
        NSSize(width: 400, height: 350)
    }
    
    var maxSize: NSSize {
        NSSize(width: 1100, height: 800)
    }
    
}
