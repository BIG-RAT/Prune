//
//  WriteToLog.swift
//  Prune
//
//  Created by Leslie Helou on 7/11/20.
//  Copyright © 2019 jamf. All rights reserved.
//

import Foundation
import os.log

class WriteToLog {
    var logFileW: FileHandle? = FileHandle(forUpdatingAtPath: (Log.path! + Log.file))
    let fm                    = FileManager()
    
    func logCleanup() {
        // migrate log files from old location - start
//        var isDirectory: ObjCBool = true
////        print("[logCleanup] old log path: \(Log.path!)jamfcpr")
//        if fm.fileExists(atPath: Log.path! + "jamfcpr", isDirectory: &isDirectory) {
//            do {
//                let oldLogFiles = try fm.contentsOfDirectory(atPath: Log.path! + "jamfcpr/")
//                for oldLogFile in oldLogFiles {
//                    print("[logCleanup] move old log: \(oldLogFile)")
//                    try fm.moveItem(atPath: Log.path! + "jamfcpr/\(oldLogFile)", toPath: Log.path! + oldLogFile)
//                }
//                try fm.removeItem(atPath: Log.path! + "jamfcpr/")
//            } catch {
//                print("[logCleanup] error moving old log files from: \(Log.path!)jamfcpr")
//            }
//        }
        // migrate log files from old location - end
        
        if didRun {
            var logArray: [String] = []
            var logCount: Int = 0
            do {
                let logFiles = try fm.contentsOfDirectory(atPath: Log.path!)
                
                for logFile in logFiles {
                    let filePath: String = Log.path! + logFile
                    logArray.append(filePath)
                }
                logArray.sort()
                logCount = logArray.count
                // remove old log files
                if logCount-1 >= Log.maxFiles {
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
            } catch {
                print("no history")
            }
        } else {
            // delete empty log file
            do {
                try fm.removeItem(atPath: Log.path! + Log.file)
            }
            catch let error as NSError {
                WriteToLog().message(theString: "Error deleting log file:    \n" + Log.path! + Log.file + "\n    \(error)\n")
            }
        }
    }

    func message(theString: String) {
        let logString = "\(getCurrentTime(theFormat: "log")) \(theString)\n"
        self.logFileW?.seekToEndOfFile()
            
        let logText = (logString as NSString).data(using: String.Encoding.utf8.rawValue)
        self.logFileW?.write(logText!)
    }

}

extension Logger {
    private static var subsystem = Bundle.main.bundleIdentifier!

    //Categories
    static let prune = Logger(subsystem: subsystem, category: "prune")
}
