import SwiftUI

extension View {
    
    func croppable(normalizedCropRect: Binding<CGRect>) -> some View {
        self.overlay {
            CropBox(normalizedCropRect: normalizedCropRect)
        }
    }
    
}

fileprivate struct CropBox: View {
    
    @Binding var normalizedCropRect: CGRect
    
    @State private var temporaryCropRect: CGRect?
    
    @State private var dragOffset: CGSize = .zero
    
    @State private var dashPhase: CGFloat = .zero
    
    enum PinAnchor: String, Identifiable {
        case topLeading, topCenter, topTrailing
        case centerLeading, centerTrailing
        case bottomLeading, bottomCenter, bottomTrailing
        
        static let anchors: [[PinAnchor]] = [
            [.topLeading, .topCenter, .topTrailing],
            [.centerLeading, .centerTrailing],
            [.bottomLeading, .bottomCenter, .bottomTrailing]
        ]
        
        var id: String {
            return rawValue
        }
        
        var cursor: NSCursor {
            switch self {
            case .topLeading, .bottomTrailing:
                return .resizeNWSE
            case .topCenter, .bottomCenter:
                return .resizeUpDown
            case .topTrailing, .bottomLeading:
                return .resizeNESW
            case .centerLeading, .centerTrailing:
                return .resizeLeftRight
            }
        }
    }
    
    private func standardize(_ rect: CGRect) -> CGRect {
        if (rect.size.width < 0 || rect.size.height < 0) {
            return CGRect(x: CGFloat.minimum(rect.origin.x + rect.size.width, rect.origin.x),
                          y: CGFloat.minimum(rect.origin.y + rect.size.height, rect.origin.y),
                          width: rect.width, height: rect.height)
        }
        return rect
    }
    
    private func resize(_ anchor: PinAnchor, with value: DragGesture.Value,
                        relativeTo imageGeometry: GeometryProxy) {
        let maxDeltaX = imageGeometry.size.width - value.startLocation.x
        let minDeltaX = -value.startLocation.x
        let maxDeltaY = imageGeometry.size.height - value.startLocation.y
        let minDeltaY = -value.startLocation.y
        
        let normalizedTranslation = CGSize(
            width: value.translation.width
                .within(interval: (minDeltaX, maxDeltaX)) / imageGeometry.size.width,
            height: value.translation.height
                .within(interval: (minDeltaY, maxDeltaY)) / imageGeometry.size.height
        )
        
        var cropRect = normalizedCropRect
        
        switch anchor {
        case .topLeading:
            cropRect.translate(deltaX: normalizedTranslation.width,
                               deltaY: normalizedTranslation.height)
            cropRect.resize(deltaWidth: -normalizedTranslation.width,
                            deltaHeight: -normalizedTranslation.height)
        case .topCenter:
            cropRect.translate(deltaX: 0, deltaY: normalizedTranslation.height)
            cropRect.resize(deltaWidth: 0, deltaHeight: -normalizedTranslation.height)
        case .topTrailing:
            cropRect.translate(deltaX: 0, deltaY: normalizedTranslation.height)
            cropRect.resize(deltaWidth: normalizedTranslation.width,
                            deltaHeight: -normalizedTranslation.height)
        case .centerLeading:
            cropRect.translate(deltaX: normalizedTranslation.width, deltaY: 0)
            cropRect.resize(deltaWidth: -normalizedTranslation.width, deltaHeight: 0)
        case .centerTrailing:
            cropRect.resize(deltaWidth: normalizedTranslation.width, deltaHeight: 0)
        case .bottomLeading:
            cropRect.translate(deltaX: normalizedTranslation.width, deltaY: 0)
            cropRect.resize(deltaWidth: -normalizedTranslation.width,
                            deltaHeight: normalizedTranslation.height)
        case .bottomCenter:
            cropRect.resize(deltaWidth: 0, deltaHeight: normalizedTranslation.height)
        case .bottomTrailing:
            cropRect.resize(deltaWidth: normalizedTranslation.width,
                            deltaHeight: normalizedTranslation.height)
        }
        
        temporaryCropRect = cropRect
    }
    
    @ViewBuilder
    private func cropPin(_ anchor: PinAnchor, _ imageGeometry: GeometryProxy) -> some View {
        Circle()
            .stroke(.white)
            .background(Circle().foregroundStyle(.blue))
            .frame(width: 8, height: 8)
            .onHover { isHovering in
                if (isHovering) {
                    anchor.cursor.push()
                } else {
                    NSCursor.pop()
                }
            }
            .gesture(
                DragGesture(coordinateSpace: .global)
                    .onChanged { value in
                        resize(anchor, with: value, relativeTo: imageGeometry)
                    }
                    .onEnded { value in
                        normalizedCropRect = standardize(temporaryCropRect!)
                        temporaryCropRect = nil
                    }
            )
    }
    
    @ViewBuilder
    private func cropPinOverlay(_ width: CGFloat, _ height: CGFloat,
                                _ imageGeometry: GeometryProxy) -> some View {
        ForEach(0..<3) { column in
            cropPin(PinAnchor.anchors[0][column], imageGeometry)
                .offset(x: CGFloat(column) * (width / 2))
        }
        ForEach(0..<2) { column in
            cropPin(PinAnchor.anchors[1][column], imageGeometry)
                .offset(x: CGFloat(column) * width, y: height / 2)
        }
        ForEach(0..<3) { column in
            cropPin(PinAnchor.anchors[2][column], imageGeometry)
                .offset(x: CGFloat(column) * (width / 2), y: height)
        }
    }
    
    private func createCropRectGesture(_ imageGeometry: GeometryProxy) -> _EndedGesture<_ChangedGesture<DragGesture>> {
        DragGesture(minimumDistance: 20)
            .onChanged { value in
                // constraints for drag translation so that crop box is always within bounds
                let maxDeltaX = imageGeometry.size.width - value.startLocation.x
                let minDeltaX = -value.startLocation.x
                let maxDeltaY = imageGeometry.size.height - value.startLocation.y
                let minDeltaY = -value.startLocation.y
                // normalize translation and position to preserve the scale for crop box
                let normalizedPosition = CGPoint(
                    x: value.startLocation.x / imageGeometry.size.width,
                    y: value.startLocation.y / imageGeometry.size.height
                )
                let normalizedSize = CGSize(
                    width: value.translation.width
                        .within(interval: (minDeltaX, maxDeltaX)) / imageGeometry.size.width,
                    height: value.translation.height
                        .within(interval: (minDeltaY, maxDeltaY)) / imageGeometry.size.height
                )
                let normalizedTranslation = CGRect(origin: normalizedPosition,
                                                   size: normalizedSize)
                temporaryCropRect = standardize(normalizedTranslation)
            }
            .onEnded { value in
                withAnimation {
                    normalizedCropRect = temporaryCropRect!
                    temporaryCropRect = nil
                }
            }
    }
    
    private func translationGesture(_ imageGeometry: GeometryProxy) -> _EndedGesture<_ChangedGesture<DragGesture>> {
        DragGesture(minimumDistance: 1, coordinateSpace: .global)
            .onChanged { value in
                let maxDeltaX = 1 - normalizedCropRect.maxX
                let minDeltaX = -normalizedCropRect.minX
                let maxDeltaY = 1 - normalizedCropRect.maxY
                let minDeltaY = -normalizedCropRect.minY
                
                let constrainedTranslation = CGSize(
                    width: (value.translation.width / imageGeometry.size.width)
                        .within(interval: (minDeltaX, maxDeltaX)) * imageGeometry.size.width,
                    height: (value.translation.height / imageGeometry.size.height)
                        .within(interval: (minDeltaY, maxDeltaY)) * imageGeometry.size.height
                )
                
                dragOffset = constrainedTranslation
            }
            .onEnded { value in
                normalizedCropRect.translate(deltaX: dragOffset.width / imageGeometry.size.width,
                                             deltaY: dragOffset.height / imageGeometry.size.height)
                dragOffset = .zero
            }
    }
    
    var body: some View {
        GeometryReader { imageGeometry in
            ZStack(alignment: .topLeading) {
                Color.clear
                    .onHover { isHovering in
                        if (isHovering) {
                            NSCursor.crosshair.push()
                        } else {
                            NSCursor.pop()
                        }
                    }
                    .gesture(createCropRectGesture(imageGeometry))
                    .onTapGesture {
                        withAnimation {
                            normalizedCropRect = .zero
                        }
                    }
                
                let cropRect = temporaryCropRect ?? normalizedCropRect
                if (cropRect.width * cropRect.height > 0) {
                    let size = CGSize(width: cropRect.width * imageGeometry.size.width,
                                      height: cropRect.height * imageGeometry.size.height)
                    let position = CGPoint(x: cropRect.midX * imageGeometry.size.width,
                                           y: cropRect.midY * imageGeometry.size.height)
                    
                    Rectangle()
                        .strokeBorder(style: StrokeStyle(lineWidth: 1.25, dash: [5], dashPhase: dashPhase))
                        // must be before setting frame, otherwise the hover region is the entire image
                        .contentShape(Rectangle())
                        .onHover { isHovering in
                            if (isHovering) {
                                NSCursor.openHand.push()
                            } else {
                                NSCursor.pop()
                            }
                        }
                        .frame(width: size.width, height: size.height)
                        .position(position)
                        .overlay(alignment: .topLeading) {
                            cropPinOverlay(size.width, size.height, imageGeometry)
                                .position(x: position.x - size.width / 2,
                                          y: position.y - size.height / 2)
                        }
                        .gesture(translationGesture(imageGeometry))
                        .onAppear {
                            withAnimation(.linear.repeatForever(autoreverses: false)) {
                                dashPhase += 10
                            }
                        }
                        .offset(dragOffset)
                }
            }
        }
    }
    
}

