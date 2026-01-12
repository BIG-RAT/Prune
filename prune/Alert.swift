//
//  Copyright 2026 Jamf. All rights reserved.
//

import Cocoa

class Alert: NSObject {
    
    static let shared = Alert()
    private override init() { }
    
    func display(header: String, message: String, secondButton: String = "") -> String {
        NSApplication.shared.activate(ignoringOtherApps: true)
        var selected = ""
        let dialog: NSAlert = NSAlert()
        dialog.messageText = header
        dialog.informativeText = message
        dialog.alertStyle = NSAlert.Style.warning
        let okButton = dialog.addButton(withTitle: "OK")
        if secondButton != "" {
            let otherButton = dialog.addButton(withTitle: secondButton)
            otherButton.keyEquivalent = "v"
            okButton.keyEquivalent = "\r"
        }
        
        let theButton = dialog.runModal()
        switch theButton {
        case .alertFirstButtonReturn:
            selected = "OK"
        default:
            selected = secondButton
        }
        return selected
    }
    
    func summary(header: String, message: String) {
        let dialog: NSAlert = NSAlert()
        dialog.messageText = header
        dialog.informativeText = message
        dialog.alertStyle = NSAlert.Style.informational
        dialog.addButton(withTitle: "OK")
        dialog.runModal()
        //return true
    }   // func display - end

    func warning(header: String, message: String) -> String {
        let dialog: NSAlert = NSAlert()
        dialog.messageText = header
        dialog.informativeText = message
        dialog.alertStyle = NSAlert.Style.warning
        dialog.addButton(withTitle: "Cancel")
        dialog.addButton(withTitle: "OK")
        let userSelection = dialog.runModal()

        switch userSelection {
        case .alertFirstButtonReturn:
            return "Cancel"
        default:
            return "OK"
        }
    }   // func warning - end
}
