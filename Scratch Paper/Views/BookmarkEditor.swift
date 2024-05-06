import SwiftUI

/**
 SwiftUI View for the bookmark editor.
 
 1. Adds/Edits a bookmark.
 */
struct BookmarkEditor: View {
    
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    
    /**
     A weak reference to the editor view.
     
     This property can also be used to tell if the bookmark editor is for adding bookmark or editing
     a selected bookmark. If the property is `nil`, then it implies that the bookmark editor is
     presented by `BookmarksPane` view, otherwise, `EditorVC` view.
     */
    weak var editor: EditorVC?
    
    /**
     Observed reference to file content object.
     
     `BookmarkEditor` makes changes to the bookmarks via this reference.
     */
    @ObservedObject var fileObject: FileContent
    
    /**
     A cancellable new/edited entry.
     
     This is a copy of the bookmark to be edited, or the bookmark to be added. This property is
     discarded when the cancels the adding/editing operation.
     */
    @State var newEntry: BookmarkEntry
    
    /**
     Set this state property to `true` to present the symbol picker.
     
     This property is essentially inaccessible from outside as the instance is a value-type object
     which is always copy-on-reference, might as well just make it private.
     
     - Warning: This property should not be changed unless the user clicks on the icon well.
     */
    @State private var symbolPickerPresented = false
    
    /**
     Handles the bookmark saving and dismisses the bookmark editor.
     
     Bookmarks with their names left blank will be marked unnamed and given an appropriate counter
     for display in the `List` view.
     */
    func saveEntry() {
        if newEntry.name.trimmingCharacters(in: .whitespaces) == "" {
            // unnamed
            newEntry.unnamed = true
            
            let existingCounters = fileObject.bookmarks.compactMap({ bookmark in
                if bookmark.unnamed {
                    let components = bookmark.name.components(separatedBy: "Unnamed Bookmark ")
                    return components.count == 1 ? 0 : Int(components.last!)!
                }
                return nil
            })
            let unnamedCounter = (existingCounters.max() ?? -1) + 1
            let placeholderName = "Unnamed Bookmark\(unnamedCounter > 0 ? " \(unnamedCounter)" : "")"
            
            newEntry.name = placeholderName
        } else {
            // named
            newEntry.unnamed = false
        }
        if let _ = editor {
            // adding an entry
            fileObject.bookmarks.append(newEntry)
        } else {
            // editing an entry
            if let index = fileObject.bookmarks.firstIndex(where: { $0.id == newEntry.id }) {
                fileObject.bookmarks[index] = newEntry
            }
        }
        // select the new entry
        fileObject.selectedBookmark = newEntry
        
        // conditionally dismiss the editor
        if let editor = editor {
            editor.bookmarkEditor.dismiss(nil)
            editor.sidebar.navigate(to: .bookmarks)
            editor.bookmarkEditor = nil
        } else {
            dismiss()
        }
    }

    var body: some View {
        VStack {
            HStack {
                VStack(alignment: .leading) {
                    Text("\(editor == nil ? "Edit" : "Add") Bookmark")
                        .fontWeight(.semibold)
                    HStack {
                        Text("Name:")
                            .padding(.leading, 44)
                        TextField(text: $newEntry.name) {
                            Text("Name")
                        }
                        .onAppear {
                            if newEntry.unnamed {
                                newEntry.name = ""
                            }
                        }
                        .onSubmit {
                            saveEntry()
                        }
                    }
                    HStack {
                        Text("Description:")
                            .padding(.leading, 10)
                        TextField(text: $newEntry.description) {
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
                    Image(systemName: newEntry.iconName)
                        .font(.largeTitle)
                        .padding(15)
                        .background(colorScheme == .light ? .white : .darkAqua)
                        .overlay(
                            Circle()
                                .stroke(colorScheme == .light ? .white : .darkAqua, lineWidth: 1)
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
                    SymbolPicker(symbol: $newEntry.iconName)
                }
            }
            HStack {
                Button {
                    if let editor = editor {
                        editor.bookmarkEditor.dismiss(nil)
                    } else {
                        dismiss()
                    }
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
}
