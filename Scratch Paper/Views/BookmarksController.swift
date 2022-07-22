//
//  BookmarksController.swift
//  Scratch Paper
//
//  Created by Bingyi Billy Li on 2022/7/15.
//

import Cocoa
import SwiftUI

/**
 A subclass of `NSHostingController` hosting specifically the `BookmarksPane` view that is used to customize certain behaviors.
 
 Adds a click gesture recognizer that sends a command to: highlight the corresponding text ranges of the selected bookmark entry, edit the selected bookmark entry, or deselect selected row if the user clicked elsewhere in the `List` view.
 
 - Note: This implementation is a workaround for receiving mouse click event on the SwiftUI's `List` view. The idea did not seem to be supported by SwiftUI natively as the view modifier `onTapGesture(perform:)` did not work gracefully with clear background `List` view, nor did it work properly with the rounded-rectangular table cell view.
 */
class BookmarksController: NSHostingController<BookmarksPane>, NSGestureRecognizerDelegate {
    
    /// An action-less click gesture recognizer.
    var clickGestureRecognizer = NSClickGestureRecognizer()
    
    /**
     A timer used to differentiate between single click and double click gestures.
     
     This timer, if `nil`, is registered with a delayed action (of an eligible interval) when a mouse click event is received. When a new click event is received, whether or not this timer is valid and has a scheduled action will be used to determine if the mouse click event should be recognized as part of a double-click sequence. If an existing timer is in place, the timer immediately gets invalidated to prevent the registered single-click action from firing and perform actions as a result of a double-click event.
     
     - Note: This should always be `nil` when no mouse click event is received in order for it to function properly.
     When this is not `nil` as a result of a mouse click event, it should always be regardfully reset to `nil` when done.
     */
    var gestureTimer: Timer?
    
    /**
     Sets click gesture recognizers' delegate to `self` and attaches them to the controller's view.
     
     This is implemented here because the hosting controller does not invoke `viewDidLoad()`.
     */
    override func viewDidAppear() {
        super.viewDidAppear()
        self.clickGestureRecognizer.delegate = self
        self.view.addGestureRecognizer(self.clickGestureRecognizer)
    }
    
    /**
     Intercepts the gesture recognizer and allows user interaction with the content view.
     
     This was originally called to determine whether the gesture recognizer should begin. It was repurposed to execute the target action here (hence the action-less gesture recognizer) and always prevent the gesture recognizer from proceeding with its state transition, because heuristically, this acts just like the target action of the gesture recognizer----when a gesture is recognized, the method is called and an operation is done.
     
     - Note: Although the mouse click event is received from using the gesture recognizer, allowing it to begin the transition from `possible` state to `began` will prevent the user from interacting with the content view (the `List` view) as a side effect.
     */
    func gestureRecognizerShouldBegin(_ gestureRecognizer: NSGestureRecognizer) -> Bool {
        let point = gestureRecognizer.location(in: self.view)
        
        // Manually recognize and differentiate between single and double click events
        if self.gestureTimer == nil {
            self.gestureTimer = .scheduledTimer(withTimeInterval: 0.3, repeats: false, block: { timer in
                // get point clicked from gesture recognizer
                global.bookmarksListClicked?(point: point, doubleClick: false)
                
                timer.invalidate()
                self.gestureTimer = nil
            })
        } else {
            // gesture timer exists, recognizing as double click
            self.gestureTimer!.invalidate()
            self.gestureTimer = nil
            
            global.bookmarksListClicked?(point: point, doubleClick: true)
        }
        return false
    }
    
    /**
     Detaches the gesture recognizer from the view and invalidates the gesture timer.
     
     The gesture recognizer and timer are detached to release the memory.
     */
    override func viewWillDisappear() {
        super.viewWillDisappear()
        self.view.removeGestureRecognizer(self.clickGestureRecognizer)
        self.gestureTimer?.invalidate()
    }
    
    deinit {
        // deregister functions
        global.deregisterFunction(ofName: "editSelectedBookmark")
        global.deregisterFunction(ofName: "deleteSelectedBookmark")
        global.deregisterFunction(ofName: "bookmarksListClicked")
    }
    
}
