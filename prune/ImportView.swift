//
//  Copyright 2026 Jamf. All rights reserved.
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
        var canAccept = true

        let pasteBoard = draggingInfo.draggingPasteboard
        return canAccept
    }
    
    var isReceivingDrag = false {
      didSet {
        needsDisplay = true
      }
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
      let allow = shouldAllowDrag(sender)
      isReceivingDrag = allow
      return allow ? .copy : NSDragOperation()
    }
    
    override func draggingExited(_ sender: NSDraggingInfo?) {
      isReceivingDrag = false
    }
    
    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
      let allow = shouldAllowDrag(sender)
      return allow
    }
    
    
    override func performDragOperation(_ draggingInfo: NSDraggingInfo) -> Bool {
        
        isReceivingDrag = false
        let pasteBoard = draggingInfo.draggingPasteboard
        let urls = pasteBoard.readObjects(forClasses: [NSURL.self], options: [:]) as? [URL]

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
