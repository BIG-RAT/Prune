//
//  ViewController.swift
//  prune
//
//  Created by Leslie Helou on 12/11/19.
//  Copyright © 2019 Leslie Helou. All rights reserved.
//

import Cocoa
import Foundation

class ViewController: NSViewController {

    
    var theGetQ    = OperationQueue() // create operation queue for API POST/PUT calls
    var theDeleteQ = OperationQueue() // queue for delete API calls
    
    @IBOutlet weak var jamfServer_TextField: NSTextField!
    @IBOutlet weak var uname_TextField: NSTextField!
    @IBOutlet weak var passwd_TextField: NSSecureTextField!
    @IBOutlet weak var view_PopUpButton: NSPopUpButton!
    @IBOutlet weak var packages_Button: NSButton!
    @IBOutlet weak var scripts_Button: NSButton!
    @IBOutlet weak var computerGroups_Button: NSButton!
    
    @IBOutlet weak var import_Button: NSPathControl!
    
    @IBAction func updateViewButton_Action(_ sender: NSButton) {
        let state = (sender.state.rawValue == 1) ? "on":"off"
        let title = sender.title
        if state == "on" {
            view_PopUpButton.addItem(withTitle: "\(title)")
        } else {
            view_PopUpButton.removeItem(withTitle: "\(title)")
        }
        switch title {
        case "Packages":
            if state == "on" {
                packagesButtonState = "on"
            } else {
                packagesButtonState = "off"
            }
        case "Scripts":
            if state == "on" {
                scriptsButtonState = "on"
            } else {
                scriptsButtonState = "off"
            }
        case "Computer Groups":
            if state == "on" {
                computerGroupsButtonState = "on"
            } else {
                computerGroupsButtonState = "off"
            }
        default:
            if state == "on" {
                
            }
        }
    }
    
    @IBOutlet var summary_TextField: NSTextView!
    
    var currentServer   = ""
    var jamfCreds       = ""
    var jamfBase64Creds = ""
    var completed       = 0
    
    var packagesDict              = Dictionary<String,Dictionary<String,String>>()    // id, name, used
    var scriptsDict               = Dictionary<String,Dictionary<String,String>>()    // id, name, used
    var policiesDict              = [String:String]()    //:Dictionary<String,String> = [:]
    var computerConfigurationDict = [String:String]()
    var computerGroupsDict        = Dictionary<String,Dictionary<String,String>>()
    var allUnused                 = [[String:[String:String]]]() //Dictionary<String,Dictionary<String,String>>()    // currently unused var
    
    var packagesButtonState       = "off"
    var scriptsButtonState        = "off"
    var computerGroupsButtonState = "off"
    
    @IBAction func go_action(_ sender: Any) {
        view_PopUpButton.isEnabled = false
        view_PopUpButton.selectItem(at: 0)
        packagesDict.removeAll()
        scriptsDict.removeAll()
        policiesDict.removeAll()
        computerConfigurationDict.removeAll()
        computerGroupsDict.removeAll()
        
        summary_TextField.textColor = NSColor.black
        summary_TextField.font      = NSFont(name: "HelveticaNeue", size: CGFloat(12))
        summary_TextField.string    = ""
        
        currentServer       = jamfServer_TextField.stringValue
        jamfCreds           = "\(uname_TextField.stringValue):\(passwd_TextField.stringValue)"
        let jamfUtf8Creds   = jamfCreds.data(using: String.Encoding.utf8)
        jamfBase64Creds     = (jamfUtf8Creds?.base64EncodedString())!
        completed           = 0
        
        print("[go_action caller] start lookups...")
        processItems(type: "packages")
    }
    
    func processItems(type: String) {
        
        theGetQ.maxConcurrentOperationCount = 3

        theGetQ.addOperation {
            switch type {
                            case "osxconfigurationprofiles":
                                DispatchQueue.main.async {
                                    self.summary_TextField.string = "Fetching Computer Configuration Profiles..."
                                }
                                Json().getRecord(theServer: self.currentServer, base64Creds: self.jamfBase64Creds, theEndpoint: "packages") {
                                    (result: [String:AnyObject]) in
                //                    print("json returned packages: \(result)")
                                    let packagesArray = result["packages"] as! [Dictionary<String, Any>]
                                    let packagesArrayCount = packagesArray.count
                                    if packagesArrayCount > 0 {
                                        for i in (0..<packagesArrayCount) {
                                            if let id = packagesArray[i]["id"], let name = packagesArray[i]["name"] {
                                                self.packagesDict["\(id)"] = ["name":"\(name)", "used":"false"]
                                            }
                                        }
                                    }
                //                    print("packagesDict (\(self.packagesDict.count)): \(self.packagesDict)")
                                    print("call scripts")
                                    DispatchQueue.main.async {
                                        self.processItems(type: "scripts")
                                    }
                                }
                                
            case "packages":
                if self.packagesButtonState == "on" {
                    DispatchQueue.main.async {
                        self.summary_TextField.string = "Fetching Packages..."
                    }
                    Json().getRecord(theServer: self.currentServer, base64Creds: self.jamfBase64Creds, theEndpoint: "packages") {
                        (result: [String:AnyObject]) in
    //                    print("json returned packages: \(result)")
                        let packagesArray = result["packages"] as! [Dictionary<String, Any>]
                        let packagesArrayCount = packagesArray.count
                        if packagesArrayCount > 0 {
                            for i in (0..<packagesArrayCount) {
                                if let id = packagesArray[i]["id"], let name = packagesArray[i]["name"] {
                                    self.packagesDict["\(id)"] = ["name":"\(name)", "used":"false"]
                                }
                            }
                        }
    //                    print("packagesDict (\(self.packagesDict.count)): \(self.packagesDict)")
                        print("call scripts")
                        DispatchQueue.main.async {
                            self.processItems(type: "scripts")
                        }
                    }
                } else {
                    print("call scripts")
                    DispatchQueue.main.async {
                        self.processItems(type: "scripts")
                    }
                }
                
                case "scripts":
                    if self.scriptsButtonState == "on" {
                        DispatchQueue.main.async {
                            self.summary_TextField.string = "Fetching Scripts..."
                        }
                        Json().getRecord(theServer: self.currentServer, base64Creds: self.jamfBase64Creds, theEndpoint: "scripts") {
                            (result: [String:AnyObject]) in
        //                    print("json returned scripts: \(result)")
                            let scriptsArray = result["scripts"] as! [Dictionary<String, Any>]
                            let scriptsArrayCount = scriptsArray.count
                            if scriptsArrayCount > 0 {
                                for i in (0..<scriptsArrayCount) {
                                    if let id = scriptsArray[i]["id"], let name = scriptsArray[i]["name"] {
                                        self.scriptsDict["\(id)"] = ["name":"\(name)", "used":"false"]
                                    }
                                }
                            }
    //                        print("scriptsDict (\(self.scriptsDict.count)): \(self.scriptsDict)")
                            print("call computerGroups")
                            DispatchQueue.main.async {
                                self.processItems(type: "computerGroups")
                            }
                        }
                    } else {
                        print("call computerGroups")
                        DispatchQueue.main.async {
                            self.processItems(type: "computerGroups")
                        }
                   }
                            
                case "computerGroups":
                    if self.computerGroupsButtonState == "on" {
                        DispatchQueue.main.async {
                            self.summary_TextField.string = "Fetching Computer Groups..."
                        }
                        Json().getRecord(theServer: self.currentServer, base64Creds: self.jamfBase64Creds, theEndpoint: "computergroups") {
                            (result: [String:AnyObject]) in
    //                            print("json returned scripts: \(result)")
                            let computerGroupsArray = result["computer_groups"] as! [Dictionary<String, Any>]
                            let computerGroupsArrayCount = computerGroupsArray.count
                            if computerGroupsArrayCount > 0 {
                                // loop through all computer groups and mark as unused
                                // skip All managed clients / servers
                                for i in (0..<computerGroupsArrayCount) {
                                    if let id = computerGroupsArray[i]["id"], let name = computerGroupsArray[i]["name"] {
                                        // skip by id rather than name?
                                        if "\(name)" != "All Managed Clients" && "\(name)" != "All Managed Servers" {
                                            self.computerGroupsDict["\(name)"] = ["id":"\(id)", "used":"false"]
                                        }
                                    }
                                }   // for i in (0..<computerGroupsArrayCount) - end
                                // look for nested computer groups
                                DispatchQueue.main.async {
                                    self.summary_TextField.string = "Scanning for nexted computer groups..."
                                }
                                for theGroup in computerGroupsArray {
                                    if let id = theGroup["id"] {
                                        Json().getRecord(theServer: self.currentServer, base64Creds: self.jamfBase64Creds, theEndpoint: "computergroups/id/\(id)") {
                                                        (result: [String:AnyObject]) in
//                                            print("result: \(result)")
                                            let computerGroupInfo = result["computer_group"] as! Dictionary<String, AnyObject>
                                            let criterion = computerGroupInfo["criteria"] as! [Dictionary<String, Any>]
                                            for theCriteria in criterion {
                                                if let name = theCriteria["name"], let value = theCriteria["value"] {
                                                    if (name as! String) == "Computer Group" {
                                                        self.computerGroupsDict["\(value)"] = ["used":"true"]
                                                    }
                                                }
                                            }
                                        }   //Json().getRecord - end
                                    }
                                }
                                // look for nested computer groups - end
                            }
    //                        print("computerGroupsDict (\(self.computerGroupsDict.count)): \(self.computerGroupsDict)")
                            print("call computerConfigurations")
                            DispatchQueue.main.async {
                                self.processItems(type: "computerConfigurations")
                            }
                        }
                    } else {
                        print("call computerConfigurations")
                        DispatchQueue.main.async {
                            self.processItems(type: "computerConfigurations")
                        }
                    }
                                    
                case "computerConfigurations":
                    DispatchQueue.main.async {
                        self.summary_TextField.string = "Fetching Computer Configurations..."
                    }
                    Json().getRecord(theServer: self.currentServer, base64Creds: self.jamfBase64Creds, theEndpoint: "computerconfigurations") {
                        (result: [String:AnyObject]) in
            //            print("json returned: \(result)")
                        self.completed = 0
                        let computerConfigurationsArray = result["computer_configurations"] as! [Dictionary<String, Any>]
                        let computerConfigurationsArrayCount = computerConfigurationsArray.count
                        if computerConfigurationsArrayCount > 0 {
                            // loop through all the computerConfigurations
                            DispatchQueue.main.async {
                                self.summary_TextField.string = "Scanning Computer Configurations for packages and scripts..."
                            }
                            for i in (0..<computerConfigurationsArrayCount) {
                                if let id = computerConfigurationsArray[i]["id"], let name = computerConfigurationsArray[i]["name"] {
                                    self.computerConfigurationDict["\(id)"] = "\(name)"
                                    Json().getRecord(theServer: self.currentServer, base64Creds: self.jamfBase64Creds, theEndpoint: "computerconfigurations/id/\(id)") {
                                        (result: [String:AnyObject]) in
            //                            print("json for computerConfiguration id: \(id): \(result)")
                                        self.completed += 1
                                        let theComputerConfiguration = result["computer_configuration"] as! [String:AnyObject]
                                     //   let packageList = theComputerConfiguration["packages"] as! [String:AnyObject]
                                        let computerConfigurationPackageList = theComputerConfiguration["packages"] as! [Dictionary<String, Any>]
                                        for thePackage in computerConfigurationPackageList {
    //                                        print("thePackage: \(thePackage)")
                                            let thePackageID = thePackage["id"]
    //                                        print("packages id for policy id: \(id): \(thePackageID!)")
                                            self.packagesDict["\(thePackageID!)"]?["used"] = "true"
                                        }

                                        let omputerConfigurationScriptList = theComputerConfiguration["scripts"] as! [Dictionary<String, Any>]
                                        for theScript in omputerConfigurationScriptList {
    //                                        print("thePackage: \(thePackage)")
                                            let theScriptID = theScript["id"]
    //                                        print("packages id for policy id: \(id): \(thePackageID!)")
                                            self.scriptsDict["\(theScriptID!)"]?["used"] = "true"
                                        }
    //                                    print("packages for policy id: \(id): \(packageList)")
                                        if self.completed == computerConfigurationsArrayCount {
                                            DispatchQueue.main.async {
                                                self.processItems(type: "policies")
                                            }
                                        }
                                    }
                                }
                            }   // for i in (0..<computerConfigurationsArrayCount) - end
                        }
    //                    print("policy dict: \(self.policiesDict)")
                    }   //         Json().getRecord - computerConfigurations - end
                
            case "policies":
                DispatchQueue.main.async {
                    self.summary_TextField.string = "Fetching Policies..."
                }
                Json().getRecord(theServer: self.currentServer, base64Creds: self.jamfBase64Creds, theEndpoint: "policies") {
                    (result: [String:AnyObject]) in
        //            print("json returned: \(result)")
                    self.completed = 0
                    let policiesArray = result["policies"] as! [Dictionary<String, Any>]
                    let policiesArrayCount = policiesArray.count
                    if policiesArrayCount > 0 {
                        // loop through all the policies
                        DispatchQueue.main.async {
                            self.summary_TextField.string = "Scanning policies for packages, scripts, computer groups..."
                        }
                        for i in (0..<policiesArrayCount) {
                            if let id = policiesArray[i]["id"], let name = policiesArray[i]["name"] {
                                self.policiesDict["\(id)"] = "\(name)"
                                Json().getRecord(theServer: self.currentServer, base64Creds: self.jamfBase64Creds, theEndpoint: "policies/id/\(id)") {
                                    (result: [String:AnyObject]) in
        //                            print("json for policy id: \(id): \(result)")
                                    self.completed += 1
                                    let thePolicy = result["policy"] as! [String:AnyObject]
    //                                    print("thePolicy: \(thePolicy)")
    //                                    NSApplication.shared.terminate(self)
                                    
                                    // check of used packages - start
                                    let packageList = thePolicy["package_configuration"] as! [String:AnyObject]
                                    let policyPackageList = packageList["packages"] as! [Dictionary<String, Any>]
                                    for thePackage in policyPackageList {
    //                                        print("thePackage: \(thePackage)")
                                        let thePackageID = thePackage["id"]
    //                                        print("packages id for policy id: \(id): \(thePackageID!)")
                                        self.packagesDict["\(thePackageID!)"]?["used"] = "true"
                                    }
                                    // check of used packages - end

                                    // check for used scripts - start
                                    let policyScriptList = thePolicy["scripts"] as! [Dictionary<String, Any>]
                                    for theScript in policyScriptList {
    //                                        print("thePackage: \(thePackage)")
                                        let theScriptID = theScript["id"]
    //                                        print("packages id for policy id: \(id): \(thePackageID!)")
                                        self.scriptsDict["\(theScriptID!)"]?["used"] = "true"
                                    }
                                    // check of used scripts - end

                                    // check for used computergroups - start
                                    let computerGroupList = thePolicy["scope"] as! [String:AnyObject]
    //                                    print("computerGroupList: \(computerGroupList)")
                                    let computer_groupList = computerGroupList["computer_groups"] as! [Dictionary<String, Any>]
                                    for theComputerGroup in computer_groupList {
    //                                        print("thePackage: \(thePackage)")
                                        let theComputerGroupID = theComputerGroup["name"]
    //                                        let theComputerGroupID = theComputerGroup["id"]
    //                                        print("packages id for policy id: \(id): \(thePackageID!)")
                                        self.computerGroupsDict["\(theComputerGroupID!)"]?["used"] = "true"
                                    }
                                    // check exclusions - start
                                    let computer_groupExcl = computerGroupList["exclusions"] as! [String:AnyObject]
                                    let computer_groupListExcl = computer_groupExcl["computer_groups"] as! [Dictionary<String, Any>]
                                    for theComputerGroupExcl in computer_groupListExcl {
    //                                        print("thePackage: \(thePackage)")
                                        let theComputerGroupID = theComputerGroupExcl["name"]
    //                                        print("packages id for policy id: \(id): \(thePackageID!)")
                                        self.computerGroupsDict["\(theComputerGroupID!)"]?["used"] = "true"
                                    }
                                    // check exclusions - end
                                    // check of used computergroups - end
                                    
    //                                    print("packages for policy id: \(id): \(packageList)")
                                    if self.completed == policiesArrayCount {
                                        var reportItems = [[String:[String:[String:String]]]]()
                                        if self.packagesButtonState == "on" {
                                            reportItems.append(["packages":self.packagesDict])
                                        }
                                        if self.scriptsButtonState == "on" {
                                            reportItems.append(["scripts":self.scriptsDict])
                                        }
                                        if self.computerGroupsButtonState == "on" {
                                            reportItems.append(["computergroups":self.computerGroupsDict])
                                        }
                                        self.unused(itemDictionary: reportItems)
                                    }
                                }
                            }
                        }   // for i in (0..<policiesArrayCount) - end
                    }
    //                    print("policy dict: \(self.policiesDict)")
                }   //         Json().getRecord - policies - end
            default:
                print("[default] unknown item, exiting...")
                NSApplication.shared.terminate(self)
                DispatchQueue.main.async {
                    self.processItems(type: "initialize")
                }
            }
        }
    }

    func unused(itemDictionary: [[String:Any]]) {
//        print("looking for unused packages")
//        print("packagesDict (\(self.packagesDict.count)): \(self.packagesDict)")
        
        var unusedCount = 0
        var sortedArray = [String]()
        let dictCount   = itemDictionary.count
        
        OperationQueue.main.addOperation {
            self.summary_TextField.string = ""
        }
        for i in (0..<dictCount) {
            let currentDict = itemDictionary[i]
            print("currentDict: \(currentDict)")
            for (type, theDict) in currentDict {
                print("\ntype: \(type)")
                print("theDict: \(theDict)")
                let newDict = theDict as! Dictionary<String,Dictionary<String,String>>
                for (key, _) in newDict {
                    if newDict["\(key)"]?["used"] == "false" {
//                        print("unused \(type): \(newDict[key]!["name"]!)")
                        if type != "computergroups" {
                            sortedArray.append("\(newDict[key]!["name"]!)")
                        } else {
                            sortedArray.append("\(key)")
                        }
                        unusedCount += 1
                    }
                }
                // case insensitive sort - ascending
                sortedArray = sortedArray.sorted{$0.localizedCaseInsensitiveCompare($1) == .orderedAscending}
//                print("\(sortedArray.sorted())")
                displayUnused(key: type, theList: sortedArray)

                unusedCount = 0
                sortedArray.removeAll()
            }
        }
        view_PopUpButton.isEnabled = true
    }
    
    func displayUnused(key: String, theList: [String]) {
//        print("count of unused \(key): \(theList.count)\n")
        OperationQueue.main.addOperation {
            self.summary_TextField.textColor = NSColor.blue
            self.summary_TextField.font = NSFont(name: "HelveticaNeue", size: CGFloat(14))
//            let font = NSFont(name: "HelveticaNeue", size: CGFloat(18))
//            let color = NSColor.blue
//            let attributedText = NSAttributedString(string: "count of unused \(key): \(theList.count)\n", attributes: [NSAttributedString.Key.font : font!, NSAttributedString.Key.foregroundColor : color])
            self.summary_TextField.string.append("count of unused \(key): \(theList.count)\n")
        }
        for theItem in theList {
//          print("\(theItem)")
            // add item to master dictionary of unused items - start
            
            // add item to master dictionary of unused items - end
            let delay = (theList.count == 0) ? 100:theList.count
            // display each unused item
            OperationQueue.main.addOperation {
                self.summary_TextField.string.append("\(theItem)\n")
                usleep(useconds_t(50000/delay))
                self.summary_TextField.scrollToEndOfDocument(self)
            }
        }
        OperationQueue.main.addOperation {
            self.summary_TextField.string.append("\n=============================================================\n\n")
        }
    }
    
    
//    func buildDictionary(type: String, used: String, data: [String:Any]) -> [String:[String:String]] {
    func buildDictionary(type: String, used: String, data: [String:Any]) -> [String:Any] {
        
//        var unusedItemsDictionary = [String:[String:String]]()
        var unusedItemsDictionary = [String:Any]()
        var category            = ""
        
        if let listOfUnused = data[type] {
            for theDict in listOfUnused as! [[String:String]] {
                if type != "unusedComputerGroups" {
                    unusedItemsDictionary[theDict["id"]!] = ["name":theDict["name"]!,"used":"false"]
                } else {
                    unusedItemsDictionary[theDict["name"]!] = ["id":theDict["id"]!,"used":"false"]
                }
            }
        }
        switch type {
        case "unusedPackages":
            category = "packages"
            packagesDict = (unusedItemsDictionary as! [String:[String:String]])
        case "unusedScripts":
            category = "scripts"
        case "unusedComputerGroups":
            category = "computergroups"
        default:
            category = type
        }
//        return packagesDict
        return ["\(category)":unusedItemsDictionary]
    }
    
    @IBAction func view_Action(_ sender: NSButton) {
        var reportItems = [[String:[String:[String:String]]]]()
        if sender.title == "Packages" || sender.title == "All" {
            reportItems.append(["packages":self.packagesDict])
        }
        if sender.title == "Scripts" || sender.title == "All" {
            reportItems.append(["scripts":self.scriptsDict])
        }
        if sender.title == "Computer Groups" || sender.title == "All" {
            reportItems.append(["computergroups":self.computerGroupsDict])
        }
        self.unused(itemDictionary: reportItems)
    }
    
    @IBAction func import_Action(_ sender: Any) {
                
        if let pathToFile = import_Button.url {
            let objPath: URL!
            if let pathOrDirectory = import_Button.url {
                print("fileOrPath: \(pathOrDirectory)")
                
                objPath = URL(string: "\(pathOrDirectory)")!
                var isDir : ObjCBool = false

                sleep(1)
                _ = FileManager.default.fileExists(atPath: objPath.path, isDirectory:&isDir)
                do {
                    let dataFile =  try Data(contentsOf:pathToFile, options: .mappedIfSafe)
                    let objectJSON = try JSONSerialization.jsonObject(with: dataFile, options: .mutableLeaves) as? [String:Any]
                    
                    print("objectJSON: \(String(describing: objectJSON!))")
                    for (key, _) in objectJSON! {
                        print("\(key)")
                        print("buildDictionary: \(buildDictionary(type: key, used: "false", data: objectJSON!))")
                        unused(itemDictionary: [buildDictionary(type: key, used: "false", data: objectJSON!)])
                    }

                } catch {
                    print("file read error")
                    return
                }
            }
        }
    }
    
    
    @IBAction func export_Action(_ sender: Any) {
        
        let timeStamp = Time().getCurrent()
        let exportQ = DispatchQueue(label: "com.jamf.prune.exportQ", qos: DispatchQoS.background)
        
        exportQ.sync {
            if self.packagesButtonState == "on" {
                let packageLogFile = "prunePackages_\(timeStamp).json"
//                let packageLogFile = "prunePackages_\(timeStamp).xml"
                let exportURL = getDownloadDirectory().appendingPathComponent(packageLogFile)

                do {
                    try "{\"unusedPackages\":[\n".write(to: exportURL, atomically: true, encoding: .utf8)
//                    try "<unusedPackages>\n".write(to: exportURL, atomically: true, encoding: .utf8)
                } catch {
                    print("failed to write the following: <unusedPackages>")
                }
                
                if let packageLogFileOp = try? FileHandle(forUpdating: exportURL) {
                    for (key, _) in packagesDict {
                        if packagesDict[key]?["used"]! == "false" {
                            packageLogFileOp.seekToEndOfFile()
                            let text = "\t{\"id\": \"\(key)\", \"name\": \"\(String(describing: packagesDict[key]!["name"]!))\"},\n"
//                            let text = "\t{\"id\": \"\(key)\",\n\"name\": \"\(String(describing: packagesDict[key]!["name"]!))\",\n\"used\": \"false\"},\n"
//                            let text = "\t<id>\(key)</id><name>\(String(describing: packagesDict[key]!["name"]!))</name>\n"
                            packageLogFileOp.write(text.data(using: String.Encoding.utf8)!)
                        }
                    }   // for (key, _) in packagesDict - end
                    packageLogFileOp.seekToEndOfFile()
                    packageLogFileOp.write("]}".data(using: String.Encoding.utf8)!)
//                    packageLogFileOp.write("</unusedPackages>".data(using: String.Encoding.utf8)!)
                    packageLogFileOp.closeFile()
                }
            }
            
            if self.scriptsButtonState == "on" {
                let scriptLogFile = "pruneScripts_\(timeStamp).json"
//                let scriptLogFile = "pruneScripts_\(timeStamp).xml"
                let exportURL = getDownloadDirectory().appendingPathComponent(scriptLogFile)

                do {
                    try "{\"unusedScripts\":[\n".write(to: exportURL, atomically: true, encoding: .utf8)
//                    try "<unusedScripts>\n".write(to: exportURL, atomically: true, encoding: .utf8)
                } catch {
                    print("failed to write the following: <unusedScripts>")
                }
                
                if let scriptLogFileOp = try? FileHandle(forUpdating: exportURL) {
                    for (key, _) in scriptsDict {
                        if scriptsDict[key]?["used"]! == "false" {
                            scriptLogFileOp.seekToEndOfFile()
                            let text = "\t{\"id\": \"\(key)\", \"name\": \"\(String(describing: scriptsDict[key]!["name"]!))\"},\n"
//                            let text = "\t<id>\(key)</id><name>\(String(describing: scriptsDict[key]!["name"]!))</name>\n"
                            scriptLogFileOp.write(text.data(using: String.Encoding.utf8)!)
                        }
                    }   // for (key, _) in scriptsDict - end
                    scriptLogFileOp.seekToEndOfFile()
                    scriptLogFileOp.write("]}".data(using: String.Encoding.utf8)!)
//                    scriptLogFileOp.write("</unusedScripts>".data(using: String.Encoding.utf8)!)
                    scriptLogFileOp.closeFile()
                }
            }
            
            if self.computerGroupsButtonState == "on" {
                let computerGroupLogFile = "pruneComputerGroups_\(timeStamp).json"
//                let computerGroupLogFile = "pruneComputerGroups_\(timeStamp).xml"
                let exportURL = getDownloadDirectory().appendingPathComponent(computerGroupLogFile)

                do {
                    try "{\"unusedComputerGroups\":[\n".write(to: exportURL, atomically: true, encoding: .utf8)
//                    try "<unusedComputerGroups>\n".write(to: exportURL, atomically: true, encoding: .utf8)
                } catch {
                    print("failed to write the following: <unusedComputerGroups>")
                }
                
                if let computerGroupLogFileOp = try? FileHandle(forUpdating: exportURL) {
                    for (key, _) in computerGroupsDict {
                        if computerGroupsDict[key]?["used"]! == "false" {
                            computerGroupLogFileOp.seekToEndOfFile()
                            let text = "\t{\"id\": \"\(String(describing: computerGroupsDict[key]!["id"]!))\", \"name\": \"\(key)\"},\n"
//                            let text = "\t<id>\(String(describing: computerGroupsDict[key]!["id"]!))</id><name>\(key)</name>\n"
                            computerGroupLogFileOp.write(text.data(using: String.Encoding.utf8)!)
                        }
                    }   // for (key, _) in scriptsDict - end
                    computerGroupLogFileOp.seekToEndOfFile()
                    computerGroupLogFileOp.write("]}".data(using: String.Encoding.utf8)!)
//                    computerGroupLogFileOp.write("</unusedComputerGroups>".data(using: String.Encoding.utf8)!)
                    computerGroupLogFileOp.closeFile()
                }
            }
        }
    }
    
    @IBAction func remove_Action(_ sender: Any) {
        
        theDeleteQ.maxConcurrentOperationCount = 3
        
        let viewing = view_PopUpButton.title
        print("[remove] viewing: \(viewing)")
        
        var masterItemsToDeleteArray = [[String:String]]()
        if viewing == "All" || viewing == "Packages" {
            for (key, _) in packagesDict {
                if packagesDict[key]?["used"] == "false" {
//                    print("[remove_Action] remove package with id: \(key)")
                    masterItemsToDeleteArray.append(["packages":key])
                }
            }
        }

        if viewing == "All" || viewing == "Scripts" {
            for (key, _) in scriptsDict {
                if scriptsDict[key]?["used"] == "false" {
//                    print("[remove_Action] remove script with id: \(key)")
                    masterItemsToDeleteArray.append(["scripts":key])
                }
            }
        }

        if viewing == "All" || viewing == "Computer Groups" {
            for (key, _) in computerGroupsDict {
                if computerGroupsDict[key]?["used"] == "false" {
                    let id = "\(String(describing: computerGroupsDict[key]!["id"]!))"
//                    print("[remove_Action] remove computer group with id: \(id)")
                    masterItemsToDeleteArray.append(["computergroups":id])
                }
            }
        }
        

        theDeleteQ.addOperation {
            var counter = 0
            // loop through master list and delete items - start
            for item in masterItemsToDeleteArray {
                for (category, id) in item {
                    Xml().action(action: "DELETE", theServer: self.currentServer, base64Creds: self.jamfBase64Creds, theEndpoint: "\(category)/id/\(id)") {
                        (result: [String:AnyObject]) in
                        print("[remove_Action] removed \(category) with id: \(id)")
//                                        print("json returned packages: \(result)")
                        counter += 1
                        if counter == masterItemsToDeleteArray.count {
                            self.summary_TextField.string = "All removals have been processed."
                        }
                                        
                    }
                }
            }
            // loop through master list and delete items - end
        }
    }
    
    
    func getDownloadDirectory() -> URL {
        let downloadsDirectory = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0]
        return downloadsDirectory
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        
        // configure import button
        import_Button.url          = getDownloadDirectory()
        import_Button.allowedTypes = ["json"]
        
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }


}

