//
//  AppDelegate.swift
//  TeX-ScratchPad
//
//  Created by Bingyi Billy Li on 2021/6/14.
//

import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        
    }
    
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
    
    @IBAction func export(_ sender: NSMenuItem) {
        (NSApp.keyWindow?.windowController as? DocumentWindow)?.export()
    }
    
    @IBAction func insert(_ sender: NSMenuItem) {
        (NSApp.keyWindow?.windowController as? DocumentWindow)?.insert(sender)
    }

}
