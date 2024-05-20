import SwiftUI

/**
 SwiftUI View for the bookmark editor.
 
 1. Adds/Edits a bookmark.
 */
struct BookmarkEditor: View {
    
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    
    @State private var name: String
    
    @State private var description: String
    
    @State var iconName: String
    
    let bookmark: Bookmark
    
    let isNew: Bool
    
    let responseHandler: (Bookmark?) -> Void
    
    /**
     Set this state property to `true` to present the symbol picker.
     
     This property is essentially inaccessible from outside as the instance is a value-type object
     which is always copy-on-reference, might as well just make it private.
     
     - Warning: This property should not be changed unless the user clicks on the icon image well.
     */
    @State private var symbolPickerPresented = false
    
    init(for bookmark: Bookmark, isNew: Bool,
         responseHandler: @escaping (Bookmark?) -> Void) {
        self.name = bookmark.name
        self.description = bookmark.description
        self.iconName = bookmark.icon
        self.bookmark = bookmark
        self.isNew = isNew
        self.responseHandler = responseHandler
    }

    var body: some View {
        VStack {
            HStack {
                VStack(alignment: .leading) {
                    Text("\(isNew ? "Create" : "Edit") Bookmark")
                        .fontWeight(.semibold)
                    HStack {
                        Text("Name:")
                            .padding(.leading, 44)
                        TextField(text: $name) {
                            Text("Name")
                        }
                        .onSubmit {
                            saveEntry()
                        }
                    }
                    HStack {
                        Text("Description:")
                            .padding(.leading, 10)
                        TextField(text: $description) {
                            Text("Description")
                        }
                        .onSubmit {
                            saveEntry()
                        }
                    }
                }
                Button {
                    symbolPickerPresented = true
                } label: {
                    Image(systemName: iconName)
                        .font(.largeTitle)
                        .padding(15)
                        .background((colorScheme == .light) ? .white : .darkAqua)
                        .overlay(
                            Circle()
                                .stroke((colorScheme == .light) ? .white : .darkAqua, lineWidth: 1)
                                .shadow(color: .gray, radius: 3)
                                .clipShape(Circle())
                        )
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .focusable(false)
                .frame(minWidth: 60, minHeight: 60)
                .padding(EdgeInsets(top: 0, leading: 10, bottom: 0, trailing: 5))
                .sheet(isPresented: $symbolPickerPresented) {
                    SymbolPicker(symbol: $iconName)
                }
            }
            HStack {
                Button {
                    responseHandler(nil)
                    dismiss()
                } label: {
                    Text("Cancel")
                        .frame(width: 55)
                }
                .keyboardShortcut(.cancelAction)
                Spacer()
                Button {
                    saveEntry()
                } label: {
                    Text("Save")
                        .frame(width: 50)
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .frame(minWidth: 400, maxWidth: 700)
        .padding()
    }
    
    /**
     Handles the bookmark saving and dismisses the bookmark editor.
     
     Bookmarks with their names left blank will be marked unnamed and given an appropriate counter
     for display in the `List` view.
     */
    private func saveEntry() {
        if (name.trimmingCharacters(in: .whitespaces).isEmpty) {
            name = "Unnamed Bookmark"
        }
        if (name != bookmark.name || description != bookmark.description
                || iconName != bookmark.icon) {
            var bookmark = bookmark
            bookmark.name = name
            bookmark.description = description
            bookmark.icon = iconName
            responseHandler(bookmark)
        } else {
            responseHandler(nil)
        }
        dismiss()
    }
    
}
