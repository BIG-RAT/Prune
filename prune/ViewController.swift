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
    
    @IBOutlet weak var object_TableView: NSTableView!
    
    
    @IBAction func removeObject_Action(_ sender: Any) {
        let theRow = object_TableView.selectedRow
//        print("selectedRow: \(String(describing: theRow))")
        if let itemName = unusedItems_TableArray?[theRow] {
            if (itemSeperators.firstIndex(of: itemName) ?? -1) == -1 {
                unusedItems_TableArray?.remove(at: theRow)
                object_TableView.reloadData()
            }
        }
    }
    
    @IBOutlet weak var import_Button: NSPathControl!
    
//    @IBAction func removeItem_Action(_ sender: Any) {
//    }
    
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
    
    @IBOutlet weak var process_TextField: NSTextField!
    
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
    var unusedItems_TableArray: [String]?
    var itemSeperators            = [String]()
    
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
        
        unusedItems_TableArray?.removeAll()
        
//        process_TextField.textColor   = NSColor.blue
        process_TextField.font        = NSFont(name: "HelveticaNeue", size: CGFloat(12))
        process_TextField.stringValue = ""
        
        currentServer       = jamfServer_TextField.stringValue
        jamfCreds           = "\(uname_TextField.stringValue):\(passwd_TextField.stringValue)"
        let jamfUtf8Creds   = jamfCreds.data(using: String.Encoding.utf8)
        jamfBase64Creds     = (jamfUtf8Creds?.base64EncodedString())!
        completed           = 0
        
        if unusedItems_TableArray?.count == 0 {
            object_TableView.reloadData()
        }
        
        Json().getToken(serverUrl: currentServer, base64creds: jamfBase64Creds) {
            (result: String) in
            if result != "" {
                DispatchQueue.main.async {
                    self.process_TextField.isHidden = false
                    self.process_TextField.stringValue = "Starting lookups..."
                }
                print("[go_action caller] start lookups...")
                self.processItems(type: "packages")
            }
        }
    }
    
    func processItems(type: String) {
        
        theGetQ.maxConcurrentOperationCount = 3

        theGetQ.addOperation {
            switch type {
                            case "osxconfigurationprofiles":
                                DispatchQueue.main.async {
                                    self.process_TextField.stringValue = "Fetching Computer Configuration Profiles..."
                                }
                                Json().getRecord(theServer: self.currentServer, base64Creds: self.jamfBase64Creds, theEndpoint: "packages") {
                                    (result: [String:AnyObject]) in
                //                    print("json returned packages: \(result)")
                                    let packagesArray = result["packages"] as! [Dictionary<String, Any>]
                                    let packagesArrayCount = packagesArray.count
                                    if packagesArrayCount > 0 {
                                        for i in (0..<packagesArrayCount) {
                                            if let id = packagesArray[i]["id"], let name = packagesArray[i]["name"] {
                                                self.packagesDict["\(name)"] = ["id":"\(id)", "used":"false"]
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
                        self.process_TextField.stringValue = "Fetching Packages..."
                    }
                    Json().getRecord(theServer: self.currentServer, base64Creds: self.jamfBase64Creds, theEndpoint: "packages") {
                        (result: [String:AnyObject]) in
    //                    print("json returned packages: \(result)")
                        let packagesArray = result["packages"] as! [Dictionary<String, Any>]
                        let packagesArrayCount = packagesArray.count
                        if packagesArrayCount > 0 {
                            for i in (0..<packagesArrayCount) {
                                if let id = packagesArray[i]["id"], let name = packagesArray[i]["name"] {
                                    self.packagesDict["\(name)"] = ["id":"\(id)", "used":"false"]
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
                            self.process_TextField.stringValue = "Fetching Scripts..."
                        }
                        Json().getRecord(theServer: self.currentServer, base64Creds: self.jamfBase64Creds, theEndpoint: "scripts") {
                            (result: [String:AnyObject]) in
        //                    print("json returned scripts: \(result)")
                            let scriptsArray = result["scripts"] as! [Dictionary<String, Any>]
                            let scriptsArrayCount = scriptsArray.count
                            if scriptsArrayCount > 0 {
                                for i in (0..<scriptsArrayCount) {
                                    if let id = scriptsArray[i]["id"], let name = scriptsArray[i]["name"] {
                                        self.scriptsDict["\(name)"] = ["id":"\(id)", "used":"false"]
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
                            self.process_TextField.stringValue = "Fetching Computer Groups..."
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
                                    self.process_TextField.stringValue = "Scanning for nexted computer groups..."
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
                        self.process_TextField.stringValue = "Fetching Computer Configurations..."
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
                                self.process_TextField.stringValue = "Scanning Computer Configurations for packages and scripts..."
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
                                            let thePackageName = thePackage["name"]
    //                                        print("packages id for policy id: \(id): \(thePackageID!)")
                                            self.packagesDict["\(thePackageName!)"]?["used"] = "true"
                                        }

                                        let omputerConfigurationScriptList = theComputerConfiguration["scripts"] as! [Dictionary<String, Any>]
                                        for theScript in omputerConfigurationScriptList {
    //                                        print("thePackage: \(thePackage)")
                                            let theScriptName = theScript["name"]
    //                                        print("packages id for policy id: \(id): \(thePackageID!)")
                                            self.scriptsDict["\(theScriptName!)"]?["used"] = "true"
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
                    self.process_TextField.stringValue = "Fetching Policies..."
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
                            self.process_TextField.stringValue = "Scanning policies for packages, scripts, computer groups..."
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
                                        let thePackageName = thePackage["name"]
    //                                        print("packages id for policy id: \(id): \(thePackageID!)")
                                        self.packagesDict["\(thePackageName!)"]?["used"] = "true"
                                    }
                                    // check of used packages - end

                                    // check for used scripts - start
                                    let policyScriptList = thePolicy["scripts"] as! [Dictionary<String, Any>]
                                    for theScript in policyScriptList {
    //                                        print("thePackage: \(thePackage)")
                                        let theScriptName = theScript["name"]
    //                                        print("packages id for policy id: \(id): \(thePackageID!)")
                                        self.scriptsDict["\(theScriptName!)"]?["used"] = "true"
                                    }
                                    // check of used scripts - end

                                    // check for used computergroups - start
                                    let computerGroupList = thePolicy["scope"] as! [String:AnyObject]
    //                                    print("computerGroupList: \(computerGroupList)")
                                    let computer_groupList = computerGroupList["computer_groups"] as! [Dictionary<String, Any>]
                                    for theComputerGroup in computer_groupList {
    //                                        print("thePackage: \(thePackage)")
                                        let theComputerGroupName = theComputerGroup["name"]
    //                                        let theComputerGroupID = theComputerGroup["id"]
    //                                        print("packages id for policy id: \(id): \(thePackageID!)")
                                        self.computerGroupsDict["\(theComputerGroupName!)"]?["used"] = "true"
                                    }
                                    // check exclusions - start
                                    let computer_groupExcl = computerGroupList["exclusions"] as! [String:AnyObject]
                                    let computer_groupListExcl = computer_groupExcl["computer_groups"] as! [Dictionary<String, Any>]
                                    for theComputerGroupExcl in computer_groupListExcl {
    //                                        print("thePackage: \(thePackage)")
                                        let theComputerGroupName = theComputerGroupExcl["name"]
    //                                        print("packages id for policy id: \(id): \(thePackageID!)")
                                        self.computerGroupsDict["\(theComputerGroupName!)"]?["used"] = "true"
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
        
        if unusedItems_TableArray?.count != nil {
            unusedItems_TableArray?.removeAll()
            object_TableView.reloadData()
        }
        
        
        OperationQueue.main.addOperation {
            self.process_TextField.stringValue = ""
        }
        for i in (0..<dictCount) {
            let currentDict = itemDictionary[i]
            print("currentDict: \(currentDict)")
            for (type, theDict) in currentDict {
                print("\ntype: \(type)")
                print("theDict: \(theDict)")
                let currentItem = type
                let newDict = theDict as! Dictionary<String,Dictionary<String,String>>
                for (key, _) in newDict {
                    if newDict["\(key)"]?["used"] == "false" {
                            sortedArray.append("\(key)")
                        unusedCount += 1
                    }
                }
                // case insensitive sort - ascending
                sortedArray = sortedArray.sorted{$0.localizedCaseInsensitiveCompare($1) == .orderedAscending}
//                print("\(sortedArray.sorted())")
                print("unusedItems_TableArray?.count: \(unusedItems_TableArray?.count)")
//                if unusedItems_TableArray?[0] == nil {
                if unusedItems_TableArray?.count != nil {
                    if unusedItems_TableArray?.count == 0 {
                        unusedItems_TableArray = ["----- count of unused \(currentItem): \(sortedArray.count) -----"]
                    } else {
                        unusedItems_TableArray?.append("----- count of unused \(currentItem): \(sortedArray.count) -----")
                    }
                } else {
                    unusedItems_TableArray = ["----- count of unused \(currentItem): \(sortedArray.count) -----"]
                }
                
                itemSeperators.append("----- count of unused \(currentItem): \(sortedArray.count) -----")
                unusedItems_TableArray! += sortedArray
//                print("unusedItems_TableArray: \(String(describing: unusedItems_TableArray))")
                object_TableView.reloadData()
                
//                displayUnused(key: type, theList: sortedArray)

                unusedCount = 0
                sortedArray.removeAll()
            }
        }
        view_PopUpButton.isEnabled = true

        DispatchQueue.main.async {
            self.process_TextField.isHidden = true
        }
    }
    
    func displayUnused(key: String, theList: [String]) {
//        print("count of unused \(key): \(theList.count)\n")
        OperationQueue.main.addOperation {
//            self.process_TextField.textColor = NSColor.blue
            self.process_TextField.font = NSFont(name: "HelveticaNeue", size: CGFloat(14))
//            let font = NSFont(name: "HelveticaNeue", size: CGFloat(18))
//            let color = NSColor.blue
//            let attributedText = NSAttributedString(string: "count of unused \(key): \(theList.count)\n", attributes: [NSAttributedString.Key.font : font!, NSAttributedString.Key.foregroundColor : color])
//            self.process_TextField.string.append("count of unused \(key): \(theList.count)\n")
        }

    }
    
    
//    func buildDictionary(type: String, used: String, data: [String:Any]) -> [String:[String:String]] {
    func buildDictionary(type: String, used: String, data: [String:Any]) -> [String:Any] {
        
//        var unusedItemsDictionary = [String:[String:String]]()
        var unusedItemsDictionary = [String:Any]()
        var category            = ""
        
        if let listOfUnused = data[type] {
            for theDict in listOfUnused as! [[String:String]] {
//                if type != "unusedComputerGroups" {
//                    unusedItemsDictionary[theDict["id"]!] = ["name":theDict["name"]!,"used":"false"]
//                } else {
                    unusedItemsDictionary[theDict["name"]!] = ["id":theDict["id"]!,"used":"false"]
//                }
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
        if sender.title == "Packages" || (sender.title == "All" && packagesButtonState == "on") {
            reportItems.append(["packages":self.packagesDict])
        }
        if sender.title == "Scripts" || (sender.title == "All" && scriptsButtonState == "on") {
            reportItems.append(["scripts":self.scriptsDict])
        }
        if sender.title == "Computer Groups" || (sender.title == "All" && computerGroupsButtonState == "on") {
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
                            let text = "\t{\"id\": \"\(String(describing: packagesDict[key]!["id"]!))\", \"name\": \"\(key)\"},\n"
//                            let text = "\t{\"id\": \"\(key)\", \"name\": \"\(String(describing: packagesDict[key]!["name"]!))\"},\n"
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
                            let text = "\t{\"id\": \"\(String(describing: scriptsDict[key]!["id"]!))\", \"name\": \"\(key)\"},\n"
//                            let text = "\t{\"id\": \"\(key)\", \"name\": \"\(String(describing: scriptsDict[key]!["name"]!))\"},\n"
//                            let text = "\t<id>\(key)</id><name>\(String(describing: scriptsDict[key]!["name"]!))</name>\n"    // old - xml format
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
        
        currentServer       = jamfServer_TextField.stringValue
        jamfCreds           = "\(uname_TextField.stringValue):\(passwd_TextField.stringValue)"
        let jamfUtf8Creds   = jamfCreds.data(using: String.Encoding.utf8)
        jamfBase64Creds     = (jamfUtf8Creds?.base64EncodedString())!
        
        theDeleteQ.maxConcurrentOperationCount = 3
        
        let viewing = view_PopUpButton.title
        print("[remove] viewing: \(viewing)")
        
        var masterItemsToDeleteArray = [[String:String]]()
        if viewing == "All" || viewing == "Packages" {
            for (key, _) in packagesDict {
                if packagesDict[key]?["used"] == "false" {
                    let id = "\(String(describing: packagesDict[key]!["id"]!))"
//                    print("[remove_Action] remove package with id: \(key)")
                    masterItemsToDeleteArray.append(["packages":id])
                }
            }
        }

        if viewing == "All" || viewing == "Scripts" {
            for (key, _) in scriptsDict {
                if scriptsDict[key]?["used"] == "false" {
                    let id = "\(String(describing: scriptsDict[key]!["id"]!))"
//                    print("[remove_Action] remove script with id: \(id)")
                    masterItemsToDeleteArray.append(["scripts":id])
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
            var completed = false
            // loop through master list and delete items - start
            for item in masterItemsToDeleteArray {
                // pause on the first record in a category to make sure we have the permissions to delete
                completed = false
                for (category, id) in item {
                    Xml().action(action: "DELETE", theServer: self.currentServer, base64Creds: self.jamfBase64Creds, theEndpoint: "\(category)/id/\(id)") {
                        (xmlResult: (Int,String)) in
                        let (statusCode, _) = xmlResult
                        if !(statusCode >= 200 && statusCode <= 299) {
                            if "\(statusCode)" == "401" {
                                Alert().display(header: "Alert", message: "Verify username and password.")
                                return
                            }
                        }
                        completed = true
                        
                        print("[remove_Action] removed \(category) with id: \(id)")
//                        print("json returned packages: \(result)")
                        counter += 1
                        if counter == masterItemsToDeleteArray.count {
                            Alert().display(header: "Congratulations", message: "Removal process complete.")
//                            self.process_TextField.stringValue = "All removals have been processed."
//                            sleep(3)
                        }
                                        
                    }   // Xml().action - end
                    while !completed {
                        usleep(500000)
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
        object_TableView.delegate   = self
        object_TableView.dataSource = self
        
        // configure import button
        import_Button.url          = getDownloadDirectory()
        import_Button.allowedTypes = ["json"]
        
        // for testing - start
        jamfServer_TextField.stringValue = "https://coldmizer.jamfcloud.com"
        uname_TextField.stringValue      = "apiread"
        passwd_TextField.stringValue     = "***REMOVED***"
        // for testing - end
        
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }


}


extension ViewController: NSTableViewDataSource {
    func numberOfRows(in object_TableView: NSTableView) -> Int {
//        print("[numberOfRows] \(unusedItems_TableArray?.count ?? 0)")
        return unusedItems_TableArray?.count ?? 0
    }
}

extension ViewController: NSTableViewDelegate {
    
    fileprivate enum CellIdentifiers {
        static let NameCell = "ObjectName_Cell-ID"
    }
    
    func tableView(_ object_TableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        
        var text: String = ""
        var cellIdentifier: String = ""
    
//        print("[func tableView] item: \(unusedItems_TableArray?[row] ?? nil)")
        guard let item = unusedItems_TableArray?[row] else {
            return nil
        }
        
        
        if tableColumn == object_TableView.tableColumns[0] {
//            image = item.icon
            text = "\(item)"
            cellIdentifier = CellIdentifiers.NameCell
        } else if tableColumn == object_TableView.tableColumns[1] {
            print("unused")
           
        }
    
        if let cell = object_TableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: cellIdentifier), owner: nil) as? NSTableCellView {
            cell.textField?.stringValue = text
            return cell
        }
        return nil
    }
    
}
