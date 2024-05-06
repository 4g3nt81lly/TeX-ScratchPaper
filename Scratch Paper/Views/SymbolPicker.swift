// Reference: https://github.com/xnth97/SymbolPicker

import Cocoa
import SwiftUI

struct SymbolPicker: View {

    // MARK: - Static constants

    static let symbols: [String] = {
        guard let path = Bundle.main.path(forResource: "symbols", ofType: "txt"),
              let content = try? String(contentsOfFile: path) else {
            return []
        }
        return content.split(separator: "\n").map({ String($0) })
    }()

    static var gridDimension: CGFloat = 30

    static var symbolSize: CGFloat = 14

    static var symbolCornerRadius: CGFloat = 4

    static var systemBackground: Color {
        dynamicColor(
            light: .init(red: 1, green: 1, blue: 1, alpha: 1.0),
            dark: .init(red: 0.125, green: 0.125, blue: 0.125, alpha: 1.0)
        )
    }

    // MARK: - Properties

    @Binding var symbol: String
    @State var searchText = ""
    @Environment(\.presentationMode) var presentationMode

    // MARK: - Init

    init(symbol: Binding<String>) {
        _symbol = symbol
    }

    // MARK: - View Components

    @ViewBuilder
    var searchableSymbolGrid: some View {
        VStack(spacing: 10) {
            TextField("Search", text: $searchText)
                .disableAutocorrection(true)
            symbolGrid
        }
    }

    var symbolGrid: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: Self.gridDimension, maximum: Self.gridDimension))]) {
                ForEach(Self.symbols.filter { searchText.isEmpty ? true : $0.localizedCaseInsensitiveContains(searchText) }, id: \.self) { thisSymbol in
                    Button(action: {
                        symbol = thisSymbol
                    }) {
                        if thisSymbol == symbol {
                            Image(systemName: thisSymbol)
                                .font(.system(size: Self.symbolSize))
                                .frame(maxWidth: .infinity, minHeight: Self.gridDimension)
                                .background(Color.accentColor)
                                .cornerRadius(Self.symbolCornerRadius)
                                .foregroundColor(.white)
                        } else {
                            Image(systemName: thisSymbol)
                                .font(.system(size: Self.symbolSize))
                                .frame(maxWidth: .infinity, minHeight: Self.gridDimension)
                                .background(Self.systemBackground)
                                .cornerRadius(Self.symbolCornerRadius)
                                .foregroundColor(.primary)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Select a symbol:")
                .font(.headline)
            searchableSymbolGrid
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .focusable(false)
            Divider()
            HStack {
                Button {
                    presentationMode.wrappedValue.dismiss()
                } label: {
                    Text("Cancel")
                        .padding(.horizontal, 5)
                }
                .keyboardShortcut(.cancelAction)
                .focusable(false)
                Spacer()
                Button {
                    presentationMode.wrappedValue.dismiss()
                } label: {
                    Text("Done")
                        .padding(.horizontal, 8)
                }
                .keyboardShortcut(.defaultAction)
                .focusable(false)
            }
        }
        .padding()
        .frame(width: 520, height: 300, alignment: .center)
    }

    // MARK: - helpers

    static func dynamicColor(light: NSColor, dark: NSColor) -> Color {
        let color = NSColor(name: nil) { $0.name == .darkAqua ? dark : light }
        if #available(macOS 12.0, *) {
            return Color(nsColor: color)
        }
        return Color(color)
    }

}
