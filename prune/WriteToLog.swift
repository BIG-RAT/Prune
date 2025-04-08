//
//  Copyright 2024 Jamf. All rights reserved.
//

import Foundation
import os.log

class WriteToLog {
    
    static let shared = WriteToLog()
    private init() { }
    
//    var logFileW: FileHandle? = FileHandle(forUpdatingAtPath: (Log.path! + Log.file))
    let fm                    = FileManager()
    
    func logCleanup() {
        
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
                        WriteToLog.shared.message(theString: "Deleting log file: " + logArray[i] + "\n")
                        do {
                            try fm.removeItem(atPath: logArray[i])
                        }
                        catch let error as NSError {
                            WriteToLog.shared.message(theString: "Error deleting log file:\n    " + logArray[i] + "\n    \(error)\n")
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
                WriteToLog.shared.message(theString: "Error deleting log file:    \n" + Log.path! + Log.file + "\n    \(error)\n")
            }
        }
    }

    func message(theString: String) {
        let logString = "\(getCurrentTime(theFormat: "log")) \(theString)\n"
//        print("[WriteToLog] \(logString)")

        guard let logData = logString.data(using: .utf8) else { return }
        let logURL = URL(fileURLWithPath: Log.path! + Log.file)
        
        do {
            let fileHandle = try FileHandle(forWritingTo: logURL)
            defer { fileHandle.closeFile() } // Ensure file is closed
            
            fileHandle.seekToEndOfFile()
            fileHandle.write(logData)
        } catch {
            print("[Log Error] Failed to write to log file: \(error.localizedDescription)")
        }
        
        
        
//        let logString = "\(getCurrentTime(theFormat: "log")) \(theString)\n"
//        self.logFileW?.seekToEndOfFile()
//            
//        let logText = (logString as NSString).data(using: String.Encoding.utf8.rawValue)
//        self.logFileW?.write(logText!)
    }

}

extension Logger {
    private static var subsystem = Bundle.main.bundleIdentifier!

    //Categories
    static let prune = Logger(subsystem: subsystem, category: "prune")
}
