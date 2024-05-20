import SwiftUI

struct TeXScannerDropZone: View {
    
    @State private var dropInRegion = false
    
    let dismissWithImage: (NSImage) -> Void
    
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
            .foregroundStyle(dropInRegion ? Color.accentColor : .gray)
            .animation(.easeInOut, value: dropInRegion)
            .contentShape(Rectangle())
            .onTapGesture {
                Task {
                    if let image = chooseImage() {
                        dismissWithImage(image)
                    }
                }
            }
            .onDrop(of: [.png, .jpeg], isTargeted: $dropInRegion) { providers in
                handleImageDrop(from: providers) { image in
                    DispatchQueue.main.async {
                        dismissWithImage(image)
                    }
                }
            }
            .padding(geometry.size.width * 0.05)
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }
    
}

extension TeXScannerDropZone: Presentable {
    
    var frameSize: NSSize? {
        NSSize(width: 300, height: 200)
    }
    
    var constraintsEnabled: Bool {
        return false
    }
    
}
