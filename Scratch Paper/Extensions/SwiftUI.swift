import SwiftUI

extension View {
    
    /**
     Conditionally applies the given transformation, analogous to an `if, else if, else` block.
     
     - Parameters:
        - condition: The initial condition to evaluate.
        - transform: The transformation to apply when the condition is `true`.
        - else: The transformation to apply when none of the conditions are `true`.
        - elif: Else if clauses in pairs of condition and transformation to apply.
     
     - Returns: Either the original `View` or the conditionally transformed `View`.
     */
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, _ transform: (Self) -> Content,
                             else: ((Self) -> Content)? = nil,
                             elif: (Bool, (Self) -> Content)...) -> some View {
        if (condition) {
            transform(self)
        } else if (!elif.isEmpty) {
            var finished = false
            let conditionArray: [Bool] = Array(elif).map { $0.0 }
            let blockArray = Array(elif).map { (_, clause) in
                return { (_ view: Self) -> Content in
                    if (!finished) {
                        finished = true
                        return clause(self)
                    }
                    return self as! Content
                }
            }
            ForEach(0..<elif.count, id: \.self) { index in
                if (conditionArray[index]) {
                    blockArray[index](self)
                }
            }
        } else if let `default` = `else` {
            `default`(self)
        } else {
            self
        }
    }
    
    @ViewBuilder
    func onLoad(_ callback: @escaping () -> Void) -> some View {
        modifier(ViewDidLoadModifier(callback))
    }
    
}

fileprivate struct ViewDidLoadModifier: ViewModifier {
    
    @State private var viewDidLoad = false
    
    private let callback: () -> Void
    
    init(_ callback: @escaping () -> Void) {
        self.callback = callback
    }
    
    func body(content: Content) -> some View {
        content.onAppear {
            guard !viewDidLoad else {
                return
            }
            callback()
            viewDidLoad = true
        }
    }
    
}

protocol Presentable: View {
    
    var frameSize: NSSize? { get }
    
    var constraintsEnabled: Bool { get }
    
    var minSize: NSSize { get }
    
    var maxSize: NSSize { get }
    
    var viewController: NSHostingController<Self> { get }
    
}

extension Presentable {
    
    var frameSize: NSSize? {
        return nil
    }
    
    var constraintsEnabled: Bool {
        return true
    }
    
    var minSize: NSSize {
        return .zero
    }
    
    var maxSize: NSSize {
        return .zero
    }
    
    var viewController: NSHostingController<Self> {
        let viewController = NSHostingController(rootView: self)
        
        if (constraintsEnabled) {
            viewController.view.translatesAutoresizingMaskIntoConstraints = false
            viewController.view.widthAnchor
                .constraint(greaterThanOrEqualToConstant: minSize.width).isActive = true
            viewController.view.widthAnchor
                .constraint(lessThanOrEqualToConstant: maxSize.width).isActive = true
            viewController.view.heightAnchor
                .constraint(greaterThanOrEqualToConstant: minSize.height).isActive = true
            viewController.view.heightAnchor
                .constraint(lessThanOrEqualToConstant: maxSize.height).isActive = true
        }
        
        if let frameSize {
            viewController.view.setFrameSize(frameSize)
        }
        
        return viewController
    }
    
}

/*
 // reference: https://stackoverflow.com/a/57982560/10446972
 // more: https://github.com/filimo/ReaderTranslator/blob/master/ReaderTranslator/Property%20Wrappers/Published.swift

private var cancellables: Set<AnyCancellable> = []

extension Published {
    // default config
    init(wrappedValue defaultValue: Value, _ key: String) {
        // initialize with initial value
        self.init(initialValue: appSettings.value(forKey: key) as! Value)
        projectedValue.sink { value in
            // update settings
            appSettings.setValue(value, forKey: key)
        }.store(in: &cancellables)
    }
}
 */

extension Color {
    
    static let darkAqua = Color(red: 0.125, green: 0.125, blue: 0.125)
    
    /**
     The hex string of the receiver color.
     
     Reference: [](https://blog.eidinger.info/from-hex-to-color-and-back-in-swiftui).
     
     - Precondition: This property is non-`nil` if and only if the receiver color uses RGB or RGBA
     color space.
     
     */
    var hex: String? {
        let color = NSColor(self)
        guard let components = color.cgColor.components,
              components.count >= 3 else { return nil }
        
        let r = Float(components[0])
        let g = Float(components[1])
        let b = Float(components[2])
        var a = Float(1.0)

        if (components.count >= 4) {
            a = Float(components[3])
        }

        if (a != Float(1.0)) {
            return String(format: "%02lX%02lX%02lX%02lX",
                          lroundf(r * 255), lroundf(g * 255), lroundf(b * 255), lroundf(a * 255))
        }
        return String(format: "%02lX%02lX%02lX",
                      lroundf(r * 255), lroundf(g * 255), lroundf(b * 255))
    }
    
    /**
     Initializes the `Color` object using a hex string.
     
     A failable initializer is in place to expose an error when failing to load a color using the
     given hex string, which, in theory, should be impossible when the hex string is valid.
     
     - Precondition: This initializer will only succeed if and only if the receiver color uses RGB
     or RGBA color space and the given hex string is valid.
     
     */
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0

        var r: CGFloat = 0.0
        var g: CGFloat = 0.0
        var b: CGFloat = 0.0
        var a: CGFloat = 1.0

        let length = hexSanitized.count

        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        if (length == 6) {
            r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
            g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
            b = CGFloat(rgb & 0x0000FF) / 255.0
        } else if (length == 8) {
            r = CGFloat((rgb & 0xFF000000) >> 24) / 255.0
            g = CGFloat((rgb & 0x00FF0000) >> 16) / 255.0
            b = CGFloat((rgb & 0x0000FF00) >> 8) / 255.0
            a = CGFloat(rgb & 0x000000FF) / 255.0
        } else {
            return nil
        }

        self.init(red: r, green: g, blue: b, opacity: a)
    }
}
