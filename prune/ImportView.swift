//
//  MainViewDelegate.swift
//  Prune
//
//  Created by Leslie Helou on 3/18/23.
//  Copyright © 2023 Leslie Helou. All rights reserved.
//

import AppKit
import Cocoa
import Foundation

protocol ImportViewDelegate: AnyObject {
  func importFile(fileURL: URL)
}

class ImportView: NSView {
    
    enum Appearance {
      static let lineWidth: CGFloat = 5.0
    }
    
    weak var importDelegate: ImportViewDelegate?
    
    let importFilter = [NSPasteboard.ReadingOptionKey.urlReadingFileURLsOnly]
    
    override func awakeFromNib() {
        registerForDraggedTypes(Array([.fileURL]))
    }
    
    override func draw(_ dirtyRect: NSRect) {
      
      if isReceivingDrag {
        NSColor.selectedControlColor.set()
        
        let path = NSBezierPath(rect:bounds)
        path.lineWidth = Appearance.lineWidth
        path.stroke()
      }
    }
    
//    override func hitTest(_ aPoint: NSPoint) -> NSView? {
//      return nil
//    }
    
    func shouldAllowDrag(_ draggingInfo: NSDraggingInfo) -> Bool {
        print("shouldAllowDrag")
        
        var canAccept = true
//        var canAccept = false
      
      //2.
      let pasteBoard = draggingInfo.draggingPasteboard
      
      //3.
//      if pasteBoard.canReadObject(forClasses: [NSURL.self], options: convertToOptionalNSPasteboardReadingOptionKeyDictionary(filteringOptions)) {
//        canAccept = true
//      }
      return canAccept
      
    }
    
    var isReceivingDrag = false {
      didSet {
        needsDisplay = true
      }
    }
    //2.
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        print("draggingEntered")
      let allow = shouldAllowDrag(sender)
      isReceivingDrag = allow
      return allow ? .copy : NSDragOperation()
    }
    
    override func draggingExited(_ sender: NSDraggingInfo?) {
        print("draggingExited")
      isReceivingDrag = false
    }
    
    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        print("prepareForDragOperation")
      let allow = shouldAllowDrag(sender)
      return allow
    }
    
    
    override func performDragOperation(_ draggingInfo: NSDraggingInfo) -> Bool {
        print("performDragOperation")
      
      //1.
        isReceivingDrag = false
        let pasteBoard = draggingInfo.draggingPasteboard
        let urls = pasteBoard.readObjects(forClasses: [NSURL.self], options: [:]) as? [URL]
        print("[ImportView] file URLs: \(String(describing: urls))")

        NSApplication.shared.activate(ignoringOtherApps: true)
        importDelegate?.importFile(fileURL: urls![0])
//        ViewController().importButton_Action(urls![0])
        return true
    }

}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertToNSPasteboardPasteboardTypeArray(_ input: [String]) -> [NSPasteboard.PasteboardType] {
    return input.map { key in NSPasteboard.PasteboardType(key) }
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertFromNSPasteboardReadingOptionKey(_ input: NSPasteboard.ReadingOptionKey) -> String {
    return input.rawValue
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertToOptionalNSPasteboardReadingOptionKeyDictionary(_ input: [String: Any]?) -> [NSPasteboard.ReadingOptionKey: Any]? {
    guard let input = input else { return nil }
    return Dictionary(uniqueKeysWithValues: input.map { key, value in (NSPasteboard.ReadingOptionKey(rawValue: key), value)})
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertFromOptionalNSPasteboardPasteboardTypeArray(_ input: [NSPasteboard.PasteboardType]?) -> [String]? {
    guard let input = input else { return nil }
    return input.map { key in key.rawValue }
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertToNSPasteboardPasteboardType(_ input: String) -> NSPasteboard.PasteboardType {
    return NSPasteboard.PasteboardType(rawValue: input)
}
