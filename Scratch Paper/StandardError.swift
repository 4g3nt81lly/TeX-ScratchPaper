//
//  StandardError.swift
//  Scratch Paper
//
//  Created by Bingyi Billy Li on 2022/7/19.
//

import Cocoa

/// An enumeration object that represents the application's standard error.
enum StandardError: Error {
    
    /// Case that represents an error involving the application settings.
    case settingsError(String)
    
    /// Case that represents an error involving the document management.
    case documentError(String)
    
    /// Case that represents an error involving the editor.
    case editorError(String)
    
    /// Case that represents an error involving the rendering operations.
    case renderError(String)
    
}
