//
//  RenderConfig.swift
//  TeX-ScratchPad
//
//  Created by Bingyi Billy Li on 2022/7/4.
//

import Cocoa

struct RenderConfig {
    
    var renderMode = 0
    var displayMode = false
    var displayStyle = false
    var lineCorrespondence = false
    var lockToRight = false
    var lockToBottom = false
    
    init(_ editor: Editor) {
        let contentObject = editor.document.content
        
        self.renderMode = contentObject.renderMode
        self.displayMode = contentObject.displayMode
        self.displayStyle = contentObject.displayStyle
        self.lineCorrespondence = contentObject.lineCorrespondence
        self.lockToRight = contentObject.lockToRight
        self.lockToBottom = contentObject.lockToBottom
    }
}
