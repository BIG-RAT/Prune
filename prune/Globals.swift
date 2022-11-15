//
//  Globals.swift
//  Prune
//
//  Created by Leslie Helou on 12/22/19.
//  Copyright © 2019 Leslie Helou. All rights reserved.
//

import Foundation

struct appInfo {
    static let dict    = Bundle.main.infoDictionary!
    static let version = dict["CFBundleShortVersionString"] as! String
    static let name    = dict["CFBundleExecutable"] as! String

    static let userAgentHeader = "\(String(describing: name.addingPercentEncoding(withAllowedCharacters: .alphanumerics)!))/\(appInfo.version)"
}

struct JamfProServer {
    static var majorVersion = 0
    static var minorVersion = 0
    static var patchVersion = 0
    static var build        = ""
    static var authType     = "Basic"
    static var authCreds    = ""
    static var base64Creds  = ""        // used if we want to auth with a different account
    static var validToken   = false
    static var version      = ""
}

struct Log {
    static var path: String? = (NSHomeDirectory() + "/Library/Logs/")
    static var file     = "Prune.log"
    static var maxFiles = 10
    static var maxSize  = 5000000 // 5MB
}

struct LoginWindow {
    static var show = true
}

struct token {
    static var refreshInterval:UInt32 = 20*60  // 20 minutes
    static var sourceServer  = ""
    static var sourceExpires = ""
}

struct waitFor {
    static var deviceGroup             = true   // used for both computer and mobile device groups
    static var computerConfiguration   = true
    static var computerPrestage        = true
    static var osxconfigurationprofile = true
    static var policy                  = true
    static var mobiledeviceobject      = true
    static var ebook                   = true
    static var classes                 = true
    static var advancedsearch          = true
}
