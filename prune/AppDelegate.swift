//
//  AppDelegate.swift
//  prune
//
//  Created by Leslie Helou on 12/11/19.
//  Copyright © 2019 Leslie Helou. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    @IBAction func QuitNow(sender: AnyObject) {
        JamfPro().jpapiAction(serverUrl: JamfProServer.source, endpoint: "auth/invalidate-token", apiData: [:], id: "", token: JamfProServer.authCreds["source"] ?? "https://null", method: "POST") {
            (returnedJSON: [String:Any]) in
            WriteToLog().message(theString: "\(String(describing: returnedJSON["JPAPI_result"]!))")
            NSApplication.shared.terminate(self)
        }
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }
    
    // quit the app if the window is closed
    func applicationShouldTerminateAfterLastWindowClosed(_ app: NSApplication) -> Bool {
        QuitNow(sender: self)
        return false
    }

}

