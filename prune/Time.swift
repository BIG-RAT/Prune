//
//  Copyright 2026 Jamf. All rights reserved.
//

import Cocoa

class Time: NSObject {
    func getCurrent() -> String {
        let current = Date()
        let localCalendar = Calendar.current
        let dateObjects: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute, .second]
        let dateTime = localCalendar.dateComponents(dateObjects, from: current)
        let currentMonth  = leadingZero(value: dateTime.month!)
        let currentDay    = leadingZero(value: dateTime.day!)
        let currentHour   = leadingZero(value: dateTime.hour!)
        let currentMinute = leadingZero(value: dateTime.minute!)
        let currentSecond = leadingZero(value: dateTime.second!)
        let stringDate = "\(dateTime.year!)\(currentMonth)\(currentDay)_\(currentHour)\(currentMinute)\(currentSecond)"
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
}
