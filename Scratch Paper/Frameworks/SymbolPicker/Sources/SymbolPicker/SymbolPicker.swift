//
//  SymbolPicker.swift
//  SymbolPicker
//
//  Created by Yubo Qin on 2/14/22.
//

import SwiftUI

import AppKit

public struct SymbolPicker: View {

    // MARK: - Static constants

    private static let symbols: [String] = {
        guard let path = Bundle.module.path(forResource: "sfsymbols", ofType: "txt"),
              let content = try? String(contentsOfFile: path)
        else {
            return []
        }
        return content
            .split(separator: "\n")
            .map { String($0) }
    }()

    private static var gridDimension: CGFloat {
        return 30
    }

    private static var symbolSize: CGFloat {
        return 14
    }

    private static var symbolCornerRadius: CGFloat {
        return 4
    }

    public static var systemGray5: Color {
        dynamicColor(
            light: .init(red: 0.9, green: 0.9, blue: 0.92, alpha: 1.0),
            dark: .init(red: 0.17, green: 0.17, blue: 0.18, alpha: 1.0)
        )
    }

    public static var systemBackground: Color {
        dynamicColor(
            light: .init(red: 1, green: 1, blue: 1, alpha: 1.0),
            dark: .init(red: 0.125, green: 0.125, blue: 0.125, alpha: 1.0)
        )
    }

    public static var secondarySystemBackground: Color {
        dynamicColor(
            light: .init(red: 0.95, green: 0.95, blue: 1, alpha: 1.0),
            dark: .controlBackgroundColor
        )
    }

    // MARK: - Properties

    @Binding public var symbol: String
    @State private var searchText = ""
    @Environment(\.presentationMode) private var presentationMode

    // MARK: - Public Init

    public init(symbol: Binding<String>) {
        _symbol = symbol
    }

    // MARK: - View Components

    @ViewBuilder
    private var searchableSymbolGrid: some View {
        VStack(spacing: 10) {
            TextField(LocalizedString("search_placeholder"), text: $searchText)
                .disableAutocorrection(true)
            symbolGrid
        }
    }

    private var symbolGrid: some View {
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

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(LocalizedString("sf_symbol_picker"))
                .font(.headline)
            searchableSymbolGrid
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .focusable(false)
            Divider()
            HStack {
                Button {
                    presentationMode.wrappedValue.dismiss()
                } label: {
                    Text(LocalizedString("cancel"))
                        .padding(.horizontal, 5)
                }
                .keyboardShortcut(.cancelAction)
                .focusable(false)
                Spacer()
                Button {
                    presentationMode.wrappedValue.dismiss()
                } label: {
                    Text(LocalizedString("done"))
                        .padding(.horizontal, 8)
                }
                .keyboardShortcut(.defaultAction)
                .focusable(false)
            }
        }
        .padding()
        .frame(width: 520, height: 300, alignment: .center)
    }

    // MARK: - Private helpers

    private static func dynamicColor(light: NSColor, dark: NSColor) -> Color {
        let color = NSColor(name: nil) { $0.name == .darkAqua ? dark : light }
        if #available(macOS 12.0, *) {
            return Color(nsColor: color)
        }
        return Color(color)
    }

}

private func LocalizedString(_ key: String) -> String {
    NSLocalizedString(key, bundle: .module, comment: "")
}

struct SymbolPicker_Previews: PreviewProvider {
    @State static var symbol: String = "square.and.arrow.up"

    static var previews: some View {
        Group {
            SymbolPicker(symbol: Self.$symbol)
            SymbolPicker(symbol: Self.$symbol)
                .preferredColorScheme(.dark)
        }
    }
}
