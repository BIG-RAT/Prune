//
//  Copyright 2026 Jamf. All rights reserved.
//

import Cocoa

class Alert: NSObject {
    
    static let shared = Alert()
    private override init() { }
    
    func display(header: String, message: String, additionalButton: String = "") -> String {
        NSApplication.shared.activate(ignoringOtherApps: true)
        var selected = ""
        let dialog: NSAlert = NSAlert()
        dialog.messageText = header
        dialog.informativeText = message
        dialog.alertStyle = NSAlert.Style.warning
        let defaultButtonTitle = (additionalButton == "Stop") ? "Stop" : "OK"
        let additionalButtonTitle = (additionalButton == "Stop") ? "OK" : additionalButton
        let defaultButton = dialog.addButton(withTitle: defaultButtonTitle)
        if additionalButton != "" {
            let otherButton = dialog.addButton(withTitle: additionalButtonTitle)
            otherButton.keyEquivalent = (additionalButton == "Stop") ? "o" : "v"
            defaultButton.keyEquivalent = "\r"
        }
        
        let theButton = dialog.runModal()
        switch theButton {
        case .alertFirstButtonReturn:
            selected = defaultButtonTitle
        default:
            selected = additionalButtonTitle
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
