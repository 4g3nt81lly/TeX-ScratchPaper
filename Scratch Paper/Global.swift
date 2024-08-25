import Cocoa
import SwiftUI
import Combine

/// The application's delegate object.
let appDelegate = NSApp.delegate as! AppDelegate

/// The application's default notification center.
let notificationCenter = NotificationCenter.default

/// The application's standard user defaults object.
let userDefaults = UserDefaults.standard

/// The application's default file manager object.
let fileManager = FileManager.default

/// The application's shared font manager object.
let fontManager = NSFontManager.shared

/// The main storyboard.
let mainStoryboard = NSStoryboard.main!

/// The application's main bundle object.
let mainBundle = Bundle.main

/// An instance of the global environment channel.
let global = GlobalChannel()

/**
 Application's universally accessible settings object.
 
 Reads and decodes settings from application support directory within the current user domain.
 If the configuration file is not found under the target directory, it will attempt to create a new instance.
 
 - Note: This property is initialized as part of the delegate's instantiation process, which
 guarantees it to be readily available when one requests it.
 */
var appSettings: AppSettings = AppSettings.shared
