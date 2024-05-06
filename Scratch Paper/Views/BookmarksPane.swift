import SwiftUI
import SwiftUIIntrospect

/**
 SwiftUI view for the bookmarks pane.
 
 1. Displays and manages (but does not store) the bookmarks.
 2. Handles adding/editing/deleting bookmarks.
 */
struct BookmarksPane: View {
    
    /**
     Observed reference to file content object.
     
     Changes made to bookmarks are published and observed by the `BookmarksPane` view, which make
     changes to the bookmarks via this reference.
     */
    @ObservedObject var fileObject: FileContent
    
    /**
     Set this state property to `true` to present the bookmark editor and edit a selected bookmark.
     
     This property is essentially inaccessible from outside as the instance is a value-type object
     which is always copy-on-reference, might as well just make it private.
     In order to notify `BookmarksPane` to present the bookmark editor on the selected bookmark,
     call `editSelectedBookmark()` from the global channel.
     
     - Warning: Global method `editSelectedBookmark()` should only be invoked after the `BookmarksPane`'s
     `List` view has appeared.
     */
    @State private var bookmarkIsEditing = false
    
    /**
     Set this state property to `true` to notify `BookmarksPane` that the selected bookmark was
     requested for deletion, which subsequently displays a confirmation alert.
     
     This property is essentially inaccessible from outside as the instance is a value-type object
     which is always copy-on-reference, might as well just make it private.
     In order to notify `BookmarksPane` to delete the selected bookmark, call `deleteSelectedBookmark()`
     from the global channel.
     
     - Warning: Global method `deleteSelectedBookmark()` should only be invoked after the
     `BookmarksPane`'s `List` view has appeared.
     */
    @State private var bookmarkWillDelete = false
    
    /**
     A state property indicating whether click-to-reveal feature is enabled.
     
     This property determines whether the global method `bookmarksListClicked(point:doubleClick:)`
     should reveal the clicked bookmark entry in the main text view upon receiving a click gesture
     detected and sent by `BookmarksController`. This property is in place to conditionally disable
     the click-to-reveal feature so that it does not reveal the selected bookmark when the user uses
     the swipe actions.
     
     This property only takes effect once after the swipe actions set it to `false` and is gracefully
     reset to `true` by `bookmarksListClicked(point:doubleClick:)`.
     
     - Warning: This property should **never** be altered boldly.
     */
    @State private var tapToReveal = true
    
    /**
     Reusable edit button for contextual menu and swipe actions.
     
     - Parameter bookmark: The sender bookmark entry.
     
     - Returns: An actionable edit button.
     */
    @ViewBuilder
    private func editButton(for bookmark: Binding<BookmarkEntry>) -> some View {
        Button {
            // row action is received, disable tap to reveal for once
            tapToReveal = false
            
            fileObject.selectedBookmark = bookmark.wrappedValue
            bookmarkIsEditing = true
        } label: {
            Label("Edit...", systemImage: "pencil.circle")
        }
    }
    
    /**
     Reusable delete button for contextual menu and swipe actions.
     
     - Parameter bookmark: The sender bookmark entry.
     
     - Returns: An actionable delete button.
     */
    @ViewBuilder
    private func deleteButton(for bookmark: Binding<BookmarkEntry>) -> some View {
        Button {
            // row action is received, disable tap to reveal for once
            tapToReveal = false
            
            fileObject.selectedBookmark = bookmark.wrappedValue
            bookmarkWillDelete = true
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }
    
    /**
     Reveals the selected bookmark's corresponding ranges in the main text view.
     
     - Parameter bookmark: The bookmark entry to be revealed.
     */
    private func revealBookmarkRanges(_ bookmark: BookmarkEntry) {
        fileObject.selectedBookmark = bookmark
        
        // get aggregate range for multiple ranges
        let revealRange = bookmark.ranges.aggregateRange()
        
        fileObject.document.editor.contentTextView.showFindIndicator(for: revealRange)
    }
    
    /**
     Reusable reveal button for contextual menu and swipe actions.
     
     - Parameter bookmark: The sender bookmark entry.
     
     - Returns: An actionable reveal button.
     */
    @ViewBuilder
    private func revealButton(for bookmark: Binding<BookmarkEntry>) -> some View {
        Button {
            // row action is received, disable tap to reveal for once
            tapToReveal = false
            
            revealBookmarkRanges(bookmark.wrappedValue)
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
    private func selectButton(for bookmark: Binding<BookmarkEntry>) -> some View {
        Button {
            // row action is received, disable tap to reveal for once
            tapToReveal = false
            
            let _bookmark = bookmark.wrappedValue
            fileObject.selectedBookmark = _bookmark
            
            let range = _bookmark.ranges.aggregateRange()
            
            fileObject.document.editor.contentTextView.scrollRangeToCenter(range, animated: true) {
                let textView = fileObject.document.editor.contentTextView
                fileObject.document.editor.view.window!.makeFirstResponder(textView)
                textView!.selectedRanges = _bookmark.ranges as [NSValue]
            }
        } label: {
            Label("Select", systemImage: "selection.pin.in.out")
        }
    }
    
    var body: some View {
        ZStack {
            VStack {
                List(selection: $fileObject.selectedBookmark) {
                    ForEach($fileObject.bookmarks, id: \.self) { entry in
                        HStack(alignment: .top) {
                            Image(systemName: entry.iconName.wrappedValue)
                                .font(.headline)
                            VStack(alignment: .leading) {
                                Text(entry.name.wrappedValue)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .font(.system(size: 12))
                                    .help(entry.name.wrappedValue)
                                Text(entry.description.wrappedValue)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .lineLimit(.max)
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                                    .help(entry.description.wrappedValue)
                            }
                        }
                        .tag(entry.wrappedValue)
                        .contextMenu {
                            revealButton(for: entry)
                            selectButton(for: entry)
                            Divider()
                            editButton(for: entry)
                            deleteButton(for: entry)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true, content: {
                            editButton(for: entry)
                                .tint(.orange)
                            deleteButton(for: entry)
                                .tint(.red)
                        })
                        .swipeActions(edge: .leading, allowsFullSwipe: true, content: {
                            revealButton(for: entry)
                                .tint(.green)
                            selectButton(for: entry)
                                .tint(.blue)
                        })
                    }
                }
                .sheet(isPresented: $bookmarkIsEditing) {
                    BookmarkEditor(fileObject: fileObject, newEntry: fileObject.selectedBookmark!)
                }
                .frame(minWidth: 150)
                .onAppear {
                    // register globally callable methods
                    global.registerFunction(withName: "editSelectedBookmark", { (_) -> Any? in
                        self.bookmarkIsEditing = true
                    })
                    global.registerFunction(withName: "deleteSelectedBookmark", { (_) -> Any? in
                        self.bookmarkWillDelete = true
                    })
                }
                /*
                 Tap to reveal feature
                 this closure is called whenever the List redraws its content, and it holds an unowned(safe) reference to tableView and fileObject as the closure has the same lifetime as these references (these references are guaranteed to be valid when the closure is accessed)
                 */
                .introspect(.table, on: .macOS(.v12, .v13, .v14), customize: { tableView in
                    tableView.backgroundColor = .clear
                    
                    global.registerFunction(withName: "bookmarksListClicked", { [unowned tableView,
                                                                                 unowned fileObject] (args) -> Any? in
                        // delay response by 0.001 seconds to determine if an action is needed
                        // in the case when the row action is tapped, tap-to-reveal is disabled
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.001) {
                            // actionable only when tap to reveal is enabled
                            guard tapToReveal else {
                                // resets tap-to-reveal feature
                                tapToReveal = true
                                return
                            }
                            let location = args[0].value as! NSPoint
                            let row = tableView.row(at: location)
                            
                            guard row != -1 else {
                                tableView.deselectAll(nil)
                                return
                            }
                            let clickedBookmark = fileObject.bookmarks[row]
                            
                            let doubleClick = args[1].value as! Bool
                            if doubleClick {
                                fileObject.selectedBookmark = clickedBookmark
                                bookmarkIsEditing = true
                            } else {
                                revealBookmarkRanges(clickedBookmark)
                            }
                        }
                    })
                })
            }
            .alert(isPresented: $bookmarkWillDelete) {
                Alert(title: Text("Delete Bookmark"), message: Text("Are you sure you want to delete the selected bookmark?"), primaryButton: .default(Text("Yes"), action: {
                    withAnimation {
                        if let index = fileObject.bookmarks.firstIndex(where: { $0.id == fileObject.selectedBookmark?.id }) {
                            fileObject.selectedBookmark = nil
                            fileObject.bookmarks.remove(at: index)
                        }
                    }
                }), secondaryButton: .cancel(Text("No")))
            }
            if fileObject.bookmarks.isEmpty {
                Spacer()
                HStack {
                    Spacer()
                    Text("No bookmark")
                    Spacer()
                }
                Spacer()
            }
        }
    }
}
