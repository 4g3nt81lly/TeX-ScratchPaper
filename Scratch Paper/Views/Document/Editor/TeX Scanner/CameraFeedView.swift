import SwiftUI
import AVFoundation

struct CameraFeedView: NSViewRepresentable {
    
    private let session: AVCaptureSession
    
    private class FeedLayerView: NSView {
        
        init(session: AVCaptureSession) {
            super.init(frame: .zero)
            let previewLayer = AVCaptureVideoPreviewLayer(session: session)
            previewLayer.videoGravity = .resizeAspectFill
            layer = previewLayer
            wantsLayer = true
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
    }
    
    init(from session: AVCaptureSession) {
        self.session = session
    }
    
    func makeNSView(context: Context) -> NSView {
        return FeedLayerView(session: session)
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        
    }
    
}
