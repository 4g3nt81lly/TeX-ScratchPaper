import SwiftUI
import SwiftUIIntrospect

/**
 SwiftUI view for the bookmarks pane.
 
 1. Displays and manages (but does not store) the bookmarks.
 2. Handles adding/editing/deleting bookmarks.
 */
struct BookmarksPane: View {
    
    /**
     Observed reference to the document content object.
     
     Changes made to bookmarks are published and observed by the `BookmarksPane` view, which makes changes to
     the bookmarks via this reference.
     */
    @ObservedObject var documentContent: FileContent
    
    /**
     The observed internal states shared by ``EditorVC`` and ``BookmarksPane``.
     
     The encapsulating hosting controller ``BookmarksController`` holds a reference to this observed object to
     provide ``EditorVC`` (and any other external classes) access to certain states of the bookmarks pane,
     e.g. selected bookmarks, whether the bookmark editor should present, whether an alert for bookmark
     deletion should present.
     */
    @ObservedObject var states = BookmarksController.States()
    
    /**
     A computed reference to the editor in which the bookmarks pane is installed.
     
     This reference is used to send messages to the editor only and should only be used to access members
     relevant to bookmarks.
     */
    var editor: EditorVC {
        return documentContent.document.editor
    }
    
    var body: some View {
        VStack {
            if (documentContent.bookmarks.isEmpty) {
                Spacer()
                HStack {
                    Spacer()
                    Text("No bookmark")
                    Spacer()
                }
                Spacer()
            } else {
                mainListView()
            }
        }
        .sheet(isPresented: $states.bookmarkIsEditing) {
            BookmarkEditor(for: states.newBookmark ?? states.selectedBookmark!,
                           isNew: (states.newBookmark != nil)) { bookmark in
                if let bookmark {
                    states.selectedBookmarks = [bookmark]
                    states.completionHandler?([bookmark])
                }
                states.newBookmark = nil
                states.completionHandler = nil
            }
        }
        .alert(Text("Delete Bookmark"), isPresented: $states.bookmarksWillDelete) {
            Button {
                withAnimation {
                    let selectedBookmarks = Array(states.selectedBookmarks)
                    states.selectedBookmarks = []
                    states.completionHandler!(selectedBookmarks)
                }
            } label: {
                Text("Yes")
            }
            .keyboardShortcut(.defaultAction)
            Button {
                states.completionHandler = nil
                states.bookmarksWillDelete = false
            } label: {
                Text("Cancel")
            }
            .keyboardShortcut(.cancelAction)
        } message: {
            Text("Are you sure you want to delete the selected bookmark(s)?")
        }
    }
    
    @ViewBuilder
    private func mainListView() -> some View {
        List(selection: $states.selectedBookmarks) {
            ForEach($documentContent.bookmarks.elements) { item in
                bookmarkItem(item.wrappedValue).tag(item.wrappedValue)
            }
            .onMove { from, to in
                withAnimation {
                    documentContent.moveBookmark(at: from, to: to)
                }
            }
        }
        .onDeleteCommand {
            // onDelete is not available on macOS
            // reference: https://stackoverflow.com/a/74765563/10446972
            editor.deleteSelectedBookmarks()
        }
        .listStyle(.sidebar)
        .frame(minWidth: 150)
        .introspect(.list, on: .macOS(.v13, .v14)) { tableView in
            if (self.states.bookmarkListTableView != tableView) {
                self.states.bookmarkListTableView = tableView
            }
        }
    }
    
    @ViewBuilder
    private func bookmarkItem(_ item: Bookmark) -> some View {
        HStack(alignment: .top) {
            Image(systemName: item.icon)
                .font(.headline)
            VStack(alignment: .leading) {
                Text(item.name)
                    .fixedSize(horizontal: false, vertical: true)
                    .font(.system(size: 12))
                    .help(item.name)
                Text(item.description)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(.max)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .help(item.description)
            }
        }
        .contextMenu {
            let singleOrNoSelection = (states.selectedBookmarks.count <= 1)
            if (singleOrNoSelection) {
                revealButton(for: item)
            }
            selectButton(for: item, multiselect: true)
            Divider()
            if (singleOrNoSelection) {
                editButton(for: item)
            }
            deleteButton(for: item, multiselect: true)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            editButton(for: item)
                .tint(.orange)
            deleteButton(for: item, multiselect: false)
                .tint(.red)
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            revealButton(for: item)
                .tint(.green)
            selectButton(for: item, multiselect: false)
                .tint(.blue)
        }
    }
    
    /**
     Reusable edit button for contextual menu and swipe actions.
     
     - Parameter bookmark: The sender bookmark entry.
     
     - Returns: An actionable edit button.
     */
    @ViewBuilder
    private func editButton(for bookmark: Bookmark) -> some View {
        Button {
            // row action is received, disable tap to reveal for once
            states.tapToReveal = false
            states.selectedBookmarks = [bookmark]
            editor.editSelectedBookmark()
        } label: {
            Label("Edit…", systemImage: "pencil.circle")
        }
    }
    
    /**
     Reusable delete button for contextual menu and swipe actions.
     
     - Parameter bookmark: The sender bookmark entry.
     
     - Returns: An actionable delete button.
     */
    @ViewBuilder
    private func deleteButton(for bookmark: Bookmark, multiselect: Bool) -> some View {
        Button {
            // row action is received, disable tap to reveal for once
            states.tapToReveal = false
            if (!multiselect || !states.selectedBookmarks.contains(bookmark)) {
                states.selectedBookmarks = [bookmark]
            }
            editor.deleteSelectedBookmarks()
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }
    
    /**
     Reusable reveal button for contextual menu and swipe actions.
     
     - Parameter bookmark: The sender bookmark entry.
     
     - Returns: An actionable reveal button.
     */
    @ViewBuilder
    private func revealButton(for bookmark: Bookmark) -> some View {
        Button {
            // row action is received, disable tap to reveal for once
            states.tapToReveal = false
            states.selectedBookmarks = [bookmark]
            editor.revealSelectedBookmark()
        } label: {
            Label("Reveal", systemImage: "arrowshape.turn.up.right.circle.fill")
        }
    }
    
    /**
     Reusable select button for contextual menu and swipe actions.
     
     - Parameter bookmark: The sender bookmark entry.
     
     - Returns: An actionable select button.
     */
    @ViewBuilder
    private func selectButton(for bookmark: Bookmark, multiselect: Bool) -> some View {
        Button {
            // row action is received, disable tap to reveal for once
            states.tapToReveal = false
            if (!multiselect || !states.selectedBookmarks.contains(bookmark)) {
                states.selectedBookmarks = [bookmark]
            }
            editor.selectBookmarkRanges()
        } label: {
            Label("Select", systemImage: "selection.pin.in.out")
        }
    }
    
}

extension BookmarksPane: Presentable {
    
    var constraintsEnabled: Bool {
        return false
    }
    
    var viewController: NSHostingController<BookmarksPane> {
        let viewController = BookmarksController(rootView: self)
        viewController.view.translatesAutoresizingMaskIntoConstraints = false
        return viewController
    }
    
}
