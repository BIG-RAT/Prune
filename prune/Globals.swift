//
//  Globals.swift
//  Prune
//
//  Created by Leslie Helou on 12/22/19.
//  Copyright © 2019 Leslie Helou. All rights reserved.
//

import Foundation

struct Log {
    static var path: String? = (NSHomeDirectory() + "/Library/Logs/")
    static var file  = "Prune.log"
    static var maxFiles = 10
    static var maxSize  = 5000000 // 5MB
}

struct waitFor {
    static var deviceGroup = true   // used for both computer and mobile device groups
    static var computerConfiguration   = true
    static var computerPrestage        = true
    static var osxconfigurationprofile = true
    static var policy                  = true
    static var mobiledeviceobject      = true
    static var ebook                   = true
    static var classes                 = true
}
