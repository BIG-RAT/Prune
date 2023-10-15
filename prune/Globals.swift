//
//  Globals.swift
//  Prune
//
//  Created by Leslie Helou on 12/22/19.
//  Copyright © 2019 Leslie Helou. All rights reserved.
//

import Foundation

let httpSuccess   = 200...299
let userDefaults  = UserDefaults.standard
var didRun        = false

struct AppInfo {
    static let dict    = Bundle.main.infoDictionary!
    static let version = dict["CFBundleShortVersionString"] as! String
    static let name    = dict["CFBundleExecutable"] as! String

    static let userAgentHeader = "\(String(describing: name.addingPercentEncoding(withAllowedCharacters: .alphanumerics)!))/\(AppInfo.version)"
}

struct JamfProServer {
    static var majorVersion = 0
    static var minorVersion = 0
    static var patchVersion = 0
    static var build        = ""
    static var source       = ""
    static var destination  = ""
    static var authCreds    = ["source":"", "destination":""]
    static var authExpires:[String:Double] = ["source":30.0, "destination":30.0]
    static var authType     = ["source":"Bearer", "destination":"Bearer"]
    static var base64Creds  = ["source":"", "destination":""]               // used if we want to auth with a different account
    static var validToken   = ["source":false, "destination":false]
    static var version      = ["source":"", "destination":""]
    static var tokenCreated = ["source": Date(), "destination": Date()]
    
    static var accessToken  = ["source":"", "destination":""]
    static var currentCred  = ["source":"", "destination":""]               // used if we want to auth with a different account / string used to generate token
    static var username     = ["source":"", "destination":""]
    static var password     = ["source":"", "destination":""]
    static var saveCreds    = ["source":0, "destination":0]
    static var useApiClient = ["source":0, "destination":0]
    static var url          = ["source":"", "destination":""]
    
//    static var authType     = "Basic"
//    static var authCreds    = ""
//    static var base64Creds  = ""        // used if we want to auth with a different account
//    static var source       = ""
//    static var validToken   = false
//    static var version      = ""
}

struct Log {
    static var path: String? = (NSHomeDirectory() + "/Library/Logs/")
    static var file     = "prune.log"
    static var maxFiles = 42
//    static var maxSize  = 5000000 // 5MB
}

struct LoginWindow {
    static var show = true
}

//struct token {
//    static var refreshInterval:UInt32 = 20*60  // 20 minutes
//    static var sourceServer  = ""
//    static var sourceExpires = ""
//    static var isValid       = false
//}

class ServerInfo: NSObject {
    var url: String
    var username: String
    var password: String
    var saveCreds: Int
    var useApiClient: Int
    init(url: String, username: String, password: String, saveCreds: Int = 0, useApiClient: Int = 0) {
        self.url = url
        self.username = username
        self.password = password
        self.saveCreds    = saveCreds
        self.useApiClient = useApiClient
    }
}
var sourceServer      = ServerInfo(url: "", username: "", password: "", saveCreds: 0, useApiClient: 0)
var destinationServer = ServerInfo(url: "", username: "", password: "", saveCreds: 0, useApiClient: 0)

struct waitFor {
    static var deviceGroup             = true   // used for both computer and mobile device groups
    static var computerConfiguration   = true
    static var computerPrestage        = true
    static var osxconfigurationprofile = true
    static var macApps                 = true
    static var policy                  = true
    static var mobiledeviceobject      = true
    static var ebook                   = true
    static var classes                 = true
    static var advancedsearch          = true
}

func getCurrentTime(theFormat: String = "log") -> String {
    var stringDate = ""
    let current = Date()
    let localCalendar = Calendar.current
    let dateObjects: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute, .second]
    let dateTime = localCalendar.dateComponents(dateObjects, from: current)
    let currentMonth  = leadingZero(value: dateTime.month!)
    let currentDay    = leadingZero(value: dateTime.day!)
    let currentHour   = leadingZero(value: dateTime.hour!)
    let currentMinute = leadingZero(value: dateTime.minute!)
    let currentSecond = leadingZero(value: dateTime.second!)
    switch theFormat {
    case "info":
        stringDate = "\(dateTime.year!)-\(currentMonth)-\(currentDay) \(currentHour)\(currentMinute)"
    default:
        stringDate = "\(dateTime.year!)\(currentMonth)\(currentDay)_\(currentHour)\(currentMinute)\(currentSecond)"
    }
    return stringDate
}
// add leading zero to single digit integers
func leadingZero(value: Int) -> String {
    var formattedValue = ""
    if value < 10 {
        formattedValue = "0\(value)"
    } else {
        formattedValue = "\(value)"
    }
    return formattedValue
}

public func timeDiff(startTime: Date) -> (Int, Int, Int, Double) {
    let endTime = Date()
//                    let components = Calendar.current.dateComponents([.second, .nanosecond], from: startTime, to: endTime)
//                    let timeDifference = Double(components.second!) + Double(components.nanosecond!)/1000000000
//                    WriteToLog().message(stringOfText: "[ViewController.download] time difference: \(timeDifference) seconds")
    let components = Calendar.current.dateComponents([
        .hour, .minute, .second, .nanosecond], from: startTime, to: endTime)
    var diffInSeconds = Double(components.hour!)*3600 + Double(components.minute!)*60 + Double(components.second!) + Double(components.nanosecond!)/1000000000
    diffInSeconds = Double(round(diffInSeconds * 1000) / 1000)
//    let timeDifference = Int(components.second!) //+ Double(components.nanosecond!)/1000000000
//    let (h,r) = timeDifference.quotientAndRemainder(dividingBy: 3600)
//    let (m,s) = r.quotientAndRemainder(dividingBy: 60)
//    WriteToLog().message(stringOfText: "[ViewController.download] download time: \(h):\(m):\(s) (h:m:s)")
    return (Int(components.hour!), Int(components.minute!), Int(components.second!), diffInSeconds)
//    return (h, m, s)
}
