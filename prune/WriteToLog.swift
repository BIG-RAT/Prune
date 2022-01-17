//
//  WriteToLog.swift
//  Prune
//
//  Created by Leslie Helou on 7/11/20.
//  Copyright © 2019 jamf. All rights reserved.
//

import Foundation
class WriteToLog {
    
    let logFileW    = FileHandle(forUpdatingAtPath: Log.path! + Log.file)
    var writeToLogQ = DispatchQueue(label: "com.jamf.writeToLogQ", qos: DispatchQoS.utility)
    let fm          = FileManager()
    
    func createLogFile() {
        if !self.fm.fileExists(atPath: Log.path! + Log.file) {
            self.fm.createFile(atPath: Log.path! + Log.file, contents: nil, attributes: nil)
        }
    }
    
    // func logCleanup - start
    func logCleanup(completionHandler: @escaping (_ result: String) -> Void) {
            var logArray: [String] = []
            var logCount: Int = 0
            do {
                let logFiles = try fm.contentsOfDirectory(atPath: Log.path!)
                
                for logFile in logFiles {
                    if logFile.contains(".zip") {
                        let filePath: String = Log.path! + logFile
                        logArray.append(filePath)
                    }
                }
                logArray.sort()
                logCount = logArray.count
                // remove old log files
                if logCount > Log.maxFiles {
                    for i in (0..<logCount-Log.maxFiles) {
                        WriteToLog().message(theString: "Deleting log file: " + logArray[i] + "\n")
                        
                        do {
                            try fm.removeItem(atPath: logArray[i])
                        }
                        catch let error as NSError {
                            WriteToLog().message(theString: "Error deleting log file:\n    " + logArray[i] + "\n    \(error)\n")
                        }
                    }
                }
                // zip current log if it's over 5MB
                do {
                    let fileAttributes = try fm.attributesOfItem(atPath: Log.path! + Log.file)
                    let logSize = fileAttributes[.size] as? Int
                    if Int("\(logSize ?? 0)")! > Log.maxSize {
                        let dateTmpArray = getCurrentTime().split(separator: "_")
                        let dateStamp    = dateTmpArray[0]
                        zipIt(args: "/usr/bin/zip -rm -jj -o \(Log.path!)Prune_\(dateStamp) \(Log.path!)\(Log.file)") {
                            (result: String) in
//                            print("zipIt result: \(result)")
                            self.createLogFile()
                            completionHandler(result)
                            return
                        }
                    }
                }
            } catch {
//                print("no history")
                completionHandler("")
                return
            }
            completionHandler("")
    }
    // func logCleanup - end

    func message(theString: String) {
        if !fm.fileExists(atPath: Log.path!) {
            do {
                try fm.createDirectory(atPath: Log.path!, withIntermediateDirectories: true, attributes: nil)
            } catch {
                
            }
        }
        createLogFile()
        logCleanup() {
            (result: String) in
//            self.writeToLogQ.sync {
            let logString = "\(self.logDate()) \(theString)\n"
                    
                self.logFileW?.seekToEndOfFile()
                    
                let logText = (logString as NSString).data(using: String.Encoding.utf8.rawValue)
                self.logFileW?.write(logText!)
//                self.logFileW?.closeFile()
//            }
        }
    }
    
    func getCurrentTime() -> String {
        let current = Date()
        let localCalendar = Calendar.current
        let dateObjects: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute, .second]
        let dateTime      = localCalendar.dateComponents(dateObjects, from: current)
        let currentMonth  = leadingZero(value: dateTime.month!)
        let currentDay    = leadingZero(value: dateTime.day!)
        let currentHour   = leadingZero(value: dateTime.hour!)
        let currentMinute = leadingZero(value: dateTime.minute!)
        let currentSecond = leadingZero(value: dateTime.second!)
        let stringDate    = "\(dateTime.year!)\(currentMonth)\(currentDay)_\(currentHour)\(currentMinute)\(currentSecond)"
        return stringDate
    }
    
    func logDate() -> String {
        let logDate = DateFormatter()
        logDate.dateFormat = "E MMM dd HH:mm:ss"
        return("\(logDate.string(from: Date()))")
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
    
    func zipIt(args: String..., completion: @escaping (_ result: String) -> Void) {

        var cmdArgs = ["-c"]
        for theArg in args {
            cmdArgs.append(theArg)
        }
        var status  = ""
        var statusArray  = [String]()
        let pipe    = Pipe()
        let task    = Process()
        
        task.launchPath     = "/bin/sh"
        task.arguments      = cmdArgs
        task.standardOutput = pipe
        
        task.launch()
        
        let outdata = pipe.fileHandleForReading.readDataToEndOfFile()
        if var string = String(data: outdata, encoding: .utf8) {
            string = string.trimmingCharacters(in: .newlines)
            statusArray = string.components(separatedBy: "\n")
            status = statusArray[0]
        }
        
        task.waitUntilExit()
        completion(status)
    }

}
