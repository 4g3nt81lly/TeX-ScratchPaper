//
//  TeXScannerView.swift
//  Scratch Paper
//
//  Created by Bingyi Li on 2024-05-07.
//

import SwiftUI

struct TeXScannerView: View {
    
    @StateObject private var manager = CameraManager()
    
    @State private var capturedImage: NSImage?
    
    @State private var normalizedCropRect: CGRect = .zero
    
    let dismiss: (NSImage?) -> Void
    
    @ViewBuilder
    private func cameraFeedView(_ geometry: GeometryProxy) -> some View {
        manager.cameraFeedView
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        VStack {
            HStack {
                Picker(selection: $manager.selectedDevice) {
                    if (manager.devices.isEmpty) {
                        Text(CameraManager.Device.invalid.name)
                            .tag(CameraManager.Device.invalid)
                    } else {
                        ForEach(manager.devices, id: \.id) { device in
                            Text(device.name).tag(device)
                        }
                    }
                } label: {}
                Spacer()
            }
            Spacer()
            HStack {
                Button {
                    dismiss(nil)
                    manager.endSession()
                } label: {
                    Text("Cancel")
                }
                .keyboardShortcut(.cancelAction)
                Spacer()
                Button {
                    manager.capture { image in
                        if let image {
                            manager.endSession()
                            withAnimation {
                                capturedImage = image
                            }
                        }
                    }
                } label: {
                    Text("Capture")
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(.horizontal, geometry.size.width * 0.03)
        .padding(.vertical, geometry.size.height * 0.04)
    }
    
    private func cropImage() {
        guard (normalizedCropRect != .zero) else { return }
        let image = capturedImage!
        let cropRect = CGRect(x: normalizedCropRect.minX * image.size.width,
                              y: (1 - normalizedCropRect.maxY) * image.size.height,
                              width: normalizedCropRect.width * image.size.width,
                              height: normalizedCropRect.height * image.size.height)
        capturedImage = NSImage(size: cropRect.size, flipped: false) { bound in
            image.draw(in: bound, from: cropRect, operation: .copy, fraction: 1.0)
            return true
        }
    }
    
    @ViewBuilder
    private func imageCropView(_ geometry: GeometryProxy) -> some View {
        Color.clear
            .overlay {
                Image(nsImage: capturedImage!)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .croppable(normalizedCropRect: $normalizedCropRect)
            }
        VStack(spacing: 0) {
            Spacer()
            HStack {
                Button {
                    withAnimation {
                        capturedImage = nil
                        normalizedCropRect = .zero
                    }
                } label: {
                    Text("Retake")
                }
                .keyboardShortcut(.cancelAction)
                Spacer()
                Button {
                    cropImage()
                    dismiss(capturedImage!)
                } label: {
                    Text((normalizedCropRect != .zero) ? "Crop & Confirm" : "Confirm")
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(.horizontal, geometry.size.width * 0.03)
        .padding(.vertical, geometry.size.height * 0.04)
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .center) {
                if (capturedImage != nil) {
                    imageCropView(geometry)
                } else {
                    cameraFeedView(geometry)
                        .onLoad {
                            Task {
                                await manager.beginSession()
                            }
                        }
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .ignoresSafeArea()
        }
    }
    
}

extension TeXScannerView: Presentable {
    
    var frameSize: NSSize? {
        NSSize(width: NSScreen.main!.frame.width * 0.4,
               height: NSScreen.main!.frame.height * 0.4)
    }
    
    var minSize: NSSize {
        NSSize(width: 450, height: 350)
    }
    
    var maxSize: NSSize {
        NSSize(width: 1100, height: 800)
    }
    
}
