import Cocoa
import SwiftUI

/**
 The hosting controller of the bookmarks pane, serving as a mediator, an "ambassador" for the bookmarks pane
 it hosts, allowing certain states to be accessible by external classes.
 
 It also uses a click gesture recognizer to recognize and handle single/double-click events. This is because
 certain actions cannot be implemented easily, if at all, in SwiftUI, e.g. double-click or click elsewhere to
 deselect. This classes hook into the mouse click events and handles these events on behalf of the bookmarks
 pane.
 */
class BookmarksController: NSHostingController<BookmarksPane>, NSGestureRecognizerDelegate {
    
    // MARK: - Internal States
    
    /**
     An observable state object for the bookmarks pane.
     */
    class States: NSObject, ObservableObject {
        
        /**
         A new bookmark to be added to the collection.
         
         Normally, this property is set to `nil`. When creating a new bookmark, this property is set to a
         newly-created bookmark by ``EditorVC``. ``BookmarksPane`` uses this property to determine the
         appropriate action for the bookmark editor, if this is non-`nil`, then the bookmark editor will be
         used for adding a new bookmark, otherwise the bookmark editor will be used for editing the selected
         bookmark. After the bookmark editor is dismissed, ``BookmarksPane`` resets this property to `nil`,
         allowing a new round of bookmark creation to be initiated by the editor.
         */
        var newBookmark: Bookmark?
        
        /**
         A registered action to be carried out to complete a bookmark-related operation.
         
         - Parameter bookmarks: An array of bookmarks involved in this operation. According to the
         specification below, in case 1, this will be a list with only one bookmark, i.e. the newly-created
         bookmark. In case 2, this will also be a list with only one bookmark, i.e. the edited bookmark. In
         case 3, this will be the list of bookmarks selected for removal.
         
         There are three cases in which this handler is **required**:
         1. **Bookmark creation**: An action to be done after the user has finished editing the new bookmark
         in the bookmark editor.
         2. **Bookmark editing**: An action to be done after the user has finished editing a selected bookmark
         in the bookmark editor.
         3. **Bookmark deletion**: An action to be done after the user confirmed deleting a selected bookmark.
         
         After the action is fired, ``BookmarksPane`` resets this property to `nil`.
         */
        var completionHandler: (([Bookmark]) -> Void)?
        
        /**
         The set of selected bookmarks.
         */
        @Published var selectedBookmarks: Set<Bookmark> = []
        
        /**
         The currently selected bookmark. If there are multiple selected bookmarks, the first one is returned
         from the collection. Otherwise if the selection is empty, this property returns `nil`.
         */
        var selectedBookmark: Bookmark? {
            return selectedBookmarks.first
        }
        
        /**
         A boolean state indicating whether a new/selected bookmark is being edited. Set this property to
         `true` to notify ``BookmarksPane`` that a new bookmark should be created or a selected bookmark is
         to be edited, which subsequently presents the bookmark editor.
         
         Prior to setting this property `true`, one must ensure that the states have been properly set, that
         is, in case the user is creating a bookmark, ``newBookmark`` must be non-`nil`; and in case the user
         is editing a selected bookmark, ``selectedBookmarks`` must have at least one element. Finally,
         ``completionHandler`` must be non-`nil`.
         
         After the bookmark editor is dismissed, this property is reset to `false`.
         */
        @Published var bookmarkIsEditing = false
        
        /**
         A boolean state indicating whether a selected bookmark is to be deleted. Set this state property to
         `true` to notify ``BookmarksPane`` that the selected bookmark was requested for deletion, which
         subsequently displays a confirmation alert.
         
         Prior to setting this property `true`, one must ensure that the states have been properly set, that
         is, ``selectedBookmarks`` must have at least one element. Finally, ``completionHandler`` must be
         non-`nil`.
         
         After the alert is dismissed, this property is reset to `false`.
         */
        @Published var bookmarksWillDelete = false
        
        /**
         A flag indicating whether click-to-reveal feature is enabled.
         
         This property determines whether a single-click event should reveal the clicked bookmark in the main
         text view. This flag is in place to selectively disable the click-to-reveal feature in certain
         conditions so that it does not reveal the selected bookmark (e.g. when swipe actions are performed).
         
         This property only takes effect once after being set to `false` and is reset to `true` by the first
         single-click event received.
         */
        var tapToReveal = true
        
        /**
         The underlying `NSTableView` instance for the bookmark list.
         
         This is used to retrieve the row number at a location in the list view.
         */
        var bookmarkListTableView: NSTableView!
        
    }
    
    /**
     An unowned reference to the shared state object maintained by ``BookmarksPane``.
     
     - Note: The source-of-truth for this object is in ``BookmarksPane``.
     */
    private unowned var states: States
    
    /**
     An unowned reference to the editor in which the bookmarks pane is installed.
     
     This reference is used to send messages to the editor only and should only be used to access members
     relevant to bookmarks.
     */
    private unowned let editor: EditorVC
    
    // MARK: - Bookmark Bridging
    
    /**
     The set of selected bookmarks.
     
     Setting this property updates the selected bookmarks.
     */
    var selectedBookmarks: Set<Bookmark> {
        get {
            return states.selectedBookmarks
        }
        set {
            states.selectedBookmarks = newValue
        }
    }
    
    /**
     The currently selected bookmark. If there are multiple selected bookmarks, the first one is returned
     from the collection. Otherwise if the selection is empty, this property returns `nil`.
     */
    var selectedBookmark: Bookmark? {
        return states.selectedBookmark
    }
    
    override init(rootView: BookmarksPane) {
        self.states = rootView.states
        self.editor = rootView.editor
        super.init(rootView: rootView)
        // initialize and register click gesture recognizer
        // NOTE: the hosting controller does not invoke viewDidLoad or awakeFromNib
        clickGestureRecognizer.delegate = self
        view.addGestureRecognizer(clickGestureRecognizer)
    }
    
    @MainActor required dynamic init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    /**
     Signals ``BookmarksPane`` that a new bookmark is to be created.
     
     - Parameters:
        - newBookmark: The new bookmark to be created.
        - completion: An action to be done after the user has finished editing the new bookmark in the
                      bookmark editor.
     */
    func createBookmark(_ newBookmark: Bookmark, onComplete completion: @escaping ([Bookmark]) -> Void) {
        states.newBookmark = newBookmark
        states.completionHandler = completion
        states.bookmarkIsEditing = true
    }
    
    /**
     Signals ``BookmarksPane`` that the selected bookmark is to be edited.
     
     - Parameter completion: An action to be done after the user has finished editing the selected bookmark in
                             the bookmark editor.
     
     - Precondition: ``selectedBookmark`` is non-`nil`.
     */
    func editSelectedBookmark(onComplete completion: @escaping ([Bookmark]) -> Void) {
        states.completionHandler = completion
        states.bookmarkIsEditing = true
    }
    
    /**
     Signals ``BookmarksPane`` that the selected bookmarks are requested for deletion.
     
     - Parameter completion: An action to be done after the user confirmed deleting the selected bookmarks.
     
     - Precondition: ``selectedBookmark`` is non-`nil`.
     */
    func deleteSelectedBookmarks(onCompletion completion: @escaping ([Bookmark]) -> Void) {
        states.completionHandler = completion
        states.bookmarksWillDelete = true
    }
    
    // MARK: - Custom Single/Double-Click Gesture
    
    /**
     An "action-less" click gesture recognizer.
     */
    private var clickGestureRecognizer = NSClickGestureRecognizer()
    
    /**
     A timer used to differentiate between a single click and double click event.
     
     This timer, if `nil`, is registered with a delayed action when a mouse click event is received. When a
     new click event is received, whether this timer is valid and has a scheduled action will be used to
     determine if the mouse click event should be recognized as part of a double-click sequence. If an
     existing timer is in place, the timer immediately gets invalidated and perform actions as a result of a
     double-click event.
     */
    private var gestureTimer: Timer?
    
    /**
     Intercepts the gesture recognizer and allows user interaction with the content view.
     
     This was originally called to determine whether the gesture recognizer should begin. It was
     repurposed to execute the target action here and always return `false` to prevent the
     gesture recognizer from proceeding with its state transition (hence action-less), because
     heuristically, this acts just like the target action of the gesture recognizer----when a
     gesture is recognized, the method is called and an operation is done.
     
     - Note: Although the mouse click event is received from using the gesture recognizer, allowing
     it to begin the transition from `possible` state to `began` will prevent the user from
     interacting with the content view (the `List` view) as a side effect.
     */
    func gestureRecognizerShouldBegin(_ gestureRecognizer: NSGestureRecognizer) -> Bool {
        let point = gestureRecognizer.location(in: view)
        
        // Manually recognize and differentiate between single and double click events
        if (gestureTimer == nil) {
            bookmarkListClicked(at: point, doubleClick: false)
            gestureTimer = .scheduledTimer(withTimeInterval: 0.3, repeats: false) { timer in
                timer.invalidate()
                self.gestureTimer = nil
            }
        } else {
            // gesture timer exists, recognizing as double click
            gestureTimer!.invalidate()
            gestureTimer = nil
            
            self.bookmarkListClicked(at: point, doubleClick: true)
        }
        return false
    }
    
    private func bookmarkListClicked(at point: NSPoint, doubleClick: Bool) {
        guard (states.tapToReveal) else {
            states.tapToReveal = true
            return
        }
        let tableView = states.bookmarkListTableView!
        let row = tableView.row(at: point)
        guard (row > -1) else {
            selectedBookmarks = []
            return
        }
        let bookmark = editor.document.content.bookmarks[row]
        if (doubleClick) {
            selectedBookmarks = [bookmark]
            editor.editSelectedBookmark()
        }
        // TODO: Tap to reveal feature
    }
    
    /**
     Detaches the gesture recognizer from the view and invalidates the gesture timer.
     
     The gesture recognizer and timer are detached to release the memory.
     */
    deinit {
        view.removeGestureRecognizer(clickGestureRecognizer)
        gestureTimer?.invalidate()
    }
    
}
