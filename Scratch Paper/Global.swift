//
//  Global.swift
//  Scratch Paper
//
//  Created by Bingyi Billy Li on 2022/7/4.
//

import Cocoa
import SwiftUI
import Combine

/// The application's standard user defaults object.
let userDefaults = UserDefaults.standard

/**
 A strong reference to the application's delegate object `AppDelegate`.
 
 This reference will always be available, allowing the `AppDelegate` object to be accessible at a global scope.
 */
let appDelegate = NSApp.delegate as! AppDelegate

/// The application's default file manager object.
let fileManager = FileManager.default

/// The main storyboard.
let mainStoryboard = NSStoryboard.main!

/// The application's main bundle object.
let mainBundle = Bundle.main

/// An instance of the global environment communication channel.
let global = GlobalChannel()


extension String {
    
    /**
     Counts the occurrences of a pattern within the receiver string.
     
     - Parameter item: A pattern by which a string is counted.
     
     - Returns: The number of occurrences of the given pattern.
     */
    func count(_ item: String) -> Int {
        return self.components(separatedBy: item).count - 1
    }
    
    /**
     Separate the receiver string character by character.
     
     - Returns: An array of separated characters in strings.
     */
    func components() -> [String] {
        var components: [String] = []
        for char in self {
            components.append(String(char))
        }
        return components
    }
    
    /**
     Get a character at an index in the receiver string as string.
     
     Swift does not come with native support to subscript a string, this method does just that by separating the receiver string character by character by invoking `components()` and returning the string element at the given index.
     
     - Precondition: The index must be within the valid range, otherwise this will raise an exception.
     
     - Parameter index: The index of a character.
     
     - Returns: A character at the given index as string.
     */
    subscript(_ index: Int) -> String {
        get {
            let characters = self.components()
            return characters[index]
        }
    }
    
    /**
     Slices the receiver string with a given range.
     
     Along with string subscript, Swift also does not come with native support to slice a string, this method does just that by separating the receiver string character by character by invoking `components()` and returning the joined array slice.
     
     - Precondition: The range must be within the valid range, otherwise this will raise an exception.
     
     - Parameter range: A range for slicing.
     
     - Returns: A substring sliced at the given range as a string.
     */
    subscript(_ range: Range<Int>) -> String {
        get {
            let characters = self.components()
            return characters[range].joined()
        }
    }
    
}

extension Bool {
    
    /// Integer representation of the receiver's value.
    var intValue: Int {
        return self ? 1 : 0
    }
    
}

extension NSNumber {
    
    /// An exact integer value of the `NSNumber` object.
    var intValue: Int? {
        return Int(exactly: self)
    }
    
    /// An exact boolean value of the `NSNumber` object.
    var boolValue: Bool? {
        return Bool(exactly: self)
    }
    
    /// An exact double value of the `NSNumber` object.
    var doubleValue: Double? {
        return Double(exactly: self)
    }
    
}

extension NSString {
    
    /// Swift String value of the `NSString` object.
    var string: String {
        return self as String
    }
    
}

extension Array {
    
    /**
     Counts the number of elements that satisfy a given predicate within the receiver array.
     
     - Parameter predicate: A custom predicate.
     
     - Returns: The number of elements that satisfy the given predicate.
     */
    func count(_ predicate: (Self.Element) -> Bool) -> Int {
        return self.filter(predicate).count
    }
    
}

extension Sequence where Element: Numeric {
    
    /**
     Sums up all the elements by their value in a numeric sequence.
     
     - Returns: The total sum of all the numeric elements.
     */
    func sum() -> Self.Element {
        var sum: Self.Element = .zero
        self.forEach { element in
            sum += element
        }
        return sum
    }
    
}

extension Array where Element == Bool {
    
    /// A boolean value indicating whether any of the array is true.
    var any: Bool {
        return self.contains(true)
    }
    
    /// A boolean value indicating whether all of the array is true.
    var all: Bool {
        return !self.contains(false)
    }
    
}

extension NSWindow {
    
    /// Centers the receiver window to the screen.
    func centerInScreen() {
        if let screenSize = screen?.frame.size {
            let origin = NSPoint(x: (screenSize.width - frame.size.width) / 2, y: (screenSize.height - frame.size.height) / 2)
            self.setFrameOrigin(origin)
        }
    }
    
}

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
        if condition {
            transform(self)
        } else if !elif.isEmpty {
            var finished = false
            let conditionArray: [Bool] = Array(elif).map { $0.0 }
            let blockArray = Array(elif).map { (_, clause) in
                return { (_ view: Self) -> Content in
                    if !finished {
                        finished = true
                        return clause(self)
                    }
                    return self as! Content
                }
            }
            ForEach(0..<elif.count, id: \.self) { index in
                if conditionArray[index] {
                    blockArray[index](self)
                }
            }
        } else if let `default` = `else` {
            `default`(self)
        } else {
            self
        }
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
        self.init(initialValue: appDelegate.settings.value(forKey: key) as! Value)
        projectedValue.sink { value in
            // update settings
            appDelegate.settings.setValue(value, forKey: key)
        }.store(in: &cancellables)
    }
}
 */

extension Color {
    
    static let darkAqua = Color(red: 0.125, green: 0.125, blue: 0.125)
    
    /**
     The hex string of the receiver color.
     
     Reference: [](https://blog.eidinger.info/from-hex-to-color-and-back-in-swiftui).
     
     - Precondition: This property is non-`nil` if and only if the receiver color uses RGB or RGBA color space.
     
     */
    var hex: String? {
        let color = NSColor(self)
        guard let components = color.cgColor.components,
              components.count >= 3 else { return nil }
        
        let r = Float(components[0])
        let g = Float(components[1])
        let b = Float(components[2])
        var a = Float(1.0)

        if components.count >= 4 {
            a = Float(components[3])
        }

        if a != Float(1.0) {
            return String(format: "%02lX%02lX%02lX%02lX", lroundf(r * 255), lroundf(g * 255), lroundf(b * 255), lroundf(a * 255))
        }
        return String(format: "%02lX%02lX%02lX", lroundf(r * 255), lroundf(g * 255), lroundf(b * 255))
    }
    
    /**
     Initializes the `Color` object using a hex string.
     
     A failable initializer is in place to expose an error when failing to load a color using the given hex string, which, in theory, should be impossible when the hex string is valid.
     
     - Precondition: This initializer will only succeed if and only if the receiver color uses RGB or RGBA color space and the given hex string is valid.
     
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

        if length == 6 {
            r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
            g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
            b = CGFloat(rgb & 0x0000FF) / 255.0
        } else if length == 8 {
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
