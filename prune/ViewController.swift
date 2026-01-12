//
//  ViewController.swift
//  prune
//
//  Created by Leslie Helou on 12/11/19.
//  Copyright © 2019 Leslie Helou. All rights reserved.
//

import AppKit
import Cocoa
import Foundation

class ViewController: NSViewController, ImportViewDelegate, SendingLoginInfoDelegate, URLSessionDelegate {
    
    @IBOutlet weak var importLayer: ImportView!
    
    var theGetQ    = OperationQueue() // create operation queue for API POST/PUT calls
    var theDeleteQ = OperationQueue() // queue for delete API calls
    
    private let parser = XMLDotNotationParser()
    
    @IBOutlet weak var jamfServer_TextField: NSTextField!
    
    @IBOutlet weak var scan_Button: NSButton!
    @IBOutlet weak var view_PopUpButton: NSPopUpButton!
    @IBOutlet weak var packages_Button: NSButton!
    @IBOutlet weak var scripts_Button: NSButton!
    @IBOutlet weak var ebooks_Button: NSButton!
    @IBOutlet weak var classes_Button: NSButton!
    @IBOutlet weak var computerGroups_Button: NSButton!
    @IBOutlet weak var computerProfiles_Button: NSButton!
    @IBOutlet weak var macApps_Button: NSButton!
    @IBOutlet weak var policies_Button: NSButton!
    @IBOutlet weak var printers_Button: NSButton!
    @IBOutlet weak var restrictedSoftware_Button: NSButton!
    @IBOutlet weak var computerEAs_Button: NSButton!
    @IBOutlet weak var mobileDeviceGroups_Button: NSButton!
    @IBOutlet weak var mobileDeviceApps_Button: NSButton!
    @IBOutlet weak var configurationProfiles_Button: NSButton!
    @IBOutlet weak var mobileDeviceEAs_Button: NSButton!
    
    @IBOutlet weak var object_TableView: NSTableView!
    
    @IBOutlet weak var spinner_ProgressIndicator: NSProgressIndicator!
    
    @IBOutlet weak var import_Button: NSButton!
    
    @IBOutlet weak var process_TextField: NSTextField!
        
    var username       = ""
    var password       = ""
    
//    var currentServer   = ""
    var jamfCreds       = ""
    var jamfBase64Creds = ""
    var saveCreds       = false
    var completed       = 0
    var logout          = false
    var counter         = 0
    var incrememt       = 0.0
    var itemsToDelete   = 0
    // define master dictionary of items
    // ex. masterObjectDict["packages"] = [package1Name:["id":id1,"name":name1],package2Name:["id":id2,"name":name2]]
    var masterObjectDict = [String:[String:[String:String]]]()
    var masterObjects    = ["advancedcomputersearches", "advancedmobiledevicesearches", "packages", "osxconfigurationprofiles", "scripts", "ebooks", "classes", "computerGroups", "macapplications", "policies", "printers", "restrictedsoftware", "computerextensionattributes", "mobileDeviceGroups", "mobiledeviceapplications", "mobiledeviceconfigurationprofiles", "computer-prestages", "patchpolicies", "patchsoftwaretitles", "mobiledeviceextensionattributes"]
    
    var unusedItems_TableArray: [String]?
    var unusedItems_TableDict: [[String:String]]?
    
    var computerGroupNameByIdDict   = [Int:String]()
    var mobileGroupNameByIdDict     = [Int:String]()
    var packagesByIdDict            = [String:String]()
    var computerProfilesByIdDict    = [String:String]()
    
    var itemSeperators              = [String]()
    var isDir: ObjCBool             = true
    
    var packagesButtonState              = "off"
    var scriptsButtonState               = "off"
    var ebooksButtonState                = "off"
    var classesButtonState               = "off"
    var computerGroupsButtonState        = "off"
    var computerProfilesButtonState      = "off"
    var macAppsButtonState               = "off"
    var policiesButtonState              = "off"
    var printersButtonState              = "off"
    var restrictedSoftwareButtonState    = "off"
    var computerEAsButtonState           = "off"
    var mobileDeviceGroupsButtonState    = "off"
    var mobileDeviceAppsButtonState      = "off"
    var configurationProfilesButtonState = "off"
    var mobileDeviceEAsButtonState       = "off"
    
    var computerGroupsScanned            = false
    
    var msgText    = ""
    var nextObject = ""
    
    let myParagraphStyle = NSMutableParagraphStyle()
    
    let backgroundQ = DispatchQueue(label: "com.jamf.prune.backgroundQ", qos: DispatchQoS.background)
    
    @IBAction func logout_Action(_ sender: Any) {
        
        unusedItems_TableArray?.removeAll()
        unusedItems_TableDict?.removeAll()
        object_TableView.reloadData()
        setAllButtonsState(theState: "off")
        
        setViewButton(setOn: false)
        LoginWindow.show = true
        JamfPro.shared.jpapiAction(serverUrl: JamfProServer.source, endpoint: "auth/invalidate-token", apiData: [:], id: "", token: JamfProServer.accessToken, method: "POST") { [self]
            (returnedJSON: [String:Any]) in
            WriteToLog.shared.message("logging out: \(String(describing: returnedJSON["JPAPI_result"]!))")
            JamfProServer.validToken = false
            JamfProServer.version    = ""
            performSegue(withIdentifier: "loginView", sender: nil)
        }
    }
    
    @objc func logoutNotification(_ notification: Notification) {
        DistributedNotificationCenter.default.removeObserver(self, name: .logoutNotification, object: nil)
        spinner_ProgressIndicator.stopAnimation(self)
        process_TextField.isHidden = true
        process_TextField.stringValue = ""
        scan_Button.isEnabled = true
        allButtonsEnabledState(theState: true)
    }
    
    @IBAction func scan_action(_ sender: Any) {
        didRun = true
        working(isWorking: true)
        NotificationCenter.default.addObserver(self, selector: #selector(logoutNotification(_:)), name: .logoutNotification, object: nil)
        
        waitFor.deviceGroup             = true   // used for both computer and mobile device groups
        waitFor.computerConfiguration   = true
        waitFor.computerPrestage        = true
        waitFor.osxconfigurationprofile = true
        waitFor.packages                = true
        waitFor.policy                  = true
//        waitFor.printers                = true
        waitFor.mobiledeviceobject      = true
        waitFor.ebook                   = true
        waitFor.classes                 = true
        waitFor.advancedsearch          = true
        
        computerGroupsScanned           = false
        view_PopUpButton.isEnabled      = false
        setViewButton(setOn: true)
        view_PopUpButton.selectItem(at: 0)
        
        mobileGroupNameByIdDict.removeAll()
        masterObjectDict.removeAll()
        failedLookup.removeAll()
        
        unusedItems_TableArray?.removeAll()
        unusedItems_TableDict?.removeAll()
        
        process_TextField.font        = NSFont(name: "HelveticaNeue", size: CGFloat(16))
        process_TextField.stringValue = ""
        
        jamfCreds            = "\(JamfProServer.username):\(JamfProServer.password)"
        let jamfUtf8Creds    = jamfCreds.data(using: String.Encoding.utf8)
        jamfBase64Creds      = (jamfUtf8Creds?.base64EncodedString())!
        completed            = 0
        
        sourceServer = ServerInfo(url: JamfProServer.source, username: JamfProServer.username, password: JamfProServer.password, saveCreds: defaults.object(forKey: "saveCreds") as? Int ?? 0, useApiClient: 0)
        
        if unusedItems_TableArray?.count == 0 {
            object_TableView.reloadData()
        }
        
        JamfPro.shared.getToken(serverUrl: JamfProServer.source, whichServer: "source", base64creds: jamfBase64Creds) { [self]
            (result: (Int,String)) in
            let (statusCode, theResult) = result
            if theResult == "success" {
                DispatchQueue.main.async { [self] in
                    process_TextField.isHidden = false
                    process_TextField.stringValue = "Starting lookups..."
                }
                // initialize masterObjectsDict
                masterObjectDict.removeAll()
                for theObject in masterObjects {
                    masterObjectDict[theObject] = [String:[String:String]]()
                }
                WriteToLog.shared.message("[Scan] start scanning...")
                
                if computerEAsButtonState == "on" {
                    processItems(type: "computerextensionattributes")
                } else {
                    processItems(type: "mobiledeviceextensionattributes")
                }
                //                if computerGroupsButtonState == "on" {
                //                    processItems(type: "computerGroups")
                //                } else {
                //                    processItems(type: "mobileDeviceGroups")
                //                }
                
            } else {
                DispatchQueue.main.async { [self] in
                    working(isWorking: false)
                }
            }
        }
    }
    
    @IBAction func showLogFolder(_ sender: Any) {
        isDir = true
        if (FileManager.default.fileExists(atPath: Log.path, isDirectory: &isDir)) {
            NSWorkspace.shared.open(URL(fileURLWithPath: Log.path))
        } else {
            _ = Alert.shared.display(header: "Alert", message: "There are currently no log files to display.")
        }
    }
    
    func processItems(type: String) {
        
        WriteToLog.shared.message("[processItems] Starting to process \(type)")

        theGetQ.maxConcurrentOperationCount = 4
        var groupType = ""

        theGetQ.addOperation { [self] in
                        
            switch type {
            case "computerextensionattributes","mobiledeviceextensionattributes":
                var deviceText = ""

                WriteToLog.shared.message("[processItems] \(type)")
                switch type {
                case "computerextensionattributes":
                    nextObject = "mobiledeviceextensionattributes"
                    deviceText = "Computer"
                case "mobiledeviceextensionattributes":
                    nextObject = (computerGroupsButtonState == "on") ? "computerGroups":"mobileDeviceGroups"
                    deviceText = "Moble Device"
                default:
                    break
                }
                
                if self.computerEAsButtonState == "on" || mobileDeviceEAsButtonState == "on" {
                
                   DispatchQueue.main.async {
                          self.process_TextField.stringValue = "Fetching \(deviceText) Extension Attributes..."
                   }

                   var eaArray = [[String:Any]]()
                   
                    self.xmlAction(action: "GET", theServer: JamfProServer.source, base64Creds: self.jamfBase64Creds, theEndpoint: type) { [self]
                       (result: (Int,String)) in
                        let (statusCode,returnedXml) = result
//                        print("[processItems] returnedXml: \(statusCode)")

                        guard let parsedXmlData = parser.parse(string: returnedXml) else {
                           WriteToLog.shared.message("[processItme] failed to parse returnedXml: \(returnedXml)")
                           return
                        }
                        
                        let allEAs = (type == "computerextensionattributes") ? parsedXmlData.all("computer_extension_attribute") : parsedXmlData.all("mobile_device_extension_attribute")

                        for eaInfo in allEAs {
                            if let id = eaInfo.id?.intValue, let name = eaInfo.name?.value {

                                let enabled = eaInfo.enabled?.boolValue ?? true

                                WriteToLog.shared.message("\(deviceText.lowercased()) extension attribute title id: \(id)      name: \(name)      enabled: \(enabled)")
                                let eaDisplayName = enabled ? name:"\(name)    [disabled]"
                                eaArray.append(["id": "\(id)", "name": "\(eaDisplayName)"])
                               // mark advanced search title as unused (reporting only)
                                self.masterObjectDict[type]!["\(eaDisplayName)"] = ["id":"\(id)", "used":"false", "enabled":"\(enabled)"]
                           }
                       }
                        self.masterObjectDict[type]!["AD Users"]?["used"] = "true"
                        DispatchQueue.main.async { [self] in
                            self.processItems(type: nextObject)
                        }
                    }
                } else {
                    // skip EAs
                    WriteToLog.shared.message("[processItems] skipping \(deviceText.lowercased()) extension attributes, calling - \(nextObject)")
                    DispatchQueue.main.async { [self] in
                        self.processItems(type: nextObject)
                    }
                }
            
            case "computerGroups", "mobileDeviceGroups":
                if self.computerGroupsButtonState == "on" || self.mobileDeviceGroupsButtonState == "on" || self.computerEAsButtonState == "on" || mobileDeviceEAsButtonState == "on" {
                    DispatchQueue.main.async {
                        self.process_TextField.stringValue = "Fetching Groups..."
                    }
                                        
                    // what if we're doing both computer and mobile device groups/EAs
                    let groupEndpoint = (type == "computerGroups" || (type == "mobileDeviceGroups" && computerEAsButtonState == "on" && !computerGroupsScanned)) ? "computergroups":"mobiledevicegroups"
                   
                    Json.shared.getRecord(theServer: JamfProServer.source, base64Creds: self.jamfBase64Creds, theEndpoint: groupEndpoint) {
                        (result: [String:AnyObject]) in
//                            print("json returned scripts: \(result)")
                        if let _ = result["Alert"] as? String {
                            self.working(isWorking: false)
                            return
                        }
                        let computerGroupsArray = (groupEndpoint == "computergroups") ? result["computer_groups"] as! [[String: Any]]:result["mobile_device_groups"] as! [[String: Any]]

                        let computerGroupsArrayCount = computerGroupsArray.count
                        if computerGroupsArrayCount > 0 {

                            // loop through all groups and mark as unused
                            // skip All managed clients / servers
                            for i in (0..<computerGroupsArrayCount) {
                                if let id = computerGroupsArray[i]["id"], let name = computerGroupsArray[i]["name"], let isSmart = computerGroupsArray[i]["is_smart"] {
                                    // skip by id rather than name?
                                    if (isSmart as! Bool) {
                                        groupType = (type == "computerGroups") ? "smartComputerGroup":"smartMobileDeviceGroup"
                                    } else {
                                        groupType = (type == "computerGroups") ? "staticComputerGroup":"staticMobileDeviceGroup"
                                    }
                                    if type == "computerGroups" {
                                        if "\(name)" != "All Managed Clients" && "\(name)" != "All Managed Servers" {
                                            self.masterObjectDict[type]!["\(name)"] = ["id":"\(id)", "used":"false", "groupType":"\(groupType)"]
//                                                self.computerGroupNameById[id as! Int] = "\(name)"
                                        }
                                    } else {
                                        if "\(name)" != "All Managed iPads" && "\(name)" != "All Managed iPhones" && "\(name)" != "All Managed iPod touches" {
                                            self.masterObjectDict[type]!["\(name)"] = ["id":"\(id)", "used":"false", "groupType":"\(groupType)"]
                                            // used for classes, that list only group id
                                            self.mobileGroupNameByIdDict[id as! Int] = "\(name)"
                                        }
                                    }
                                        
                                }
                            }   // for i in (0..<computerGroupsArrayCount) - end
                            // look for nested device groups
                            DispatchQueue.main.async {
                                self.process_TextField.stringValue = "Scanning for nested groups and extensions attributes..."
                            }
                            WriteToLog.shared.message("[processItems] call recursiveLookup for \(type)")
                            self.recursiveLookup(theServer: JamfProServer.source, base64Creds: self.jamfBase64Creds, theEndpoint: groupEndpoint, theData: computerGroupsArray, index: 0)
                            waitFor.deviceGroup = true
                            self.backgroundQ.async { [self] in
                                while true {
                                    usleep(10)
                                    if !waitFor.deviceGroup {
                                        if type == "computerGroups" || (!computerGroupsScanned && computerEAsButtonState == "on") {
//                                                print("[processItems] skipping \(type) - call mobileDeviceGroups")
                                            WriteToLog.shared.message("[processItems] skipping \(type) - call mobileDeviceGroups")
                                            computerGroupsScanned = true
                                            DispatchQueue.main.async {
                                                self.processItems(type: "mobileDeviceGroups")
                                            }
                                            
                                        } else {
//                                                print("[processItems] skipping \(type) - call packages")
                                            WriteToLog.shared.message("[processItems] skipping \(type) - call packages")
                                            DispatchQueue.main.async {
                                                self.processItems(type: "packages")
                                            }
                                        }
                                        break
                                    }
                                }
                            }
                        }
                    }
                } else {
                    if type == "computerGroups" {
                        WriteToLog.shared.message("[processItems] skipping \(type) - call mobileDeviceGroups")
                        DispatchQueue.main.async {
                            self.processItems(type: "mobileDeviceGroups")
                        }
                        
                    } else {
                        WriteToLog.shared.message("[processItems] skipping \(type) - call packages")
                        DispatchQueue.main.async {
                            self.processItems(type: "packages")
                        }
                    }
                }   // if self.computerGroupsButtonState == "on" - end
                     
                
            case "packages":
                if self.packagesButtonState == "on" {
                    DispatchQueue.main.async {
                        self.process_TextField.stringValue = "Fetching Packages..."
                    }
                    
                    /*
                    // get list of JCDS2 packages
                    Json.shared.getRecord(theServer: JamfProServer.source, base64Creds: self.jamfBase64Creds, theEndpoint: "jcds2Packages") {
                        (result: [String:AnyObject]) in
//                        print("[jcds2] result: \(result)")
                        
                        Json.shared.getRecord(theServer: JamfProServer.source, base64Creds: self.jamfBase64Creds, theEndpoint: "packages") { [self]
                            (result: [String:AnyObject]) in

                            if let _  = result["packages"] {
                                let packagesArray = result["packages"] as! [[String:Any]]
                                let packagesArrayCount = packagesArray.count
                                // loop through all packages and mark as unused
                                if packagesArrayCount > 0 {
                                    for i in (0..<packagesArrayCount) {
                                        if let id = packagesArray[i]["id"], let name = packagesArray[i]["name"] {
                                            if "\(name)" != "" {
                                                self.masterObjectDict["packages"]!["\(name)"] = ["id":"\(id)", "used":"false"]
                                                self.packagesByIdDict["\(id)"] = "\(name)"
                                            }
                                        }
                                    }
                                    
                                    WriteToLog.shared.message("[processItems] call recursiveLookup for \(type)")
                                    packageIdFileNameDict = [:]
                                    recursiveLookup(theServer: JamfProServer.source, base64Creds: self.jamfBase64Creds, theEndpoint: type, theData: packagesArray, index: 0)
                                    waitFor.packages = true
                                    self.backgroundQ.async { [self] in
                                        while true {
                                            usleep(10)
                                            if !waitFor.packages {
                                                WriteToLog.shared.message("[processItems] packages complete - next object: scripts")
                                                DispatchQueue.main.async { [self] in
                                                    self.processItems(type: "scripts")
                                                }
                                                print("[processItems.packages] id to filename: \(packageIdFileNameDict)")
                                                break
                                            }
                                        }
                                    }
                                    
                                    
                                }
                            } else {
                                WriteToLog.shared.message("[processItems] call scripts")
                                DispatchQueue.main.async {
                                    self.processItems(type: "scripts")
                                }
                            }
                        }
                    }
                    */
                    
                    Json.shared.getRecord(theServer: JamfProServer.source, base64Creds: self.jamfBase64Creds, theEndpoint: "packages") {
                        (result: [String:AnyObject]) in
                        if let _ = result["Alert"] as? String {
                            self.working(isWorking: false)
                            return
                        }

                        if let _  = result["packages"] {
                            let packagesArray = result["packages"] as! [[String:Any]]
                            let packagesArrayCount = packagesArray.count
                            // loop through all packages and mark as unused
                            if packagesArrayCount > 0 {
                                for i in (0..<packagesArrayCount) {
                                    if let id = packagesArray[i]["id"], let name = packagesArray[i]["name"] {
                                        if "\(name)" != "" {
                                            self.masterObjectDict["packages"]!["\(name)"] = ["id":"\(id)", "used":"false"]
                                            self.packagesByIdDict["\(id)"] = "\(name)"
                                        }
                                    }
                                }
                            }
                        }
                        WriteToLog.shared.message("[processItems] call printers")
                        DispatchQueue.main.async {
                            self.processItems(type: "printers")
                        }
                    }
                } else {
                    WriteToLog.shared.message("[processItems] skipping packages - call printers")
                    DispatchQueue.main.async {
                        self.processItems(type: "printers")
                    }
                }
                
            case "printers":
                if self.printersButtonState == "on" {
                    DispatchQueue.main.async {
                        self.process_TextField.stringValue = "Fetching Printers..."
                    }
                    Json.shared.getRecord(theServer: JamfProServer.source, base64Creds: self.jamfBase64Creds, theEndpoint: "printers") {
                        (result: [String:AnyObject]) in
                        if let _ = result["Alert"] as? String {
                            self.working(isWorking: false)
                            return
                        }
                        if let _  = result[type] {
                            let objectsArray = result[type] as! [[String:Any]]
                            let objectsArrayCount = objectsArray.count
                            if objectsArrayCount > 0 {
                                for i in (0..<objectsArrayCount) {
                                    if let id = objectsArray[i]["id"], let name = objectsArray[i]["name"] {
                                        if "\(name)" != "" {
                                            self.masterObjectDict[type]!["\(name)"] = ["id":"\(id)", "used":"false"]
                                        }
                                    }
                                }
                            }
                        }
                        
                        WriteToLog.shared.message("[processItems] printers complete - call scripts")
                        DispatchQueue.main.async {
                            self.processItems(type: "scripts")
                        }
                    }
                } else {
                    WriteToLog.shared.message("[processItems] skipping scripts - call scripts")
                    DispatchQueue.main.async {
                        self.processItems(type: "scripts")
                    }
               }
                
            case "scripts":
                if self.scriptsButtonState == "on" {
                    DispatchQueue.main.async {
                        self.process_TextField.stringValue = "Fetching Scripts..."
                    }
                    Json.shared.getRecord(theServer: JamfProServer.source, base64Creds: self.jamfBase64Creds, theEndpoint: "scripts") {
                        (result: [String:AnyObject]) in
                        if let _ = result["Alert"] as? String {
                            self.working(isWorking: false)
                            return
                        }
                        if let _  = result[type] {
                            let objectsArray = result[type] as! [[String:Any]]
                            let objectsArrayCount = objectsArray.count
                            if objectsArrayCount > 0 {
                                for i in (0..<objectsArrayCount) {
                                    if let id = objectsArray[i]["id"], let name = objectsArray[i]["name"] {
                                        if "\(name)" != "" {
                                            self.masterObjectDict[type]!["\(name)"] = ["id":"\(id)", "used":"false"]
                                        }
                                    }
                                }
                            }
                        }
                        
                        WriteToLog.shared.message("[processItems] scripts complete - call eBooks")
                        DispatchQueue.main.async {
                            self.processItems(type: "ebooks")
                        }
                    }
                } else {
                    WriteToLog.shared.message("[processItems] skipping scripts - call eBooks")
                    DispatchQueue.main.async {
                        self.processItems(type: "ebooks")
                    }
               }
                
            case "ebooks":
                msgText    = "eBooks"
                nextObject = "classes"
                
                if self.computerGroupsButtonState == "on" || self.mobileDeviceGroupsButtonState == "on" || self.ebooksButtonState == "on" {
                    DispatchQueue.main.async { [self] in
                        self.process_TextField.stringValue = "Fetching \(msgText)..."
                    }
                    Json.shared.getRecord(theServer: JamfProServer.source, base64Creds: self.jamfBase64Creds, theEndpoint: "ebooks") { [self]
                        (result: [String:AnyObject]) in
                        if let _ = result["Alert"] as? String {
                            self.working(isWorking: false)
                            return
                        }
    //                    print("json returned eBooks: \(result)")
                        let ebooksArray = result["ebooks"] as! [[String:Any]]
                        let ebooksArrayCount = ebooksArray.count
                        if ebooksArrayCount > 0 {
                            for i in (0..<ebooksArrayCount) {
                                if let id = ebooksArray[i]["id"], let name = ebooksArray[i]["name"] {
                                    if "\(name)" != "" {
                                        self.masterObjectDict[type]!["\(name)"] = ["id":"\(id)", "used":"false"]
                                    }
                                }
                            }
                            
                            WriteToLog.shared.message("[processItems] call recursiveLookup for \(type)")
                            self.recursiveLookup(theServer: JamfProServer.source, base64Creds: self.jamfBase64Creds, theEndpoint: type, theData: ebooksArray, index: 0)
                            waitFor.ebook = true
                            self.backgroundQ.async { [self] in
                                while true {
                                    usleep(10)
                                    if !waitFor.ebook {
                                        WriteToLog.shared.message("[processItems] \(msgText) complete - next object: \(nextObject)")
                                        DispatchQueue.main.async { [self] in
                                            self.processItems(type: nextObject)
                                        }
                                        break
                                    }
                                }
                            }
                        } else {
                            WriteToLog.shared.message("[processItems] \(msgText) complete - call \(nextObject)")
                            DispatchQueue.main.async { [self] in
                                self.processItems(type: "\(nextObject)")
                            }
                        }
                    }
                } else {
                    WriteToLog.shared.message("[processItems] skipping \(msgText) - call \(nextObject)")
                    DispatchQueue.main.async { [self] in
                        self.processItems(type: "\(nextObject)")
                    }
               }
                
            case "classes":
                msgText    = "classes"
                nextObject = "osxconfigurationprofiles"
                
                if self.mobileDeviceGroupsButtonState == "on" || self.classesButtonState == "on" {
                    DispatchQueue.main.async { [self] in
                        self.process_TextField.stringValue = "Fetching \(msgText)..."
                    }
                    Json.shared.getRecord(theServer: JamfProServer.source, base64Creds: self.jamfBase64Creds, theEndpoint: "classes") { [self]
                        (result: [String:AnyObject]) in
                        if let _ = result["Alert"] as? String {
                            self.working(isWorking: false)
                            return
                        }
    //                    print("json returned classes: \(result)")
                        let classesArray = result["classes"] as! [[String: Any]]
                        let classesArrayCount = classesArray.count
                        if classesArrayCount > 0 {
                            for i in (0..<classesArrayCount) {
                                if let id = classesArray[i]["id"], let name = classesArray[i]["name"] {
                                    if "\(name)" != "" {
                                        self.masterObjectDict[type]!["\(name)"] = ["id":"\(id)", "used":"false"]
                                    }
                                }
                            }
                            
                            WriteToLog.shared.message("[processItems] call recursiveLookup for \(type)")
                            self.recursiveLookup(theServer: JamfProServer.source, base64Creds: self.jamfBase64Creds, theEndpoint: type, theData: classesArray, index: 0)
                            waitFor.classes = true
                            self.backgroundQ.async { [self] in
                                while true {
                                    usleep(10)
                                    if !waitFor.classes {
                                        WriteToLog.shared.message("[processItems] \(msgText) complete - next object: \(nextObject)")
                                        DispatchQueue.main.async { [self] in
                                            self.processItems(type: nextObject)
                                        }
                                        break
                                    }
                                }
                            }
                        } else {
                            WriteToLog.shared.message("[processItems] \(msgText) complete - call \(nextObject)")
                            DispatchQueue.main.async { [self] in
                                self.processItems(type: "\(nextObject)")
                            }
                        }
                    }
                } else {
                    WriteToLog.shared.message("[processItems] skipping \(msgText) - call \(nextObject)")
                    DispatchQueue.main.async { [self] in
                        self.processItems(type: "\(nextObject)")
                    }
               }
                               
            // object that have a scope - start
//                case "computerConfigurations":
//                    if self.packagesButtonState == "on" || self.scriptsButtonState == "on" {
//                        DispatchQueue.main.async {
//                            self.process_TextField.stringValue = "Fetching Computer Configurations..."
//                        }
//                        Json.shared.getRecord(theServer: JamfProServer.source, base64Creds: self.jamfBase64Creds, theEndpoint: "computerconfigurations") {
//                            (result: [String:AnyObject]) in
//                            print("json returned: \(result)")
//                            self.completed = 0
//                            let computerConfigurationsArray = result["computer_configurations"] as! [[String: Any]]
//                            let computerConfigurationsArrayCount = computerConfigurationsArray.count
//                            if computerConfigurationsArrayCount > 0 {
//                                // loop through all the computerConfigurations
//                                DispatchQueue.main.async {
//                                    self.process_TextField.stringValue = "Scanning Computer Configurations for packages and scripts..."
//                                }
//                                self.recursiveLookup(theServer: JamfProServer.source, base64Creds: self.jamfBase64Creds, theEndpoint: "computerconfigurations", theData: computerConfigurationsArray, index: 0)
//                                waitFor.computerConfiguration = true
//                                self.backgroundQ.async {
//                                    while true {
//                                        usleep(10)
//                                        if !waitFor.computerConfiguration {
//                                            WriteToLog.shared.message("[processItems] computerConfigurations complete - call osxconfigurationprofiles")
//                                            DispatchQueue.main.async {
//                                                self.processItems(type: "osxconfigurationprofiles")
//                                            }
//                                            break
//                                        }
//                                    }
//                                }
//
//                            } else {
//                                // no computer configurations exist
//                                WriteToLog.shared.message("[processItems] no computerConfigurations - call osxconfigurationprofiles")
//                                DispatchQueue.main.async {
//                                    self.processItems(type: "osxconfigurationprofiles")
//                                }
//                            }
//                        }   //         Json.shared.getRecord - computerConfigurations - end
//                    } else {
//                        WriteToLog.shared.message("[processItems] skipping computerConfigurations - call osxconfigurationprofiles")
//                        DispatchQueue.main.async {
//                            self.processItems(type: "osxconfigurationprofiles")
//                        }
//                    }
                                                
            case "osxconfigurationprofiles":
                if self.computerGroupsButtonState == "on" || self.computerProfilesButtonState == "on" || self.printersButtonState == "on" {
                    DispatchQueue.main.async {
                        self.process_TextField.stringValue = "Fetching Computer Configuration Profiles..."
                    }
                    Json.shared.getRecord(theServer: JamfProServer.source, base64Creds: self.jamfBase64Creds, theEndpoint: type) {
                        (result: [String:AnyObject]) in
                        if let _ = result["Alert"] as? String {
                            self.working(isWorking: false)
                            return
                        }
//                            self.masterObjectDict["osxconfigurationprofiles"] = [String:[String:String]]()
                        if let _  = result["os_x_configuration_profiles"] {
                            let osxconfigurationprofilesArray = result["os_x_configuration_profiles"] as! [[String: Any]]
                            let osxconfigurationprofilesArrayCount = osxconfigurationprofilesArray.count
                            if osxconfigurationprofilesArrayCount > 0 {
                                for i in (0..<osxconfigurationprofilesArrayCount) {
                                    
                                    if let id = osxconfigurationprofilesArray[i]["id"], let name = osxconfigurationprofilesArray[i]["name"] {
                                        self.masterObjectDict["osxconfigurationprofiles"]!["\(name)"] = ["id":"\(id)", "used":"false"]
                                        self.computerProfilesByIdDict["\(id)"] = "\(name)"
                                    }
                                }
                                
                                waitFor.osxconfigurationprofile = true
                                self.backgroundQ.async {
                                    while true {
                                        usleep(10)
                                        if !waitFor.osxconfigurationprofile {
                                            WriteToLog.shared.message("[processItems] osxconfigurationprofiles complete - call mobiledeviceapplications")
                                            if self.mobileDeviceAppsButtonState == "on" || self.mobileDeviceGroupsButtonState == "on" {
                                                DispatchQueue.main.async {
                                                    self.processItems(type: "mobiledeviceapplications")
                                                }
                                            } else {
                                                DispatchQueue.main.async {
                                                    self.processItems(type: "mobiledeviceconfigurationprofiles")
                                                }
                                            }   // if self.mobileDeviceAppsButtonState == "on" - end
                                            break
                                        }   // if !waitFor.osxconfigurationprofile - end
                                    }
                                }
                                WriteToLog.shared.message("[processItems] call recursiveLookup for osxconfigurationprofiles")
                                self.recursiveLookup(theServer: JamfProServer.source, base64Creds: self.jamfBase64Creds, theEndpoint: "osxconfigurationprofiles", theData: osxconfigurationprofilesArray, index: 0)
                            } else {
                                // no computer profiles exist
                                waitFor.osxconfigurationprofile = false
                                WriteToLog.shared.message("[processItems] computer configuration profiles complete - call mobiledeviceapplications")
                                if self.mobileDeviceAppsButtonState == "on" || self.mobileDeviceGroupsButtonState == "on" {
                                    DispatchQueue.main.async {
                                        self.processItems(type: "mobiledeviceapplications")
                                    }
                                } else {
                                    DispatchQueue.main.async {
                                        self.processItems(type: "mobiledeviceconfigurationprofiles")
                                    }
                                }   // if self.mobileDeviceAppsButtonState == "on" - end
                            }
                        } else {
                            WriteToLog.shared.message("[processItems] unable to read computer configuration profiles - call mobiledeviceapplications")
                            waitFor.osxconfigurationprofile = false
                            if self.mobileDeviceAppsButtonState == "on" || self.mobileDeviceGroupsButtonState == "on" {
                                DispatchQueue.main.async {
                                    self.processItems(type: "mobiledeviceapplications")
                                }
                            } else {
                                DispatchQueue.main.async {
                                    self.processItems(type: "mobiledeviceconfigurationprofiles")
                                }
                            }   // if self.mobileDeviceAppsButtonState == "on" - end
                        }
                    }
                } else {
                    // skip computer configuration profiles
                    WriteToLog.shared.message("[processItems] skipping computer configuration profiles - call mobiledeviceapplications")
                    waitFor.osxconfigurationprofile = false
                    if self.mobileDeviceAppsButtonState == "on" || self.mobileDeviceGroupsButtonState == "on" {
                        DispatchQueue.main.async {
                            self.processItems(type: "mobiledeviceapplications")
                        }
                    } else {
                        DispatchQueue.main.async {
                            self.processItems(type: "mobiledeviceconfigurationprofiles")
                        }
                    }   // if self.mobileDeviceAppsButtonState == "on" - end
                }
                                                            
            case "mobiledeviceapplications", "mobiledeviceconfigurationprofiles":
                msgText    = "mobile device profiles"
                nextObject = "app-installers"
                
                if (type == "mobiledeviceapplications" && self.mobileDeviceAppsButtonState == "on") || self.mobileDeviceGroupsButtonState == "on" || (type == "mobiledeviceconfigurationprofiles" && self.configurationProfilesButtonState == "on") {
                    var xmlTag = ""
                    DispatchQueue.main.async { [self] in
                        if type == "mobiledeviceapplications" || (type == "mobiledeviceapplications" && self.mobileDeviceGroupsButtonState == "on") {
                            xmlTag     = "mobile_device_applications"
                            nextObject = "mobiledeviceconfigurationprofiles"
                            msgText    = "mobile device apps"
                            self.process_TextField.stringValue = "Fetching Mobile Device Apps..."
                        } else {
                            xmlTag = "configuration_profiles"
                            self.process_TextField.stringValue = "Fetching Mobile Device Configuration Profiles..."
                        }
                    }
                    Json.shared.getRecord(theServer: JamfProServer.source, base64Creds: self.jamfBase64Creds, theEndpoint: type) { [self]
                        (result: [String:AnyObject]) in
                        if let _ = result["Alert"] as? String {
                            self.working(isWorking: false)
                            return
                        }
//                            self.masterObjectDict[type] = [String:[String:String]]()
                        if let _ = result[xmlTag] {
                            let mobileDeviceObjectArray = result[xmlTag] as! [[String: Any]]
                            let mobileDeviceObjectArrayCount = mobileDeviceObjectArray.count
                            if mobileDeviceObjectArrayCount > 0 {
                                for i in (0..<mobileDeviceObjectArrayCount) {
                                    
                                    if let id = mobileDeviceObjectArray[i]["id"], let name = mobileDeviceObjectArray[i]["name"] {
                                        self.masterObjectDict[type]!["\(name)"] = ["id":"\(id)", "used":"false"]
                                    }
                                }

                                waitFor.mobiledeviceobject = true
                                self.backgroundQ.async { [self] in
                                    while true {
                                        usleep(10)
                                        if !waitFor.mobiledeviceobject {
                                            WriteToLog.shared.message("[processItems] \(msgText) complete - next object: \(nextObject)")
                                            DispatchQueue.main.async { [self] in
                                                self.processItems(type: nextObject)
                                            }
                                            break
                                        }
                                    }
                                }
                                WriteToLog.shared.message("[processItems] call recursiveLookup for \(type)")
                                self.recursiveLookup(theServer: JamfProServer.source, base64Creds: self.jamfBase64Creds, theEndpoint: type, theData: mobileDeviceObjectArray, index: 0)
                            } else {
                                // no computer configurations exist
                                WriteToLog.shared.message("[processItems] \(msgText) complete - \(nextObject)")
                                DispatchQueue.main.async { [self] in
                                    self.processItems(type: nextObject)
                                }
                            }
                        } else {
                            WriteToLog.shared.message("[processItems] unable to read \(msgText) - \(nextObject)")
                            waitFor.mobiledeviceobject = false
                            DispatchQueue.main.async { [self] in
                                self.processItems(type: nextObject)
                            }
                        }
                    }
                } else {
                    // skip \(msgText)
                    WriteToLog.shared.message("[processItems] skipping \(type) - call \(nextObject)")
                    waitFor.mobiledeviceobject = false
                    DispatchQueue.main.async { [self] in
                        self.processItems(type: nextObject)
                    }
                }
                
            case "app-installers":
                    // look for groups used in app installers
                    WriteToLog.shared.message("[processItems] app-installers")
                    let nextObject = "patchsoftwaretitles"
                
                    if computerGroupsButtonState == "on" {
                        DispatchQueue.main.async {
                               self.process_TextField.stringValue = "Fetching App Installers..."
                        }

                        var appInstallersArray = [[String:Any]]()
                        
                        JamfPro.shared.jpapiAction(serverUrl: JamfProServer.source, endpoint: "app-installers/deployments", apiData: [:], method: "GET") {
                            (returnedJSON: [String: Any]) in
    //                        print("[processItems] patchsoftwaretitles apiGetAll result: \(result)")
                            if let allAppInstallers = returnedJSON["results"] as? [[String:Any]] {
                                for appInstaller in allAppInstallers {
                                    let appInstallerName = appInstaller["name"] ?? "unknown"
                                    if let smartGroup = appInstaller["smartGroup"] as? [String:String], let smartGroupName = smartGroup["name"], let smartGroupId = smartGroup["id"] {
                                        WriteToLog.shared.message("\(appInstallerName) is scoped to group \(smartGroupName)")
                                        // mark group as unused
                                        self.masterObjectDict["computerGroups"]![smartGroupName] = ["id":smartGroupId, "used":"true"]
                                    }
                                }
                                WriteToLog.shared.message("[processItems] app installers complete - call \(nextObject)")
                                DispatchQueue.main.async {
                                    self.processItems(type: nextObject)
                                }
                            } else {
                                WriteToLog.shared.message("[processItems] no app installers found - call \(nextObject)")
                                DispatchQueue.main.async {
                                    self.processItems(type: nextObject)
                                }
                            }
                       }   //   Json.shared.getRecord - patchpolicies - end
                    } else {
                       WriteToLog.shared.message("[processItems] skipping app installers - call \(nextObject)")
                       DispatchQueue.main.async {
                           self.processItems(type: nextObject)
                       }
                    }
                
            case "patchsoftwaretitles":
                // look for packages used in patch policies
                WriteToLog.shared.message("[processItems] patchsoftwaretitles")
                let nextObject = "patchpolicies"
                if packagesButtonState == "on" || computerEAsButtonState == "on" {
                    DispatchQueue.main.async {
                           self.process_TextField.stringValue = "Fetching Patch Software Titles..."
                    }

                    var patchPoliciesArray = [[String:Any]]()
                    
                    JamfPro.shared.apiGetAll(serverUrl: JamfProServer.source, endpoint: "patch-software-title-configurations") {
                        (result: (String,[[String: Any]])) in
//                        print("[processItems] patchsoftwaretitles apiGetAll result: \(result)")
                        if result.0 == "success" {
                            for patchSoftwareTitleConfig in result.1 {
                                let id   = "\(patchSoftwareTitleConfig["id"] ?? "")"
                                let name = "\(patchSoftwareTitleConfig["displayName"] ?? "")"
                                if id != "" && name != "" {
                                    WriteToLog.shared.message("software patch policy id: \(id) \t name: \(name)")
                                    patchPoliciesArray.append(["id": "\(id)", "name": "\(name)"])
                                    // mark patch policies as unused (reporting only) - start
                                    self.masterObjectDict[type]!["\(name)"] = ["id":"\(id)", "used":"false"]
                                    // mark patch policies as unused (reporting only) - end
                                }
                            }
                            
                            let patchPoliciesArrayCount = patchPoliciesArray.count
                            if patchPoliciesArrayCount > 0 {
                                DispatchQueue.main.async {
                                    self.process_TextField.stringValue = "Scanning Patch Software Titles for packages..."
                                }
                             
                                waitFor.patchSoftwareTitles = true
                                self.backgroundQ.async {
                                    while true {
                                        usleep(10)
                                        if !waitFor.patchSoftwareTitles {
                                            WriteToLog.shared.message("[processItems] patch software titles complete - call \(nextObject)")
                                            DispatchQueue.main.async {
                                                self.processItems(type: nextObject)
                                            }
                                            break
                                        }
                                    }
                                }    // self.backgroundQ.async - end
                                WriteToLog.shared.message("[processItems] call recursiveLookup for \(type)")
                                self.recursiveLookup(theServer: JamfProServer.source, base64Creds: self.jamfBase64Creds, theEndpoint: type, theData: patchPoliciesArray, index: 0)
                                
                            } else {
                                // no patch policies exist
                                WriteToLog.shared.message("[processItems] no patch software titles - call \(nextObject)")
                                DispatchQueue.main.async {
                                    self.processItems(type: nextObject)
                                }
                            }
                        } else {
                            WriteToLog.shared.message("[processItems] error reading patch software titles - call \(nextObject)")
                            DispatchQueue.main.async {
                                self.processItems(type: nextObject)
                            }
                        }

//                    }
//                    
//                    self.xmlAction(action: "GET", theServer: JamfProServer.source, base64Creds: self.jamfBase64Creds, theEndpoint: "patchsoftwaretitles") {
//                        (result: (Int,String)) in
//                        let (statusCode,returnedXml) = result
////                            print("[patchsoftwaretitles] patchpolicies GET statusCode: \(statusCode)")
////                            print("[patchsoftwaretitles] patchpolicies GET xml: \(returnedXml)")
//                        var nameFixedXml = returnedXml.replacingOccurrences(of: "<name>", with: "<Name>")
//                        nameFixedXml = nameFixedXml.replacingOccurrences(of: "</name>", with: "</Name>")
//                        let xmlData = nameFixedXml.data(using: .utf8)
//                        let parsedXmlData = XML.parse(xmlData!)
//
//                        for thePolicy in parsedXmlData.patch_software_titles.patch_software_title {
//                            if let id = thePolicy.id.text, let name = thePolicy.Name.text {
//
//                                WriteToLog.shared.message("patchPolicy id: \(thePolicy.id.text!) \t name: \(thePolicy.Name.text!)")
//                                patchPoliciesArray.append(["id": "\(thePolicy.id.text!)", "name": "\(thePolicy.Name.text!)"])
//                                // mark patch policies as unused (reporting only) - start
//                                self.masterObjectDict[type]!["\(name)"] = ["id":"\(id)", "used":"false"]
//                                // mark patch policies as unused (reporting only) - end
//                            }
//                        }

                   }   //         Json.shared.getRecord - patchpolicies - end
                } else {
                   WriteToLog.shared.message("[processItems] skipping patch software titles - call \(nextObject)")
                   DispatchQueue.main.async {
                       self.processItems(type: nextObject)
                   }
                }
                
            case "patchpolicies":
                    // look for groups used in patch policies
                    WriteToLog.shared.message("[processItems] patchpolicies")
                    let nextObject = "computer-prestages"
                    if computerGroupsButtonState == "on" {
                        DispatchQueue.main.async {
                               self.process_TextField.stringValue = "Fetching Patch Policies..."
                        }

//                                self.masterObjectDict[type] = [String:[String:String]]()
                        var patchPoliciesArray = [[String:Any]]()
                        
                        self.xmlAction(action: "GET", theServer: JamfProServer.source, base64Creds: self.jamfBase64Creds, theEndpoint: "patchpolicies") { [self]
                            (result: (Int,String)) in
                            let (statusCode,returnedXml) = result
//                            print("[processItems] patchpolicies GET statusCode: \(statusCode)")
//                            print("[processItems]        patchpolicies GET xml: \(returnedXml)")
                            
//                            var nameFixedXml = returnedXml.replacingOccurrences(of: "<name>", with: "<Name>")
//                            nameFixedXml = nameFixedXml.replacingOccurrences(of: "</name>", with: "</Name>")
//                            let xmlData = nameFixedXml.data(using: .utf8)
//                            let parsedXmlData = XML.parse(xmlData!)
                            
                            guard let parsedXmlData = parser.parse(string: returnedXml) else {
                               WriteToLog.shared.message("[processItme] failed to parse returnedXml: \(returnedXml)")
                               return
                            }

                            for thePolicy in parsedXmlData.all("patch_policy") {
                                if let id = thePolicy.id?.intValue, let name = thePolicy.name?.value {

                                    WriteToLog.shared.message("patchPolicy id: \(id) \t name: \(name)")
                                    patchPoliciesArray.append(["id": "\(id)", "name": "\(name)"])
                                    // mark patch policies as unused (reporting only) - start
                                    self.masterObjectDict[type]!["\(name)"] = ["id":"\(id)", "used":"false"]
                                    // mark patch policies as unused (reporting only) - end
                                }
                            }

                           let patchPoliciesArrayCount = patchPoliciesArray.count
                           if patchPoliciesArrayCount > 0 {
                               DispatchQueue.main.async {
                                   self.process_TextField.stringValue = "Scanning Patch Policies for groups..."
                               }
                            
                               waitFor.policy = true
                               self.backgroundQ.async {
                                   while true {
                                       usleep(10)
                                       if !waitFor.policy {
                                           WriteToLog.shared.message("[processItems] patch policies complete - call \(nextObject)")
                                           DispatchQueue.main.async {
                                               self.processItems(type: nextObject)
                                           }
                                           break
                                       }
                                   }
                               }
                               WriteToLog.shared.message("[processItems] call recursiveLookup for \(type)")
                               self.recursiveLookup(theServer: JamfProServer.source, base64Creds: self.jamfBase64Creds, theEndpoint: type, theData: patchPoliciesArray, index: 0)
                               
                           } else {
                               // no patch policies exist
                               WriteToLog.shared.message("[processItems] no patch policies - call \(nextObject)")
                               DispatchQueue.main.async {
                                   self.processItems(type: nextObject)
                               }
                           }
                       }   //         Json.shared.getRecord - patchpolicies - end
                    } else {
                       WriteToLog.shared.message("[processItems] skipping patch policies - call \(nextObject)")
                       DispatchQueue.main.async {
                           self.processItems(type: nextObject)
                       }
                    }
                
            case "computer-prestages":
                msgText    = "Computer Prestages"
                nextObject = "restrictedsoftware"
                
                if (self.packagesButtonState == "on" || self.computerProfilesButtonState == "on") {
                    var xmlTag = ""
//                            var name   = ""
                    DispatchQueue.main.async {
                        xmlTag = "results"
                        self.process_TextField.stringValue = "Fetching Computer Prestages..."
                    }
                    Json.shared.getRecord(theServer: JamfProServer.source, base64Creds: JamfProServer.authCreds, theEndpoint: type) { [self]
                        (result: [String:AnyObject]) in
                        if let _ = result["Alert"] as? String {
                            self.working(isWorking: false)
                            return
                        }
//                                print("json returned prestages: \(result)")
//                                self.masterObjectDict[type] = [String:[String:String]]()
                        if let _ = result[xmlTag] {
                            let prestageObjectArray = result[xmlTag] as! [[String: Any]]
                            let prestageObjectArrayCount = prestageObjectArray.count
                            WriteToLog.shared.message("[processItems] scanning computer prestages for packages and configuration profiles.")
                            WriteToLog.shared.message("[processItems] found \(prestageObjectArrayCount) prestages.")
                            if prestageObjectArrayCount > 0 {
                                WriteToLog.shared.message("[processItems] scanning computer prestages for packages and computer profiles.")
                                for i in (0..<prestageObjectArrayCount) {
                                    self.updateProcessTextfield(currentCount: "\n(\(i+1)/\(prestageObjectArrayCount))")
                                    if let id = prestageObjectArray[i]["id"], let displayName = prestageObjectArray[i]["displayName"] {
                                        self.masterObjectDict[type]!["\(displayName)"] = ["id":"\(id)", "used":"false"]
                                        
                                        // mark used packages
                                            if self.packagesButtonState == "on" {
                                                if let customPackageIds = prestageObjectArray[i]["customPackageIds"] as? [String] {
                                                //                                                print("prestage \(displayName) has the following package ids \(customPackageIds)")
                                                    WriteToLog.shared.message("[processItems] prestage \(displayName) has \(customPackageIds.count) packages")
                                                    
                                                    for prestagePackageId in customPackageIds {
        //                                                        print("mark package \(String(describing: self.packagesByIdDict[prestagePackageId]!)) as used.")
                                                        if self.packagesByIdDict[prestagePackageId] != nil {
                                                            self.masterObjectDict["packages"]!["\(String(describing: self.packagesByIdDict[prestagePackageId]!))"]?["used"] = "true"
                                                        } else {
                                                            WriteToLog.shared.message("[processItems] Appears package id \(prestagePackageId) does not exist.")
                                                        }
                                                    }
                                                    
                                                } else {
                                                    WriteToLog.shared.message("[processItems] prestage \(displayName) has no packages")
                                                }
                                            }
                                        
                                        if self.computerProfilesButtonState == "on" {
                                            // mark used computer profiles

                                            let customProfileIds  = prestageObjectArray[i]["prestageInstalledProfileIds"] as! [String]
//                                                    print("computer profile \(displayName) has the following ids \(customProfileIds)")
                                            for prestageProfileId in customProfileIds {
//                                                        print("mark computer profile \(String(describing: self.computerProfilesByIdDict[prestageProfileId]!)) as used.")
                                                
                                                self.masterObjectDict["osxconfigurationprofiles"]!["\(String(describing: self.computerProfilesByIdDict[prestageProfileId]!))"]!["used"] = "true"

                                            }
                                        }
                                    }
                                }
                                WriteToLog.shared.message("[processItems] \(msgText) complete - next object: \(nextObject)")
                                DispatchQueue.main.async { [self] in
                                    self.processItems(type: nextObject)
                                }
                            } else {
                                // no computer Prestage exist
                                WriteToLog.shared.message("[processItems] \(msgText) complete - \(nextObject)")
                                DispatchQueue.main.async { [self] in
                                    self.processItems(type: nextObject)
                                }
                            }
                        } else {
                            WriteToLog.shared.message("[processItems] unable to read \(msgText) - \(nextObject)")
                            waitFor.computerPrestage = false
                            DispatchQueue.main.async { [self] in
                                self.processItems(type: nextObject)
                            }
                        }
                    }
                } else {
                    // skip computer-prestages
                    WriteToLog.shared.message("[processItems] skipping \(msgText) - \(nextObject)")
                    waitFor.computerPrestage = false
                    DispatchQueue.main.async { [self] in
                        self.processItems(type: nextObject)
                    }
                }
        
        case "restrictedsoftware":
            WriteToLog.shared.message("[processItems] restrictedsoftware")
            let nextObject = "advancedcomputersearches"
            if self.restrictedSoftwareButtonState == "on" || self.computerGroupsButtonState == "on" {
               DispatchQueue.main.async {
                      self.process_TextField.stringValue = "Fetching Restricted Software..."
               }

//                   self.masterObjectDict[type] = [String:[String:String]]()
               var restrictedsoftwareArray = [[String:Any]]()
               
                self.xmlAction(action: "GET", theServer: JamfProServer.source, base64Creds: self.jamfBase64Creds, theEndpoint: type) { [self]
                   (result: (Int,String)) in
                   let (statusCode,returnedXml) = result
   //                                    print("[processItems] restrictedsoftware GET statusCode: \(statusCode)")
   //                                    print("[processItems] restrictedsoftware GET xml: \(returnedXml)")
//                   var nameFixedXml  = returnedXml.replacingOccurrences(of: "<name>", with: "<Name>")
//                   nameFixedXml      = nameFixedXml.replacingOccurrences(of: "</name>", with: "</Name>")
//                   let xmlData       = nameFixedXml.data(using: .utf8)
//                   let parsedXmlData = XML.parse(xmlData!)

                    guard let parsedXmlData = parser.parse(string: returnedXml) else {
                       WriteToLog.shared.message("[processItme] failed to parse returnedXml: \(returnedXml)")
                       return
                    }
                    
                   for rsPolicy in parsedXmlData.all("restricted_software_title") {
                       if let id = rsPolicy.id?.intValue, let name = rsPolicy.name?.value {

//                               print("restricted software title id: \(rsPolicy.id.text!) \t name: \(rsPolicy.Name.text!)")
                           WriteToLog.shared.message("restricted software title id: \(id)      name: \(name)")
                           restrictedsoftwareArray.append(["id": "\(id)", "name": "\(name)"])
                           // mark restricted software title as unused (reporting only)
                           self.masterObjectDict[type]!["\(name)"] = ["id":"\(id)", "used":"false"]
                       }
                   }
                   
                   let restrictedsoftwareArrayCount = restrictedsoftwareArray.count
                   if restrictedsoftwareArrayCount > 0 {
                       DispatchQueue.main.async {
                           self.process_TextField.stringValue = "Scanning Restricted Software for groups..."
                       }
                    
                       WriteToLog.shared.message("[processItems] call recursiveLookup for \(type)")
                       self.recursiveLookup(theServer: JamfProServer.source, base64Creds: self.jamfBase64Creds, theEndpoint: type, theData: restrictedsoftwareArray, index: 0)
                       waitFor.policy = true
                       self.backgroundQ.async {
                           while true {
                               usleep(10)
                               if !waitFor.policy {
                                   WriteToLog.shared.message("[processItems] restricted software configurations complete - call \(nextObject)")
                                   DispatchQueue.main.async {
                                       self.processItems(type: nextObject)
                                   }
                                   break
                               }
                           }
                       }
                       
                   } else {
                       // no restricted software configurations exist
                       WriteToLog.shared.message("[processItems] no restricted software configurations - call \(nextObject)")
                       DispatchQueue.main.async {
                           self.processItems(type: nextObject)
                       }
                   }
               }
            } else {
                // skip restrictedsoftware
                WriteToLog.shared.message("[processItems] skipping restricted software, calling - \(nextObject)")
                DispatchQueue.main.async {
                    self.processItems(type: nextObject)
                }
            }
            
            case "advancedcomputersearches":
                WriteToLog.shared.message("[processItems] \(type)")
                let nextObject = "advancedmobiledevicesearches"
                if self.computerGroupsButtonState == "on" || self.computerEAsButtonState == "on" {
                   DispatchQueue.main.async {
                          self.process_TextField.stringValue = "Fetching Advanced Computer Searches..."
                   }

    //                   self.masterObjectDict[type] = [String:[String:String]]()
                   var advancedcomputersearchArray = [[String:Any]]()
                   
                    self.xmlAction(action: "GET", theServer: JamfProServer.source, base64Creds: self.jamfBase64Creds, theEndpoint: type) { [self]
                       (result: (Int,String)) in
                       let (statusCode,returnedXml) = result
       //                                    print("[processItems] restrictedsoftware GET statusCode: \(statusCode)")
       //                                    print("[processItems] restrictedsoftware GET xml: \(returnedXml)")
//                       var nameFixedXml  = returnedXml.replacingOccurrences(of: "<name>", with: "<Name>")
//                       nameFixedXml      = nameFixedXml.replacingOccurrences(of: "</name>", with: "</Name>")
//                       let xmlData       = nameFixedXml.data(using: .utf8)
//                       let parsedXmlData = XML.parse(xmlData!)
                        
                        guard let parsedXmlData = parser.parse(string: returnedXml) else {
                           WriteToLog.shared.message("[processItme] failed to parse returnedXml: \(returnedXml)")
                           return
                        }

                        for acsPolicy in parsedXmlData.all("advanced_computer_search") {
                            if let id = acsPolicy.id?.intValue, let name = acsPolicy.name?.value {

    //                               print("restricted software title id: \(acsPolicy.id.text!) \t name: \(acsPolicy.Name.text!)")
                               WriteToLog.shared.message("advanced computer search title id: \(id)      name: \(name)")
                               advancedcomputersearchArray.append(["id": "\(id)", "name": "\(name)"])
                               // mark advanced computer search title as unused (reporting only)
                               self.masterObjectDict[type]!["\(name)"] = ["id":"\(id)", "used":"false"]
                           }
                       }
                       
                       let advancedcomputersearchArrayCount = advancedcomputersearchArray.count
                       if advancedcomputersearchArrayCount > 0 {
                           DispatchQueue.main.async {
                               self.process_TextField.stringValue = "Scanning Advanced Computer Searches for groups..."
                           }
                        
                           WriteToLog.shared.message("[processItems] call recursiveLookup for \(type)")
                           self.recursiveLookup(theServer: JamfProServer.source, base64Creds: self.jamfBase64Creds, theEndpoint: type, theData: advancedcomputersearchArray, index: 0)
                           waitFor.advancedsearch = true
                           self.backgroundQ.async {
                               while true {
                                   usleep(10)
                                   if !waitFor.advancedsearch {
                                       WriteToLog.shared.message("[processItems] advanced computer searches complete - call \(nextObject)")
                                       DispatchQueue.main.async {
                                           self.processItems(type: nextObject)
                                       }
                                       waitFor.advancedsearch = true
                                       break
                                   }
                               }
                           }
                           
                       } else {
                           // no restricted software configurations exist
                           WriteToLog.shared.message("[processItems] no advanced computer searches - call \(nextObject)")
                           DispatchQueue.main.async {
                               self.processItems(type: nextObject)
                           }
                       }
                   }
                } else {
                    // skip restrictedsoftware
                    WriteToLog.shared.message("[processItems] skipping advanced computer searches, calling - \(nextObject)")
                    DispatchQueue.main.async {
                        self.processItems(type: nextObject)
                    }
                }
                
            case "advancedmobiledevicesearches":
                WriteToLog.shared.message("[processItems] \(type)")
                let nextObject = "macapplications"
                if self.mobileDeviceGroupsButtonState == "on" || self.mobileDeviceEAsButtonState == "on" {
                   DispatchQueue.main.async {
                          self.process_TextField.stringValue = "Fetching Advanced Mobile Device Searches..."
                   }

    //                   self.masterObjectDict[type] = [String:[String:String]]()
                   var advancedsearchArray = [[String:Any]]()
                   
                    self.xmlAction(action: "GET", theServer: JamfProServer.source, base64Creds: self.jamfBase64Creds, theEndpoint: type) { [self]
                       (result: (Int,String)) in
                       let (statusCode,returnedXml) = result
       //                                    print("[processItems] restrictedsoftware GET statusCode: \(statusCode)")
       //                                    print("[processItems] restrictedsoftware GET xml: \(returnedXml)")
//                       var nameFixedXml  = returnedXml.replacingOccurrences(of: "<name>", with: "<Name>")
//                       nameFixedXml      = nameFixedXml.replacingOccurrences(of: "</name>", with: "</Name>")
//                       let xmlData       = nameFixedXml.data(using: .utf8)
//                       let parsedXmlData = XML.parse(xmlData!)
                        
                        guard let parsedXmlData = parser.parse(string: returnedXml) else {
                           WriteToLog.shared.message("[processItme] failed to parse returnedXml: \(returnedXml)")
                           return
                        }

                       for amds in parsedXmlData.all("advanced_mobile_device_search") {
                           if let id = amds.id?.intValue, let name = amds.name?.value {

    //                               print("restricted software title id: \(acsPolicy.id.text!) \t name: \(acsPolicy.Name.text!)")
                               WriteToLog.shared.message("advanced mobile device search title id: \(id)      name: \(name)")
                               advancedsearchArray.append(["id": "\(id)", "name": "\(name)"])
                               // mark advanced computer search title as unused (reporting only)
                               self.masterObjectDict[type]!["\(name)"] = ["id":"\(id)", "used":"false"]
                           }
                       }
                       
                       let advancedsearchArrayCount = advancedsearchArray.count
                       if advancedsearchArrayCount > 0 {
                           DispatchQueue.main.async {
                               self.process_TextField.stringValue = "Scanning Advanced Mobile Device Searches for groups..."
                           }
                        
                           WriteToLog.shared.message("[processItems] call recursiveLookup for \(type)")
                           self.recursiveLookup(theServer: JamfProServer.source, base64Creds: self.jamfBase64Creds, theEndpoint: type, theData: advancedsearchArray, index: 0)
                           waitFor.advancedsearch = true
                           self.backgroundQ.async {
                               while true {
                                   usleep(10)
                                   if !waitFor.advancedsearch {
                                       WriteToLog.shared.message("[processItems] advanced mobile device searches complete - call \(nextObject)")
                                       DispatchQueue.main.async {
                                           self.processItems(type: nextObject)
                                       }
                                       waitFor.advancedsearch = true
                                       break
                                   }
                               }
                           }
                           
                       } else {
                           // no restricted software configurations exist
                           WriteToLog.shared.message("[processItems] no advanced mobile device searches - call \(nextObject)")
                           DispatchQueue.main.async {
                               self.processItems(type: nextObject)
                           }
                       }
                   }
                } else {
                    // skip restrictedsoftware
                    WriteToLog.shared.message("[processItems] skipping advanced mobile device searches, calling - \(nextObject)")
                    DispatchQueue.main.async {
                        self.processItems(type: nextObject)
                    }
                }
                
            case "macapplications":
                msgText    = "Mac Apps"
                nextObject = "policies"
                
                if self.macAppsButtonState == "on" || self.computerGroupsButtonState == "on" {
                    DispatchQueue.main.async {
                        self.process_TextField.stringValue = "Fetching Mac Apps..."
                    }
                    
                    Json.shared.getRecord(theServer: JamfProServer.source, base64Creds: self.jamfBase64Creds, theEndpoint: type) { [self]
                        (result: [String:AnyObject]) in
                        if let _ = result["Alert"] as? String {
                            self.working(isWorking: false)
                            return
                        }
//                            self.masterObjectDict[type] = [String:[String:String]]()
                        if let _ = result["mac_applications"] {
                            let macAppsArray = result["mac_applications"] as! [[String: Any]]
                            let macAppsArrayCount = macAppsArray.count
                            if macAppsArrayCount > 0 {
                                for i in (0..<macAppsArrayCount) {
                                    if let id = macAppsArray[i]["id"] as? Int, let name = macAppsArray[i]["name"] as? String {
                                        self.masterObjectDict[type]!["\(name)"] = ["id":"\(id)", "used":"false"]
                                    }
                                }

                                WriteToLog.shared.message("[processItems] call recursiveLookup for \(type)")
                                self.recursiveLookup(theServer: JamfProServer.source, base64Creds: self.jamfBase64Creds, theEndpoint: type, theData: macAppsArray, index: 0)
                                waitFor.macApps = true
                                self.backgroundQ.async { [self] in
                                    while true {
                                        usleep(10)
                                        if !waitFor.macApps {
                                            WriteToLog.shared.message("[processItems] \(msgText) complete - next object: \(nextObject)")
                                            DispatchQueue.main.async { [self] in
                                                self.processItems(type: nextObject)
                                            }
                                            break
                                        }
                                    }
                                }
                            } else {
                                // no computer configurations exist
                                WriteToLog.shared.message("[processItems] \(msgText) complete - \(nextObject)")
                                DispatchQueue.main.async { [self] in
                                    self.processItems(type: nextObject)
                                }
                            }
                        } else {
                            WriteToLog.shared.message("[processItems] unable to read \(msgText) - \(nextObject)")
                            waitFor.macApps = false
                            DispatchQueue.main.async { [self] in
                                self.processItems(type: nextObject)
                            }
                        }
                    }
                } else {
                    // skip \(msgText)
                    WriteToLog.shared.message("[processItems] skipping \(msgText) - call \(nextObject)")
                    waitFor.macApps = false
                    DispatchQueue.main.async { [self] in
                        self.processItems(type: nextObject)
                    }
                }
                 
                      
            case "policies":
                if self.policiesButtonState == "on" || self.packagesButtonState == "on" || self.printersButtonState == "on" || self.scriptsButtonState == "on" || self.computerGroupsButtonState == "on" {
                    DispatchQueue.main.async {
                        self.process_TextField.stringValue = "Fetching Policies..."
                    }
                    var policiesArray = [[String:Any]]()
                    Json.shared.getRecord(theServer: JamfProServer.source, base64Creds: self.jamfBase64Creds, theEndpoint: "policies") {
                        (result: [String:AnyObject]) in
            //            print("json returned: \(result)")
                        if let _ = result["Alert"] as? String {
                            self.working(isWorking: false)
                            return
                        }
                        self.completed = 0
                        let allPoliciesArray = result["policies"] as! [[String: Any]]
                        
                        // mark policies as unused and filter out policies generated with Jamf/Casper Remote - start
                        for thePolicy in allPoliciesArray {
                            if let id = thePolicy["id"], let name = thePolicy["name"] {
                                let policyName = "\(name)"
                                if policyName.range(of:"[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9] at", options: .regularExpression) == nil && policyName != "Update Inventory" && policyName != "" {
                                    policiesArray.append(thePolicy)
                                    // mark the policy as unused and disabled
                                    self.masterObjectDict[type]!["\(name) - (\(id))"] = ["id":"\(id)", "used":"false", "enabled":"false"]
                                }
                            }
                        }
                        // for testing
//                        let fakePolicy = ["name": "fake policy" as Any, "id": "1000000" as Any]
//                        policiesArray.append(fakePolicy)
//                        self.masterObjectDict[type]!["dummy - (1000000)"] = ["id":"1000000", "used":"false", "enabled":"false"]
                        // mark policies as unused and filter out policies generated with Jamf/Casper Remote - end
                        
                        let policiesArrayCount = policiesArray.count
                        if policiesArrayCount > 0 {
                            // loop through all the policies
                            DispatchQueue.main.async {
                                self.process_TextField.stringValue = "Scanning policies for packages, scripts, computer groups..."
                            }
                        
                            WriteToLog.shared.message("[processItems] call recursiveLookup for \(type)")
                            self.recursiveLookup(theServer: JamfProServer.source, base64Creds: self.jamfBase64Creds, theEndpoint: "policies", theData: policiesArray, index: 0)
                            waitFor.policy = true
                            self.backgroundQ.async { [self] in
                                while true {
                                    usleep(10)
                                    if !waitFor.policy && !waitFor.osxconfigurationprofile {
                                        WriteToLog.shared.message("[processItems] policies complete - call unused")
                                        generateReportItems()
                                        
                                        break
                                    }
                                }
                            }
                                
                        } else {
                            // no policies found
                            WriteToLog.shared.message("[processItems] no policies found or policies not searched")
                            waitFor.policy = false
                            self.backgroundQ.async { [self] in
                                while true {
                                    usleep(10)
                                    if !waitFor.policy && !waitFor.osxconfigurationprofile {
                                        WriteToLog.shared.message("[processItems] policies complete - call unused")
                                        generateReportItems()
                                        break
                                    }
                                }
                            }   // self.backgroundQ.async - end
                        }
                    }   //         Json.shared.getRecord - policies - end
                } else {
                    // skipped policy check
                    waitFor.policy = false
                    self.backgroundQ.async { [self] in
                        while true {
                            usleep(10)
                            if !waitFor.policy && !waitFor.osxconfigurationprofile {
                                WriteToLog.shared.message("[processItems] policies complete - call unused")
                                generateReportItems()
                                break
                            }
                        }
                    }   // self.backgroundQ.async - end
                }
                // object that have a scope - end
                    
                default:
                    WriteToLog.shared.message("[default] unknown item, exiting...")
                    DispatchQueue.main.async {
                        NSApplication.shared.terminate(self)
                        self.processItems(type: "initialize")
                }
            }
        }
    }
    
    func generateReportItems() {
        var reportItems = [[String:[String:[String:String]]]]()
        if self.packagesButtonState == "on" {
            reportItems.append(["packages":self.masterObjectDict["packages"]!])
        }
        if self.scriptsButtonState == "on" {
            reportItems.append(["scripts":self.masterObjectDict["scripts"]!])
        }
        if self.ebooksButtonState == "on" {
            reportItems.append(["ebooks":self.masterObjectDict["ebooks"]!])
        }
        if self.classesButtonState == "on" {
            reportItems.append(["classes":self.masterObjectDict["classes"]!])
        }
        if self.computerGroupsButtonState == "on" {
            reportItems.append(["computergroups":self.masterObjectDict["computerGroups"]!])
        }
        if self.computerProfilesButtonState == "on" {
            reportItems.append(["osxconfigurationprofiles":self.masterObjectDict["osxconfigurationprofiles"]!])
        }
        if self.macAppsButtonState == "on" {
            reportItems.append(["macapplications":self.masterObjectDict["macapplications"]!])
        }
        if self.policiesButtonState == "on" {
            reportItems.append(["policies":self.masterObjectDict["policies"]!])
        }
        if self.printersButtonState == "on" {
            reportItems.append(["printers":self.masterObjectDict["printers"]!])
        }
        if self.restrictedSoftwareButtonState == "on" {
            reportItems.append(["restrictedsoftware":self.masterObjectDict["restrictedsoftware"]!])
        }
        if self.computerEAsButtonState == "on" {
            reportItems.append(["computerextensionattributes":self.masterObjectDict["computerextensionattributes"]!])
        }
        if self.mobileDeviceGroupsButtonState == "on" {
            reportItems.append(["mobiledevicegroups":self.masterObjectDict["mobileDeviceGroups"]!])
        }
        if self.mobileDeviceAppsButtonState == "on" {
            reportItems.append(["mobiledeviceapplications":self.masterObjectDict["mobiledeviceapplications"]!])
        }
        if self.configurationProfilesButtonState == "on" {
            reportItems.append(["mobiledeviceconfigurationprofiles":self.masterObjectDict["mobiledeviceconfigurationprofiles"]!])
        }
        if self.mobileDeviceEAsButtonState == "on" {
            reportItems.append(["mobiledeviceextensionattributes":self.masterObjectDict["mobiledeviceextensionattributes"]!])
        }
        self.unused(itemDictionary: reportItems)
    }
    
        // get the full record for each comuter group, policy, computer configuration profile...
    func recursiveLookup(theServer: String, base64Creds: String, theEndpoint: String, theData: [[String:Any]], index: Int) {
        
        var objectEndpoint = ""
        let objectArray = theData
        let objectArrayCount = objectArray.count
        switch theEndpoint {
        case "advancedcomputersearches":
            objectEndpoint = "advancedcomputersearches/id"
        case "advancedmobiledevicesearches":
            objectEndpoint = "advancedmobiledevicesearches/id"
        case "computergroups":
            objectEndpoint = "computergroups/id"
//        case "computerconfigurations":
//            objectEndpoint = "computerconfigurations/id"
        case "osxconfigurationprofiles":
            objectEndpoint = "osxconfigurationprofiles/id"
        case "ebooks":
            objectEndpoint = "ebooks/id"
        case "classes":
            objectEndpoint = "classes/id"
        case "macapplications":
            objectEndpoint = "macapplications/id"
        case "packages":
            objectEndpoint = "packages/id"
        case "policies":
            objectEndpoint = "policies/id"
        case "printers":
            objectEndpoint = "printers/id"
        case "patchpolicies":
            objectEndpoint = "patchpolicies/id"
        case "patchsoftwaretitles":
            objectEndpoint = "patchsoftwaretitles/id"
        case "restrictedsoftware":
            objectEndpoint = "restrictedsoftware/id"
        case "mobiledevicegroups":
            objectEndpoint = "mobiledevicegroups/id"
        case "mobiledeviceapplications":
            objectEndpoint = "mobiledeviceapplications/id"
        case "mobiledeviceconfigurationprofiles":
            objectEndpoint = "mobiledeviceconfigurationprofiles/id"
        default:
            WriteToLog.shared.message("[recursiveLookup] unknown endpoint: [\(theEndpoint)]")
            return
        }
                    
        let theObject = objectArray[index]
        WriteToLog.shared.message("[recursiveLookup] start parsing \(theObject)")
        if let id = theObject["id"], let name = theObject["name"] {
            WriteToLog.shared.message("[recursiveLookup] \(index+1) of \(objectArrayCount)\t lookup: name \(name) - id \(id)")
            updateProcessTextfield(currentCount: "\n(\(index+1)/\(objectArrayCount))")

            switch theEndpoint {
                case "patchsoftwaretitles":
                // search for used packages using api/v2/patch-software-title-configurations/<id> endpoint
                JamfPro.shared.jpapiAction(serverUrl: JamfProServer.source, endpoint: "patch-software-title-configurations", apiData: [:], id: "\(id)", token: JamfProServer.accessToken, method: "GET") {
                    (result: [String:Any]) in
                    if let packagesInfo = result["packages"] as? [[String:String]] {
                        for packageInfo in packagesInfo {
                            if packageInfo["displayName"] != nil {
//                                print("packageInfo[\"displayName\"]: \(String(describing: packageInfo["displayName"]))")
                                self.masterObjectDict["packages"]![packageInfo["displayName"]!]?["used"] = "true"
                            }
                        }
                    }
                    if let eaInfo = result["extensionAttributes"] as? [[String: Any]] {
                        for ea in eaInfo {
//                            print("ea[\"displayName\"]: \(String(describing: ea["eaId"]))")
                            if let displayName = ea["eaId"] as? String, let accepted = ea["accepted"] as? Bool {
                                self.masterObjectDict["computerextensionattributes"]![displayName]?["used"] = "true"
                            }
                        }
                    }
                }
                
//                print("[patchSoftwareTitles] index: \(index), objectArrayCount: \(objectArrayCount)")
                if index == objectArrayCount-1 {
//                    print("[patchSoftwareTitles] done waiting")
                    waitFor.patchSoftwareTitles = false
                } else {
                    // check the next item
                    self.recursiveLookup(theServer: theServer, base64Creds: base64Creds, theEndpoint: theEndpoint, theData: theData, index: index+1)
                }
                
                case "patchpolicies":
//                    print("hello \(theEndpoint)")
                    
                        // lookup complete record, XML format looking for groups
//                        Xml().action(action: "GET", theServer: JamfProServer.source, base64Creds: self.jamfBase64Creds, theEndpoint: "patchpolicies/id/\(id)") {
//                    print("[recursiveLookup] patchpolicies: \(objectEndpoint)/\(id)")
                self.xmlAction(action: "GET", theServer: JamfProServer.source, base64Creds: self.jamfBase64Creds, theEndpoint: "\(objectEndpoint)/\(id)") { [self]
                            (xmlResult: (Int,String)) in
                            let (statusCode, returnedXml) = xmlResult
//                            print("[returnedXml] full XML: \(returnedXml)")
//                            print("statusCode: \(statusCode)")
                            if statusCode >= 200 && statusCode < 300 {
                                let patchPolicyXml = self.nameFixedXml(originalXml: returnedXml)
                                print("[recursiveLookup.patchpolicy] returnedXml: \(patchPolicyXml)")

//                                let xmlData = patchPolicyXml.data(using: .utf8)
//                                let parsedXmlData = XML.parse(xmlData!)
                                
//                                if "\(theEndpoint)" == "patchsoftwaretitles" {
//                                    // check of used packages - start
//                                    let packageVersionArray = parsedXmlData.patch_software_title.versions.version
////                                    print("[patchPolicy] package name: \(packageVersionArray)")
//                                    
//                                    
//                                    for thePackageInfo in packageVersionArray {
//                                        if thePackageInfo.package.Name.text != nil {
////                                            print("thePackageInfo.package.Name.text: \(thePackageInfo.package.Name.text!)")
//                                            self.masterObjectDict["packages"]!["\(thePackageInfo.package.Name.text!)"]?["used"] = "true"
//                                        }
//
//                                    }
//                                    // check of used packages - end
//                                } else {
                                    // check scoped groups
                                
                                if let parsedXmlData = parser.parse(string: returnedXml) {
                                    
//                                        let patchPolicyScopeArray = parsedXmlData.patch_policy.scope.computer_groups.computer_group
                                    for scopedGroup in parsedXmlData.scope?.computer_groups?.all("computer_group") ?? [] {
                                        if let name = scopedGroup.name?.value {
                                            print("[recursiveLookup.patchpolicy] theGroup: \(name)")
                                            self.masterObjectDict["computerGroups"]!["\(name)"] = ["used":"true"]
                                        }
                                    }
                                        // check excluded groups
//                                    let patchPolicyExcludeArray = parsedXmlData.patch_policy.scope.exclusions.computer_groups.computer_group
                                    for excludedGroup in parsedXmlData.scope?.exclusions?.computer_groups?.all("computer_group") ?? [] {
                                        if let name = excludedGroup.name?.value {
    //                                        print("theExcludedGroup: \(excludedGroup.Name.text!)")
                                            self.masterObjectDict["computerGroups"]!["\(name)"] = ["used":"true"]
                                        }
                                    }
                                    
                                }
                                
//                                }
                            } else {
//                                WriteToLog.shared.message("[recursiveLookup] Nothing returned for server: \(theServer) endpoint: \(theEndpoint)/\(id).  Status code: \(statusCode)")
//                                failedLookupDict(theEndpoint: theEndpoint, theId: "\(id)")
                            }

                            
                            if index == objectArrayCount-1 {
                                waitFor.policy = false
                            } else {
                                // check the next item
                                self.recursiveLookup(theServer: theServer, base64Creds: base64Creds, theEndpoint: theEndpoint, theData: theData, index: index+1)
                            }
                    }   // Xml().action patch software titles - end
       
                default:
                    // lookup complete record, JSON format
                Json.shared.getRecord(theServer: JamfProServer.source, base64Creds: self.jamfBase64Creds, theEndpoint: "\(objectEndpoint)/\(id)") { [self]
                        (result: [String:AnyObject]) in
                        if let _ = result["Alert"] as? String {
                            self.working(isWorking: false)
                            return
                        }
                        if result.count != 0 {
                            var xmlTag = ""
                            switch theEndpoint {
                            case "computergroups", "mobiledevicegroups","advancedcomputersearches","advancedmobiledevicesearches":
                                // look for nested device groups, groups used in advanced searches, extension attributes
                                switch theEndpoint {
                                case "computergroups":
                                    xmlTag = "computer_group"
                                case "mobiledevicegroups":
                                    xmlTag = "mobile_device_group"
                                case "advancedcomputersearches":
                                    xmlTag = "advanced_computer_search"
//                                case "computerextensionattribures":
//                                    xmlTag = "computer_extension_attribures"
                                case "advancedmobiledevicesearches":
                                    xmlTag = "advanced_mobile_device_search"
//                                case "mobiledeviceextensionattribures":
//                                    xmlTag = "mobile_device_extension_attribures"
                                default:
                                    break
                                }
                                
                                let computerGroupInfo = result[xmlTag] as! [String: AnyObject]
                                let criterion = computerGroupInfo["criteria"] as! [[String: Any]]
                                for theCriteria in criterion {
                                    if let name = theCriteria["name"], let value = theCriteria["value"] {
                                        switch (name as! String) {
                                        case "Computer Group":
                                            self.masterObjectDict["computerGroups"]!["\(value)"]?["used"] = "true"
                                        case "Mobile Device Group":
                                            self.masterObjectDict["mobileDeviceGroups"]!["\(value)"]?["used"] = "true"
                                        default:
                                            if computerEAsButtonState == "on" {
                                                if self.masterObjectDict["computerextensionattributes"]!["\(name)"] != nil {
                                                    self.masterObjectDict["computerextensionattributes"]!["\(name)"]!["used"] = "true"
                                                }
                                            }
                                            if mobileDeviceEAsButtonState == "on" {
                                                if self.masterObjectDict["mobiledeviceextensionattributes"]!["\(name)"] != nil {
                                                    self.masterObjectDict["mobiledeviceextensionattributes"]!["\(name)"]!["used"] = "true"
                                                }
                                            }
                                            break
                                        }
                                    }
                                }
                                // look for nested device groups, groups used in advanced searches - end
                                
                                if ["advancedcomputersearches", "advancedmobiledevicesearches"].contains(theEndpoint) {
                                    // check for extensions attributes used only on the display tab on advanced searches
                                    if let displayFields = computerGroupInfo["display_fields"] as? [[String: Any]] {
                                        for theDisplayField in displayFields {
                                            let displayFieldName = theDisplayField["name"] as! String
                                            if computerEAsButtonState == "on" {
                                                if self.masterObjectDict["computerextensionattributes"]!["\(displayFieldName)"] != nil {
                                                    self.masterObjectDict["computerextensionattributes"]!["\(displayFieldName)"]!["used"] = "true"
                                                }
                                            }
                                            if mobileDeviceEAsButtonState == "on" {
                                                if self.masterObjectDict["mobiledeviceextensionattributes"]!["\(displayFieldName)"] != nil {
                                                    self.masterObjectDict["mobiledeviceextensionattributes"]!["\(displayFieldName)"]!["used"] = "true"
                                                }
                                            }
                                        }
                                    }
                                }
                            
                            case "ebooks":
                                
                                let theEbook = result["ebook"] as! [String:AnyObject]
                                
                                // check for used computergroups - start
                                let eBookScope = theEbook["scope"] as! [String:AnyObject]
//                                print("eBook (\(name)) scope: \(eBookScope)")
            //
                                if self.isScoped(scope: eBookScope) {
                                    self.masterObjectDict["ebooks"]!["\(name)"]!["used"] = "true"
                                }
                                
                                // check for used computergroups - start
                                let computer_groupList = eBookScope["computer_groups"] as! [[String: Any]]
                                for theComputerGroup in computer_groupList {
                                    let theComputerGroupName = theComputerGroup["name"]
                                    self.masterObjectDict["computerGroups"]!["\(theComputerGroupName!)"]?["used"] = "true"
                                }
                                // check exclusions - start
                                let computer_groupExcl = eBookScope["exclusions"] as! [String:AnyObject]
                                let computer_groupListExcl = computer_groupExcl["computer_groups"] as! [[String: Any]]
                                for theComputerGroupExcl in computer_groupListExcl {
                                    let theComputerGroupName = theComputerGroupExcl["name"]
                                    self.masterObjectDict["computerGroups"]!["\(theComputerGroupName!)"]?["used"] = "true"
                                }
                                // check exclusions - end
                                // check of used computergroups - end
                                
                                if self.isScoped(scope: eBookScope) {
                                    self.masterObjectDict["ebooks"]!["\(name)"]!["used"] = "true"
                                }
                                
                                let mda_groupList = eBookScope["mobile_device_groups"] as! [[String: Any]]
                                for theMdaGroup in mda_groupList {
                                    let theMobileDeviceGroupName = theMdaGroup["name"]
            //                                        let theMdaGroupID = theMdaGroup["id"]
                                    self.masterObjectDict["mobileDeviceGroups"]!["\(theMobileDeviceGroupName!)"]?["used"] = "true"
                                }
                                // check exclusions - start
                                let mobileDevice_groupExcl = eBookScope["exclusions"] as! [String:AnyObject]
                                let mobileDevice_groupListExcl = mobileDevice_groupExcl["mobile_device_groups"] as! [[String: Any]]
                                for theMdaGroupExcl in mobileDevice_groupListExcl {
                                    let theMobileDeviceGroupName = theMdaGroupExcl["name"]
                                    self.masterObjectDict["mobileDeviceGroups"]!["\(theMobileDeviceGroupName!)"]?["used"] = "true"
                                }
                                // check exclusions - end
                                // check of used mobiledevicegroups - end
                            
                            // scan each ebook - end
                            
                            
                            case "classes":
                                
                                let theClass = result["class"] as! [String:AnyObject]
                                
                                let studentScope = theClass["students"] as! [String]
    //                            let teacherScope = theClass["teachers"] as! [String]
                                let studentGroupScope = theClass["student_group_ids"] as! [Int]
    //                            let teacherGroupScope = theClass["teacher_group_ids"] as! [Int]
                                let mobileDeviceScope = theClass["mobile_devices"] as! [AnyObject]
                                let mobileDevicGroupsScope = theClass["mobile_device_group_ids"] as! [Int]
            //
    //                            if (studentScope.count+teacherScope.count+studentGroupScope.count+teacherGroupScope.count+mobileDeviceScope.count+mobileDevicGroupsScope.count) > 0 {

                                if (studentScope.count+studentGroupScope.count+mobileDeviceScope.count+mobileDevicGroupsScope.count) > 0 {
                                    self.masterObjectDict["classes"]!["\(name)"]!["used"] = "true"
                                }
                                
                                if mobileDevicGroupsScope.count > 0 && self.mobileDeviceGroupsButtonState == "on" {
                                    for mobileDeviceGroupID in mobileDevicGroupsScope {
                                        self.masterObjectDict["mobileDeviceGroups"]![self.mobileGroupNameByIdDict[mobileDeviceGroupID]!]!["used"] = "true"
                                    }
                                }
                                
    //                        case "computerconfigurations":
    //                            // scan each computer configuration - start
    //                            self.computerConfigurationDict["\(id)"] = "\(name)"
    //
    //                                if let _ = result["computer_configuration"] {
    //                                    let theComputerConfiguration = result["computer_configuration"] as! [String:AnyObject]
    //        //                            let packageList = theComputerConfiguration["packages"] as! [String:AnyObject]
    //                                    let computerConfigurationPackageList = theComputerConfiguration["packages"] as! [[String: Any]]
    //                                    for thePackage in computerConfigurationPackageList {
    //        //                                        print("thePackage: \(thePackage)")
    //                                        let thePackageName = thePackage["name"]
    //        //                                        print("packages id for policy id: \(id): \(thePackageID!)")
    //                                        self.packagesDict["\(thePackageName!)"]?["used"] = "true"
    //                                    }
    //
    //                                    let computerConfigurationScriptList = theComputerConfiguration["scripts"] as! [[String: Any]]
    //                                    for theScript in computerConfigurationScriptList {
    //        //                                        print("thePackage: \(thePackage)")
    //                                        let theScriptName = theScript["name"]
    //        //                                        print("packages id for policy id: \(id): \(thePackageID!)")
    //                                        self.scriptsDict["\(theScriptName!)"]?["used"] = "true"
    //                                    }
    //        //                                    print("packages for policy id: \(id): \(packageList)")
    //                                }
                                // scan each computer configuration - end
                                
                            case "osxconfigurationprofiles":
                                self.masterObjectDict["osxconfigurationprofiles"]!["\(name)"] = ["id":"\(id)", "used":"false"]
//                                self.osxconfigurationprofilesDict["\(name)"] = ["id":"\(id)", "used":"false"]
                                // look up each computer profile and check scope/limitations - start
                                                                                
                                let theConfigProfile = result["os_x_configuration_profile"] as! [String:AnyObject]
//                                print("\(name) theConfigProfile: \(theConfigProfile)")
                                
                                // check for used computergroups - start
                                let profileScope = theConfigProfile["scope"] as! [String:AnyObject]
            //
                                if self.isScoped(scope: profileScope) {
                                    self.masterObjectDict["osxconfigurationprofiles"]!["\(name)"]!["used"] = "true"
                                    
                                    var format = PropertyListSerialization.PropertyListFormat.xml

                                    if let general = theConfigProfile["general"] as? [String:AnyObject], let payloads = general["payloads"] as? String, let payloadData = Data(payloads.utf8) as? Data, let plist = try? PropertyListSerialization.propertyList(from: payloadData, format: nil), let plistDict = plist as? [String: Any], let payloadContent = plistDict["PayloadContent"] as? [[String : Any]] {

                                        for thePayload in payloadContent {
                                            if printersButtonState == "on" && thePayload["PayloadType"] as? String == "com.apple.mcxprinting" {
                                                let userPrinterList = thePayload["UserPrinterList"] as? [String: Any] ?? [:]
                                                for (printerName, _) in userPrinterList {
                                                    self.masterObjectDict["printers"]!["\(printerName)"]?["used"] = "true"
                                                }
                                            }
                                        }
                                    }
                                }
                                
                                let computer_groupList = profileScope["computer_groups"] as! [[String: Any]]
                                for theComputerGroup in computer_groupList {
            //                                        print("thePackage: \(thePackage)")
                                    let theComputerGroupName = theComputerGroup["name"] as! String
            //                                        let theComputerGroupID = theComputerGroup["id"]
                                    self.masterObjectDict["computerGroups"]!["\(theComputerGroupName)"]?["used"] = "true"
                                }
                                // check exclusions - start
                                let computer_groupExcl = profileScope["exclusions"] as! [String:AnyObject]
                                let computer_groupListExcl = computer_groupExcl["computer_groups"] as! [[String: Any]]
                                for theComputerGroupExcl in computer_groupListExcl {
//                                    print("thePackage: \(thePackage)")
                                    let theComputerGroupName = theComputerGroupExcl["name"] as! String
            //                                        print("packages id for policy id: \(id): \(thePackageID!)")
                                    self.masterObjectDict["computerGroups"]!["\(theComputerGroupName)"]?["used"] = "true"
                                }
                                // check exclusions - end
                                // check of used computergroups - end
                                
                                // look up each computer profile and check scope/limitations - end
                                
                            case "macapplications":
                                // enabled/disabled state of Mac Apps is not visible in the api
                                WriteToLog.shared.message("[recursiveLookup] check usage for \(theEndpoint)")
                                
                                let macAppsXml = result["mac_application"] as! [String:AnyObject]
                                
                                // check for used mobiledevicegroups - start
                                let macAppScope = macAppsXml["scope"] as! [String:AnyObject]
            //
                                if self.isScoped(scope: macAppScope) {
                                    self.masterObjectDict[theEndpoint]!["\(name)"]!["used"] = "true"
                                }

                                // check for used computergroups - start
                                let computer_groupList = macAppScope["computer_groups"] as! [[String:Any]]

                                if self.masterObjectDict["computerGroups"]?.count ?? 0 > 0 {
                                    for theComputerGroup in computer_groupList {
                                        let theComputerGroupName = "\(String(describing: theComputerGroup["name"]!))"
                                        self.masterObjectDict["computerGroups"]!["\(theComputerGroupName)"]?["used"] = "true"
                                    }
                                    // check exclusions - start (limitations are for user/network objects)
                                    let computer_groupExcl = macAppScope["exclusions"] as! [String:AnyObject]
                                    let computer_groupListExcl = computer_groupExcl["computer_groups"] as! [[String: Any]]
                                    for theComputerGroupExcl in computer_groupListExcl {
                                        let theComputerGroupName = theComputerGroupExcl["name"]
                                        self.masterObjectDict["computerGroups"]!["\(theComputerGroupName!)"]?["used"] = "true"
                                    }
                                }
                                // check exclusions - end
                                // check of used computergroups - end
                            case "packages":
//                                print("[recursiveLookup.packages] result: \(result)")
                                let packageInfo = result["package"] as! [String:AnyObject]
                                let id          = packageInfo["id"] as? Int ?? -1
                                let filename    = packageInfo["filename"] as? String ?? ""
                                if id != -1 && filename != "" {
                                    packageIdFileNameDict["\(id)"] = filename
                                }
                                
                            case "policies":
            //                    self.policiesDict["\(id)"] = "\(name)"
                                
                                let thePolicy = (theEndpoint == "policies") ? result["policy"] as! [String:AnyObject]:result["patch_policy"] as! [String:AnyObject]
                                
                                // check for used computergroups - start
                                let policyScope = thePolicy["scope"] as! [String:AnyObject]
//                                print("\(theEndpoint) (\(name)) scope: \(policyScope)")
                                
                                if self.isScoped(scope: policyScope) {
                                    if theEndpoint == "policies" {
                                        self.masterObjectDict["policies"]!["\(name) - (\(id))"]!["used"] = "true"
                                    } else {
                                        self.masterObjectDict["patchpolicies"]!["\(name)"]!["used"] = "true"
                                    }
                                }
                                
                                if theEndpoint == "policies" {
                                    // check enabled state of the policy
                                    let policyEnabled = thePolicy["general"]!["enabled"] as! Bool
//                                    print("policy \(name) enabled state: \(policyEnabled)")
                                    if policyEnabled {
                                        self.masterObjectDict["policies"]!["\(name) - (\(id))"]!["enabled"] = "true"
                                    }
                                    // check of used packages - start
                                    let packageList = thePolicy["package_configuration"] as! [String:AnyObject]
//                                    print("[packageCheck] packageList: \(packageList)")
                                    let policyPackageList = packageList["packages"] as! [[String: Any]]
//                                    print("[packageCheck] policyPackageList: \(policyPackageList)")
                                    for thePackage in policyPackageList {
                //                                        print("thePackage: \(thePackage)")
                                        let thePackageName = thePackage["name"]
                //                                        print("packages id for policy id: \(id): \(thePackageID!)")
                                        self.masterObjectDict["packages"]!["\(thePackageName!)"]?["used"] = "true"
                                    }
                                    // check of used packages - end

                                    // check for used scripts - start
                                    let policyScriptList = thePolicy["scripts"] as? [[String: Any]] ?? []
//                                    print("[scriptCheck] masterObjectDict[\"scripts\"]: \(self.masterObjectDict["scripts"])")
                                    for theScript in policyScriptList {
                //                                        print("thePackage: \(thePackage)")
                                        let theScriptName = theScript["name"]
                //                                        print("packages id for policy id: \(id): \(thePackageID!)")
                                        self.masterObjectDict["scripts"]!["\(theScriptName!)"]?["used"] = "true"
//                                        self.scriptsDict["\(theScriptName!)"]?["used"] = "true"
                                    }
                                    // check of used scripts - end
                                    
                                    // check for used printers - start
                                    let policyPrinterList = thePolicy["printers"] as? [AnyObject] ?? []

                                    for theObject in policyPrinterList {
                                        if let thePrinter = theObject as? [String: Any] {
                                            let thePrinterName = thePrinter["name"]
                                            self.masterObjectDict["printers"]!["\(thePrinterName!)"]?["used"] = "true"
                                        }
                                    }
                                    // check of used printers - end
                                }

                                // check for used computergroups - start
            //                    let computerGroupList = thePolicy["scope"] as! [String:AnyObject]
            //                                    print("computerGroupList: \(computerGroupList)")
            //                    let computer_groupList = computerGroupList["computer_groups"] as! [[String: Any]]
                                let computer_groupList = policyScope["computer_groups"] as! [[String:Any]]

                                if self.masterObjectDict["computerGroups"]?.count ?? 0 > 0 {
                                    for theComputerGroup in computer_groupList {
                //                                        print("thePackage: \(thePackage)")
                                        let theComputerGroupName = "\(String(describing: theComputerGroup["name"]!))"
                //                                        let theComputerGroupID = theComputerGroup["id"]
                //                                        print("packages id for policy id: \(id): \(thePackageID!)")
                                        self.masterObjectDict["computerGroups"]!["\(theComputerGroupName)"]?["used"] = "true"
                                    }
                                    // check exclusions - start
                //                    let computer_groupExcl = computerGroupList["exclusions"] as! [String:AnyObject]
                                    let computer_groupExcl = policyScope["exclusions"] as! [String:AnyObject]
                                    let computer_groupListExcl = computer_groupExcl["computer_groups"] as! [[String: Any]]
                                    for theComputerGroupExcl in computer_groupListExcl {
                                        let theComputerGroupName = theComputerGroupExcl["name"]
                                        self.masterObjectDict["computerGroups"]!["\(theComputerGroupName!)"]?["used"] = "true"
                                    }
                                }
                                
                                // check exclusions - end
                                // check of used computergroups - end
                                
                            case "mobiledeviceapplications", "mobiledeviceconfigurationprofiles":
                                WriteToLog.shared.message("[recursiveLookup] check usage for \(theEndpoint)")
                                
                                let theMobileDeviceObjectXml = (theEndpoint == "mobiledeviceapplications") ? result["mobile_device_application"] as! [String:AnyObject]:result["configuration_profile"] as! [String:AnyObject]
                                
                                // check for used mobiledevicegroups - start
                                let mobileDeviceAppScope = theMobileDeviceObjectXml["scope"] as! [String:AnyObject]
//                                print("[recursiveLookup] mobileDeviceAppScope: \(mobileDeviceAppScope)")
            //
                                if self.isScoped(scope: mobileDeviceAppScope) {
                                    self.masterObjectDict[theEndpoint]!["\(name)"]!["used"] = "true"
                                }

                                // check for used mobiledevicegroups - start
                                let mdaGroupList = theMobileDeviceObjectXml["scope"] as! [String:AnyObject]
            //                                    print("mdaGroupList: \(mdaGroupList)")
                                let mda_groupList = mdaGroupList["mobile_device_groups"] as! [[String: Any]]
                                for theMdaGroup in mda_groupList {
                                    let theMobileDeviceGroupName = theMdaGroup["name"]
            //                                        let theMdaGroupID = theMdaGroup["id"]
                                    self.masterObjectDict["mobileDeviceGroups"]!["\(theMobileDeviceGroupName!)"]?["used"] = "true"
                                }
                                // check exclusions - start
                                let mobileDevice_groupExcl = mdaGroupList["exclusions"] as! [String:AnyObject]
                                let mobileDevice_groupListExcl = mobileDevice_groupExcl["mobile_device_groups"] as! [[String: Any]]
                                for theMdaGroupExcl in mobileDevice_groupListExcl {
                                    let theMobileDeviceGroupName = theMdaGroupExcl["name"]
                                    self.masterObjectDict["mobileDeviceGroups"]!["\(theMobileDeviceGroupName!)"]?["used"] = "true"
                                }
                                // check exclusions - end
                                // check of used mobiledevicegroups - end
                                
                            case "restrictedsoftware":
                                WriteToLog.shared.message("[recursiveLookup] check usage for \(theEndpoint)")
                                
                                let restrictedsoftwareObjectXml = result["restricted_software"] as! [String:AnyObject]
                                
                                // check for used mobiledevicegroups - start
                                let restrictedsoftwareScope = restrictedsoftwareObjectXml["scope"] as! [String:AnyObject]
//                                print("[recursiveLookup] restrictedsoftwareScope: \(restrictedsoftwareScope)")
            //
                                if self.isScoped(scope: restrictedsoftwareScope) {
                                    self.masterObjectDict[theEndpoint]!["\(name)"]!["used"] = "true"
                                }

                                // check for used computergroups - start
                                let rsGroupList  = restrictedsoftwareObjectXml["scope"] as! [String:AnyObject]
            //                                    print("rsGroupList: \(rsGroupList)")
                                let rs_groupList = rsGroupList["computer_groups"] as! [[String: Any]]
                                for theRstGroup in rs_groupList {
                                    let restrictedsoftwareGroupName = theRstGroup["name"]
            //                                        let theMdaGroupID = theMdaGroup["id"]
                                    self.masterObjectDict["computerGroups"]!["\(restrictedsoftwareGroupName!)"]?["used"] = "true"
                                }
                                // check exclusions - start
                                let rs_groupExcl     = rsGroupList["exclusions"] as! [String:AnyObject]
                                let rs_groupListExcl = rs_groupExcl["computer_groups"] as! [[String: Any]]
                                for theRstGroupExcl in rs_groupListExcl {
                                    let restrictedsoftwareGroupName = theRstGroupExcl["name"]
                                    self.masterObjectDict["computerGroups"]!["\(restrictedsoftwareGroupName!)"]?["used"] = "true"
                                }
                                // check exclusions - end
                                // check of used computergroups - end
                                
                                /*
                                 case "advancedcomputersearches":
                                     WriteToLog.shared.message("[recursiveLookup] check usage for \(theEndpoint)")
                                     
                                     let restrictedsoftwareObjectXml = result["advancedcomputersearch"] as! [String:AnyObject]
                                     
                                     // check for used mobiledevicegroups - start
                                     let restrictedsoftwareScope = restrictedsoftwareObjectXml["scope"] as! [String:AnyObject]
     //                                print("[recursiveLookup] restrictedsoftwareScope: \(restrictedsoftwareScope)")
                 //
                                     if self.isScoped(scope: restrictedsoftwareScope) {
                                         self.masterObjectDict[theEndpoint]!["\(name)"]!["used"] = "true"
                                     }

                                     // check for used computergroups - start
                                     let rsGroupList  = restrictedsoftwareObjectXml["scope"] as! [String:AnyObject]
                 //                                    print("rsGroupList: \(rsGroupList)")
                                     let rs_groupList = rsGroupList["computer_groups"] as! [[String: Any]]
                                     for theRstGroup in rs_groupList {
                                         let restrictedsoftwareGroupName = theRstGroup["name"]
                 //                                        let theMdaGroupID = theMdaGroup["id"]
                                         self.masterObjectDict["computerGroups"]!["\(restrictedsoftwareGroupName!)"]?["used"] = "true"
                                     }
                                     // check exclusions - start
                                     let rs_groupExcl     = rsGroupList["exclusions"] as! [String:AnyObject]
                                     let rs_groupListExcl = rs_groupExcl["computer_groups"] as! [[String: Any]]
                                     for theRstGroupExcl in rs_groupListExcl {
                                         let restrictedsoftwareGroupName = theRstGroupExcl["name"]
                                         self.masterObjectDict[theEndpoint]!["\(restrictedsoftwareGroupName!)"]?["used"] = "true"
                                     }
                                     // check exclusions - end
                                     // check of used computergroups - end
                                 */
                                
                            default:
                                WriteToLog.shared.message("[recursiveLookup] unknown endpoint: \(theEndpoint)")
                            }
                        } else {
//                            WriteToLog.shared.message("[recursiveLookup] Nothing returned for server: \(theServer) endpoint: \(theEndpoint)/\(id)")
//                            failedLookupDict(theEndpoint: theEndpoint, theId: "\(id)")
                        }
                        
                        if index == objectArrayCount-1 {
                            switch theEndpoint {
                            case "advancedcomputersearches", "advancedmobiledevicesearches":
                                waitFor.advancedsearch = false
                            case "computergroups", "mobiledevicegroups":
                                waitFor.deviceGroup = false
//                            case "computerconfigurations":
//                                waitFor.computerConfiguration = false
                            case "ebooks":
                                waitFor.ebook = false
                            case "classes":
                                waitFor.classes = false
                            case "osxconfigurationprofiles":
                                waitFor.osxconfigurationprofile = false
                            case "macapplications":
                                waitFor.macApps = false
                            case "packages":
                                waitFor.packages = false
                            case "policies","patchpolicies","patchsoftwaretitles","restrictedsoftware":
                                waitFor.policy = false
                            case "mobiledeviceapplications", "mobiledeviceconfigurationprofiles":
                                waitFor.mobiledeviceobject = false
                            default:
                                WriteToLog.shared.message("[index == objectArrayCount-1] unknown endpoint: \(theEndpoint)")
                            }
                        } else {
                            // check the next item
                            self.recursiveLookup(theServer: theServer, base64Creds: base64Creds, theEndpoint: theEndpoint, theData: theData, index: index+1)
                        }
                    }   //Json.shared.getRecord - end
            }
            
        } else {   // if let id = theObject["id"], let name = theObject["name"] - end
            WriteToLog.shared.message("[recursiveLookup] unable to identify id and/or name of object")
            if index == objectArrayCount-1 {
                switch theEndpoint {
                case "computergroups", "mobiledevicegroups":
                    waitFor.deviceGroup = false
//                            case "computerconfigurations":
//                                waitFor.computerConfiguration = false
                case "ebooks":
                    waitFor.ebook = false
                case "classes":
                    waitFor.classes = false
                case "osxconfigurationprofiles":
                    waitFor.osxconfigurationprofile = false
                case "packages":
                    waitFor.packages = false
//                case "printers":
//                    waitFor.printers = false
                case "policies","patchpolicies","patchsoftwaretitles","restrictedsoftware":
                    waitFor.policy = false
                case "mobiledeviceapplications", "mobiledeviceconfigurationprofiles":
                    waitFor.mobiledeviceobject = false
                default:
                    WriteToLog.shared.message("[index == objectArrayCount-1] unknown endpoint: \(theEndpoint)")
                }
            } else {
                // check the next item
                self.recursiveLookup(theServer: theServer, base64Creds: base64Creds, theEndpoint: theEndpoint, theData: theData, index: index+1)
            }
        }
    }

    func unused(itemDictionary: [[String:Any]]) {
//        print("[\(#line)-unused] itemDictionary: \(itemDictionary)")
        DispatchQueue.main.async { [self] in
            var unusedCount = 0
            var sortedArray = [String]()
            let dictCount   = itemDictionary.count
            
            if unusedItems_TableArray?.count != nil {
                unusedItems_TableArray?.removeAll()
                object_TableView.reloadData()
            }
            
//            OperationQueue.main.addOperation {
                self.process_TextField.stringValue = ""
//            }
            for i in (0..<dictCount) {
                if unusedItems_TableDict?.count == 0  || unusedItems_TableDict?.count == nil {
                    unusedItems_TableDict = [["----- header -----":"----- header -----"]]
                } else {
                    unusedItems_TableDict!.append(["----- header -----":"----- header -----"])
                }
                let currentDict = itemDictionary[i]
                for (type, theDict) in currentDict {
                    let currentItem = type
                    let newDict = theDict as! [String:[String:String]]
                    for (key, _) in newDict {
                        if newDict["\(key)"]?["used"] == "false" || type == "policies" {
                            if type == "policies" {
                                if newDict["\(key)"]?["enabled"] == "false" {
                                    sortedArray.append("\(key)    [disabled]")
                                } else {
                                    if newDict["\(key)"]?["used"] == "false" {
                                        sortedArray.append("\(key)")
                                    }
                                }
                            } else {
                                sortedArray.append("\(key)")
                            }
                            unusedCount += 1
                        }
                    }
                    // case insensitive sort - ascending
                    sortedArray = sortedArray.sorted{$0.localizedCaseInsensitiveCompare($1) == .orderedAscending}
                    
                    if unusedItems_TableArray?.count != nil {
                        if unusedItems_TableArray?.count == 0 {
                            unusedItems_TableArray = ["----- count of unused \(currentItem): \(sortedArray.count) -----"]
    //                        unusedItems_TableDict = [["----- header -----":"----- header -----"]]
                        } else {
                            unusedItems_TableArray?.append("----- count of unused \(currentItem): \(sortedArray.count) -----")
    //                        unusedItems_TableDict = [["----- header -----":"----- header -----"]]
                        }
                    } else {
                        unusedItems_TableArray = ["----- count of unused \(currentItem): \(sortedArray.count) -----"]
    //                    unusedItems_TableDict = [["----- header -----":"----- header -----"]]
                    }
                    
                    itemSeperators.append("----- count of unused \(currentItem): \(sortedArray.count) -----")
                    unusedItems_TableArray! += sortedArray
                    for theObject in sortedArray {
                        unusedItems_TableDict?.append([theObject:type])
                    }
//                    print("[\(#line)-unused] unusedItems_TableDict: \(String(describing: unusedItems_TableDict))")
    //                print("unusedItems_TableArray: \(String(describing: unusedItems_TableArray))")
//                    DispatchQueue.main.async { [self] in
                        object_TableView.reloadData()
        //                displayUnused(key: type, theList: sortedArray)
                        unusedCount = 0
                        sortedArray.removeAll()
//                    }
                }
            }
            view_PopUpButton.isEnabled = true
            working(isWorking: false)
            self.process_TextField.isHidden = true
            if failedLookup.count > 0 {
                let noun = (failedLookup.count) == 1 ? "lookup":"lookups"
                WriteToLog.shared.message("[Failed Lookups] \(failedLookup.count) \(noun) failed")
                _ = Alert.shared.warning(header: "", message: "Some lookups failed, some items may be incorrectly listed.  Search the log for entries containing:\nNothing returned for server:")
            }
    //        print("unusedItems_TableDict: \(unusedItems_TableDict ?? [[:]])")
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
    
    // removed 220726
//    func generateMasterObjectDict(type: String, data: [String:Any], nextItem: String) {
//        let objectsArray = data[type] as! [[String:Any]]
//        let objectsArrayCount = objectsArray.count
//        if objectsArrayCount > 0 {
//            for i in (0..<objectsArrayCount) {
//                if let id = objectsArray[i]["id"], let name = objectsArray[i]["name"] {
//                    if "\(name)" != "" {
//                        self.masterObjectDict[type]!["\(name)"] = ["id":"\(id)", "used":"false"]
//                    }
//                }
//            }
//        }
//
//        WriteToLog.shared.message("[processItems] scripts complete - call \(nextItem)")
//        DispatchQueue.main.async {
//            self.processItems(type: nextItem)
//        }
//    }
    
    // used when importing files
    func buildDictionary(type: String, used: String, data: [String:Any]) -> [String:Any] {
        
//        var unusedItemsDictionary = [String:[String:String]]()
        var unusedItemsDictionary = [String:Any]()
        var category            = ""
        
        switch type {
        case "unusedPackages":
            category = "packages"
        case "unusedScripts":
            category = "scripts"
        case "unusedComputerGroups":
            category = "computerGroups"
        case "unusedComputerProfiles":
            category = "osxconfigurationprofiles"
        case "unusedMacApps":
            category = "macapplications"
        case "unusedPolicies":
            category = "policies"
        case "unusedRestrictedsoftware":
            category = "restrictedsoftware"
        case "unusedComputerEAs":
            category = "computerextensionattributes"
        case "unusedMobileDeviceGroups":
            category = "mobileDeviceGroups"
        case "unusedMobileDeviceApps":
            category = "mobiledeviceapplications"
        case "unusedMobileDeviceConfigurationProfiles":
            category = "mobiledeviceconfigurationprofiles"
        case "unusedEbooks":
            category = "ebooks"
        case "unusedMobileDeviceEAs":
            category = "mobiledeviceextensionattributes"
        default:
            category = type
        }
        
        self.masterObjectDict["\(category)"] = [String:[String:String]]()
        var theName = ""
        var enabled = ""
        if let listOfUnused = data[type] {
            for theDict in listOfUnused as! [[String:String]] {
                
                // change theDict["name"] for disabled policies
                enabled = "true"
                if type != "unusedComputerGroups" && type != "unusedMobileDeviceGroups" {
                    switch type {
                    case "unusedPolicies", "unusedComputerEAs":
                        let pattern = (type == "unusedPolicies") ? "\\d+\\) {4}+\\[disabled+\\]+$":" {4}+\\[disabled+\\]+$"
                        var stringToMatch = "    [disabled]"
                        if type == "unusedPolicies" {
                            stringToMatch = ")\(stringToMatch)"
                        }
                        if theDict["name"]!.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil {
                            enabled = "false"
                        }
                        theName = theDict["name"]!.replacingOccurrences(of: stringToMatch, with: ")")
                    default:
                        theName = theDict["name"] ?? ""
                    }
                    if let _ = theDict["id"], let _ = theDict["name"] {
                        unusedItemsDictionary["\(theName)"] = ["id":theDict["id"]!,"used":"false", "enabled":enabled]
                        masterObjectDict["\(category)"]![theName] = ["id":theDict["id"]!, "used":"false", "enabled":enabled]
                    } else {
                        WriteToLog.shared.message("[buildDictionary] unable to read record, skipping \(theDict)")
                    }
                } else {
                    if let _ = theDict["id"], let _ = theDict["name"] {
                        unusedItemsDictionary[theDict["name"]!] = ["id":theDict["id"]!,"used":"false","groupType":theDict["groupType"]]
                        masterObjectDict["\(category)"]![theDict["name"]!] = ["id":theDict["id"]!,"used":"false"]
                    } else {
                        WriteToLog.shared.message("[buildDictionary] unable to read record, skipping \(theDict)")
                    }
                }
                
            }
        }
        
//        print("[buildDictionary] masterObjectDict for \(category): \(masterObjectDict)")
//        print("[buildDictionary] unusedItemsDictionary for \(category): \(unusedItemsDictionary)")
        return ["\(category)":unusedItemsDictionary]
    }
    
    // can't use <name> tag with SwiftyXMLParser
    func nameFixedXml(originalXml: String) -> String {
        var newXml = ""
        newXml = originalXml.replacingOccurrences(of: "<name>", with: "<Name>")
        newXml = newXml.replacingOccurrences(of: "</name>", with: "</Name>")
        return newXml
    }
    
    @IBAction func view_Action(_ sender: NSButton) {
        var reportItems = [[String:[String:[String:String]]]]()
        unusedItems_TableDict?.removeAll()
        if sender.title == "Packages" || (sender.title == "All" && packagesButtonState == "on") {
            guard let _ = self.masterObjectDict["packages"] else { return }
            reportItems.append(["packages":self.masterObjectDict["packages"]!])
        }
        if sender.title == "Scripts" || (sender.title == "All" && scriptsButtonState == "on") {
            guard let _ = self.masterObjectDict["scripts"] else { return }
            reportItems.append(["scripts":self.masterObjectDict["scripts"]!])
        }
        if sender.title == "Classes" || (sender.title == "All" && classesButtonState == "on") {
            guard let _ = self.masterObjectDict["classes"] else { return }
            reportItems.append(["ebooks":self.masterObjectDict["classes"]!])
        }
        if sender.title == "Computer Groups" || (sender.title == "All" && computerGroupsButtonState == "on") {
            guard let _ = self.masterObjectDict["computerGroups"] else { return }
            reportItems.append(["computergroups":self.masterObjectDict["computerGroups"]!])
        }
        if sender.title == "Computer Profiles" || (sender.title == "All" && computerProfilesButtonState == "on") {
            guard let _ = self.masterObjectDict["osxconfigurationprofiles"] else { return }
            reportItems.append(["osxconfigurationprofiles":self.masterObjectDict["osxconfigurationprofiles"]!])
        }
        if sender.title == "Mac Apps" || (sender.title == "All" && macAppsButtonState == "on") {
            guard let _ = self.masterObjectDict["macapplications"] else { return }
             reportItems.append(["macapplications":self.masterObjectDict["macapplications"]!])
        }
        if sender.title == "Policies" || (sender.title == "All" && policiesButtonState == "on") {
            guard let _ = self.masterObjectDict["policies"] else { return }
            reportItems.append(["policies":self.masterObjectDict["policies"]!])
        }
        if sender.title == "Printers" || (sender.title == "All" && printersButtonState == "on") {
            guard let _ = self.masterObjectDict["printers"] else { return }
            reportItems.append(["printers":self.masterObjectDict["printers"]!])
        }
        if sender.title == "Restricted Software" || (sender.title == "All" && restrictedSoftwareButtonState == "on") {
            guard let _ = self.masterObjectDict["restrictedsoftware"] else { return }
            reportItems.append(["restrictedsoftware":self.masterObjectDict["restrictedsoftware"]!])
        }
        if sender.title == "Computer EAs" || (sender.title == "All" && computerEAsButtonState == "on") {
            guard let _ = self.masterObjectDict["computerextensionattributes"] else { return }
            reportItems.append(["computerextensionattributes":self.masterObjectDict["computerextensionattributes"]!])
        }
        if sender.title == "Mobile Device Groups" || (sender.title == "All" && mobileDeviceGroupsButtonState == "on") {
            guard let _ = self.masterObjectDict["mobileDeviceGroups"] else { return }
            reportItems.append(["mobiledevicegroups":self.masterObjectDict["mobileDeviceGroups"]!])
        }
        if sender.title == "Mobile Device Apps" || (sender.title == "All" && mobileDeviceAppsButtonState == "on") {
            guard let _ = self.masterObjectDict["mobiledeviceapplications"] else { return }
            reportItems.append(["mobiledeviceapplications":self.masterObjectDict["mobiledeviceapplications"]!])
        }
        if sender.title == "Mobile Device Config. Profiles" || (sender.title == "All" && configurationProfilesButtonState == "on") {
            guard let _ = self.masterObjectDict["mobiledeviceconfigurationprofiles"] else { return }
            reportItems.append(["mobiledeviceconfigurationprofiles":self.masterObjectDict["mobiledeviceconfigurationprofiles"]!])
        }
        if sender.title == "eBooks" || (sender.title == "All" && ebooksButtonState == "on") {
            guard let _ = self.masterObjectDict["ebooks"] else { return }
            reportItems.append(["ebooks":self.masterObjectDict["ebooks"]!])
        }
        if sender.title == "Mobile Device EAs" || (sender.title == "All" && mobileDeviceEAsButtonState == "on") {
            guard let _ = self.masterObjectDict["mobiledeviceextensionattributes"] else { return }
            reportItems.append(["mobiledeviceextensionattributes":self.masterObjectDict["mobiledeviceextensionattributes"]!])
        }
        self.unused(itemDictionary: reportItems)
    }
    
    @IBAction func importButton_Action(_ sender: Any) {
        didRun = true
        var objPath: URL! = nil
        
        if let pathToFile = sender as? URL, pathToFile.path != "" {
            print("path to file: \(pathToFile)")
            objPath = pathToFile
            importFile(fileURL: objPath)
//            return
        } else {
            // filetypes that are selectable
            let fileTypeArray: Array = ["json"]

            objPath = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0]
            DispatchQueue.main.async {
                let importDialog: NSOpenPanel        = NSOpenPanel()
                importDialog.canChooseDirectories    = false
                importDialog.allowsMultipleSelection = false
                importDialog.resolvesAliases         = true
                importDialog.allowedFileTypes        = fileTypeArray
                importDialog.directoryURL            = objPath
                
                importDialog.begin { [self] result in
                    if result.rawValue == NSApplication.ModalResponse.OK.rawValue {
                        objPath = importDialog.url!
                        importFile(fileURL: objPath)
                    } else {
                        return
                    }
                }
            }
        }
        
        print("objPath: \(String(describing: objPath))")
    }
    
    func importFile(fileURL: URL) {
    
        if (fileURL.path.suffix(5) != ".json") {
            _ = Alert.shared.display(header: "Alert", message: "Import file type must be json")
            return
        }
        var isDir : ObjCBool = false

        sleep(1)
        _ = FileManager.default.fileExists(atPath: fileURL.path, isDirectory:&isDir)
        do {
            setAllButtonsState(theState: "off")
            unusedItems_TableDict?.removeAll()
            masterObjectDict.removeAll()
            let dataFile =  try Data(contentsOf:fileURL, options: .mappedIfSafe)
            let objectJSON = try JSONSerialization.jsonObject(with: dataFile, options: .mutableLeaves) as? [String:Any]
            
            if objectJSON?["jamfServer"] as? String == nil || objectJSON?["username"] as? String == nil {
                let theFile = fileURL.lastPathComponent
                Alert.shared.display(header: "Alert:", message: "\(theFile) does not appear to be a Prune file")
                return
            }
            
            // ensure the import file came from the server we're logged into
            let loggedInto = jamfServer_TextField.stringValue.replacingOccurrences(of: "://", with: "/")
            let tmpArray = loggedInto.components(separatedBy: "/")
            let serverFromFile = (objectJSON?["jamfServer"] as? String)!.replacingOccurrences(of: "://", with: "/")
            let tmpArray2 = serverFromFile.components(separatedBy: "/")
            if tmpArray[1] != tmpArray2[1] {
                Alert.shared.display(header: "", message: "The import file is not from the server you are currently logged into.  You must log into \n\(objectJSON?["jamfServer"] as! String) \nto use this file.")
                return
            }
            
            for (key, value) in objectJSON! {
                switch key {
                case "jamfServer":
                    jamfServer_TextField.stringValue = "\(value)"
                    JamfProServer.source = "\(value)"
                case "username":
                    JamfProServer.username = "\(value)"
                default:
                    switch key {
                    case "unusedPackages":
                        packages_Button.state = NSControl.StateValue(rawValue: 1)
                        packagesButtonState = "on"
                    case "unusedScripts":
                        scripts_Button.state = NSControl.StateValue(rawValue: 1)
                        scriptsButtonState = "on"
                    case "unusedComputerGroups":
                        computerGroups_Button.state = NSControl.StateValue(rawValue: 1)
                        computerGroupsButtonState = "on"
                    case "unusedComputerProfiles":
                        computerProfiles_Button.state = NSControl.StateValue(rawValue: 1)
                        computerProfilesButtonState = "on"
                    case "unusedMacApps":
                        macApps_Button.state = NSControl.StateValue(rawValue: 1)
                        macAppsButtonState = "on"
                    case "unusedPolicies":
                        policies_Button.state = NSControl.StateValue(rawValue: 1)
                        policiesButtonState = "on"
                    case "unusedPrinters":
                        printers_Button.state = NSControl.StateValue(rawValue: 1)
                        printersButtonState = "on"
                    case "unusedRestrictedSoftware":
                        restrictedSoftware_Button.state = NSControl.StateValue(rawValue: 1)
                        restrictedSoftwareButtonState = "on"
                    case "unusedComputerEAs":
                        computerEAs_Button.state = NSControl.StateValue(rawValue: 1)
                        computerEAsButtonState = "on"
                    case "unusedMobileDeviceGroups":
                        mobileDeviceGroups_Button.state = NSControl.StateValue(rawValue: 1)
                        mobileDeviceGroupsButtonState = "on"
                    case "unusedMobileDeviceApps":
                        mobileDeviceApps_Button.state = NSControl.StateValue(rawValue: 1)
                        mobileDeviceAppsButtonState = "on"
                    case "unusedMobileDeviceConfigurationProfiles":
                        configurationProfiles_Button.state = NSControl.StateValue(rawValue: 1)
                        configurationProfilesButtonState = "on"
                    case "unusedClasses":
                        classes_Button.state = NSControl.StateValue(rawValue: 1)
                        classesButtonState = "on"
                    case "unusedEbooks":
                        ebooks_Button.state = NSControl.StateValue(rawValue: 1)
                        ebooksButtonState = "on"
                    case "unusedMobileDeviceEAs":
                        mobileDeviceEAs_Button.state = NSControl.StateValue(rawValue: 1)
                        mobileDeviceEAsButtonState = "on"
                    default:
                        break
                    }
                    unused(itemDictionary: [buildDictionary(type: key, used: "false", data: objectJSON!)])
                }
            }

        } catch {
            WriteToLog.shared.message("file read error")
            return
        }
    }
    
    func sortedArrayFromDict(theDict: [String:[String:String]]) -> [String] {
//        print("theDict: \(theDict)")
        var sortedArray = [String]()
        for (key, _) in theDict {
            sortedArray.append(key)
        }
        sortedArray = sortedArray.sorted{$0.localizedCaseInsensitiveCompare($1) == .orderedAscending}
        return sortedArray
    }
    
    
    @IBAction func export_Action(_ sender: Any) {
        
        let timeStamp = Time().getCurrent()
        
        if NSEvent.modifierFlags.contains(.option) {
            
            let exportedReport = "pruneReport_\(JamfProServer.source.fqdnFromUrl)_\(timeStamp).csv"
            let exportURL = getDownloadDirectory().appendingPathComponent(exportedReport)
//            print("masterObjectDict: \(masterObjectDict)")
            var selectedObjects = [String]()
            let buttonArray:[NSButton] = [packages_Button,scripts_Button,computerGroups_Button,computerProfiles_Button,policies_Button,printers_Button,restrictedSoftware_Button,computerEAs_Button,macApps_Button,mobileDeviceGroups_Button,mobileDeviceApps_Button,configurationProfiles_Button,classes_Button,ebooks_Button,mobileDeviceEAs_Button]
            for theButton in buttonArray {
                if theButton.state.rawValue == 1 {
                    selectedObjects.append("\(theButton.identifier?.rawValue ?? "")")
                }
            }
//            print("selectedObjects: \(selectedObjects)")
            var unusedObjects = ""
            
//            print("masterObjectDict: \(masterObjectDict)")
            
            for (key, value) in masterObjectDict {
                let dictOfObjects:[String:[String:String]] = value
                
//                print("dictOfObjects: \(dictOfObjects)")
                
                if selectedObjects.firstIndex(of: key.lowercased()) != nil {
//                    print("export \(key)")
                    WriteToLog.shared.message("exporting \(key)")
                    for (theObject, objectInfo) in dictOfObjects {
                        if key == "policies" {
                            if objectInfo["used"] == "false" || objectInfo["enabled"] == "false" {
                                unusedObjects.append("\"\(key)\",\"\(theObject)\"\n")
                                WriteToLog.shared.message("    \(theObject)")
                            } else {
//                                WriteToLog.shared.message("*** \(objectInfo)\n")
                            }
                        } else {
                            if objectInfo["used"] == "false" {
                                unusedObjects.append("\"\(key)\",\"\(theObject)\"\n")
                                WriteToLog.shared.message("    \(theObject)")
                            }
                        }
                    }
                }
            }
            do {
                try unusedObjects.write(to: exportURL, atomically: true, encoding: .utf8)
                Alert.shared.summary(header: "Export Summary", message: "Report of unused itmes has been saved to ~/Downloads")
            } catch {
                Alert.shared.summary(header: "Export Summary", message: "Report of unused itmes failed to save to ~/Downloads")
            }
            return
        }
        
//        print("masterObjectDict2: \(masterObjectDict)")
        
        var text = ""
        var exportedItems:[String] = ["Exported Items"]
        let failedExported:[String] = ["Failed Exported Items"]
        let exportQ = DispatchQueue(label: "com.jamf.prune.exportQ", qos: DispatchQoS.background)
        working(isWorking: true)
        let header = "\"jamfServer\": \"\(JamfProServer.source)\",\n \"username\": \"\(JamfProServer.username)\""
        exportQ.sync {
            if self.packagesButtonState == "on" {
                var firstPackage = true
                let packageLogFile = "prunePackages_\(timeStamp).json"
                let exportURL = getDownloadDirectory().appendingPathComponent(packageLogFile)

                do {
                    try "{\(header),\n \"unusedPackages\":[\n".write(to: exportURL, atomically: true, encoding: .utf8)
                    
                    if let packageLogFileOp = try? FileHandle(forUpdating: exportURL) {
                        for key in sortedArrayFromDict(theDict: masterObjectDict["packages"]!) {
                            if masterObjectDict["packages"]![key]?["used"]! == "false" {
                                packageLogFileOp.seekToEndOfFile()
                                if firstPackage {
                                    text = "\t{\"id\": \"\(String(describing: masterObjectDict["packages"]![key]!["id"]!))\", \"name\": \"\(key.escapeDoubleQuotes)\"}"
                                    firstPackage = false
                                } else {
                                    text = ",\n\t{\"id\": \"\(String(describing: masterObjectDict["packages"]![key]!["id"]!))\", \"name\": \"\(key.escapeDoubleQuotes)\"}"
                                }
    //                            let text = "\t{\"id\": \"\(key)\", \"name\": \"\(String(describing: packagesDict[key]!["name"]!))\"},\n"
    //                            let text = "\t{\"id\": \"\(key)\",\n\"name\": \"\(String(describing: packagesDict[key]!["name"]!))\",\n\"used\": \"false\"},\n"
    //                            let text = "\t<id>\(key)</id><name>\(String(describing: packagesDict[key]!["name"]!))</name>\n"
                                packageLogFileOp.write(text.data(using: String.Encoding.utf8)!)
                            }
                        }   // for (key, _) in packagesDict - end
                        packageLogFileOp.seekToEndOfFile()
                        packageLogFileOp.write("\n]}".data(using: String.Encoding.utf8)!)
    //                    packageLogFileOp.write("</unusedPackages>".data(using: String.Encoding.utf8)!)
                        packageLogFileOp.closeFile()
                        exportedItems.append("\tUnused Packages")
                    }
                } catch {
                    WriteToLog.shared.message("failed to write the following: <unusedPackages>")
                }
            }
            
            if self.scriptsButtonState == "on" {
                var firstScript = true
                let scriptLogFile = "pruneScripts_\(timeStamp).json"
                let exportURL = getDownloadDirectory().appendingPathComponent(scriptLogFile)

                do {
                    try "{\(header),\n \"unusedScripts\":[\n".write(to: exportURL, atomically: true, encoding: .utf8)
                    
                    if let scriptLogFileOp = try? FileHandle(forUpdating: exportURL) {
                        for key in sortedArrayFromDict(theDict: masterObjectDict["scripts"]!) {
                            if masterObjectDict["scripts"]![key]?["used"]! == "false" {
                                scriptLogFileOp.seekToEndOfFile()
//                                let text = "\t{\"id\": \"\(String(describing: scriptsDict[key]!["id"]!))\", \"name\": \"\(key.escapeDoubleQuotes)\"},\n"
                                if firstScript {
                                    text = "\t{\"id\": \"\(String(describing: masterObjectDict["scripts"]![key]!["id"]!))\", \"name\": \"\(key.escapeDoubleQuotes)\"}"
                                    firstScript = false
                                } else {
                                    text = ",\n\t{\"id\": \"\(String(describing: masterObjectDict["scripts"]![key]!["id"]!))\", \"name\": \"\(key.escapeDoubleQuotes)\"}"
                                }
    //                            let text = "\t{\"id\": \"\(key)\", \"name\": \"\(String(describing: scriptsDict[key]!["name"]!))\"},\n"
    //                            let text = "\t<id>\(key)</id><name>\(String(describing: scriptsDict[key]!["name"]!))</name>\n"    // old - xml format
                                scriptLogFileOp.write(text.data(using: String.Encoding.utf8)!)
                            }
                        }   // for (key, _) in scriptsDict - end
                        scriptLogFileOp.seekToEndOfFile()
                        scriptLogFileOp.write("\n]}".data(using: String.Encoding.utf8)!)
    //                    scriptLogFileOp.write("</unusedScripts>".data(using: String.Encoding.utf8)!)
                        scriptLogFileOp.closeFile()
                        exportedItems.append("\tUnused Scripts")
                    }
                } catch {
                    WriteToLog.shared.message("failed to write the following: <unusedScripts>")
                }
            }
            
            if self.ebooksButtonState == "on" {
                var firstEbook = true
                let ebooksLogFile = "pruneEbooks_\(timeStamp).json"
                let exportURL = getDownloadDirectory().appendingPathComponent(ebooksLogFile)

                do {
                    try "{\(header),\n \"unusedEbooks\":[\n".write(to: exportURL, atomically: true, encoding: .utf8)
                    
                    if let ebooksLogFileOp = try? FileHandle(forUpdating: exportURL) {
                        for key in sortedArrayFromDict(theDict: masterObjectDict["ebooks"]!) {
                            if masterObjectDict["ebooks"]![key]?["used"]! == "false" {
                                ebooksLogFileOp.seekToEndOfFile()
//                                let text = "\t{\"id\": \"\(String(describing: ebooksDict[key]!["id"]!))\", \"name\": \"\(key.escapeDoubleQuotes)\"},\n"
                                if firstEbook {
                                    text = "\t{\"id\": \"\(String(describing: masterObjectDict["ebooks"]![key]!["id"]!))\", \"name\": \"\(key.escapeDoubleQuotes)\"}"
                                    firstEbook = false
                                } else {
                                    text = ",\n\t{\"id\": \"\(String(describing: masterObjectDict["ebooks"]![key]!["id"]!))\", \"name\": \"\(key.escapeDoubleQuotes)\"}"
                                }
    //                            let text = "\t{\"id\": \"\(key)\", \"name\": \"\(String(describing: scriptsDict[key]!["name"]!))\"},\n"
    //                            let text = "\t<id>\(key)</id><name>\(String(describing: scriptsDict[key]!["name"]!))</name>\n"    // old - xml format
                                ebooksLogFileOp.write(text.data(using: String.Encoding.utf8)!)
                            }
                        }   // for (key, _) in scriptsDict - end
                        ebooksLogFileOp.seekToEndOfFile()
                        ebooksLogFileOp.write("\n]}".data(using: String.Encoding.utf8)!)
    //                    scriptLogFileOp.write("</unusedScripts>".data(using: String.Encoding.utf8)!)
                        ebooksLogFileOp.closeFile()
                        exportedItems.append("\tUnused eBooks")
                    }
                } catch {
                    WriteToLog.shared.message("failed to write the following: <unusedEbooks>")
                }
            }
            
            if self.classesButtonState == "on" {
                var firstClass = true
                let classesLogFile = "pruneClasses_\(timeStamp).json"
                let exportURL = getDownloadDirectory().appendingPathComponent(classesLogFile)

                do {
                    try "{\(header),\n \"unusedClasses\":[\n".write(to: exportURL, atomically: true, encoding: .utf8)
                    
                    if let classesLogFileOp = try? FileHandle(forUpdating: exportURL) {
                        for key in sortedArrayFromDict(theDict: masterObjectDict["classes"]!) {
                            if masterObjectDict["classes"]![key]?["used"]! == "false" {
                                classesLogFileOp.seekToEndOfFile()
//                                let text = "\t{\"id\": \"\(String(describing: classesDict[key]!["id"]!))\", \"name\": \"\(key.escapeDoubleQuotes)\"},\n"
                                if firstClass {
                                    text = "\t{\"id\": \"\(String(describing: masterObjectDict["classes"]![key]!["id"]!))\", \"name\": \"\(key.escapeDoubleQuotes)\"}"
                                    firstClass = false
                                } else {
                                    text = ",\n\t{\"id\": \"\(String(describing: masterObjectDict["classes"]![key]!["id"]!))\", \"name\": \"\(key.escapeDoubleQuotes)\"}"
                                }
    //                            let text = "\t{\"id\": \"\(key)\", \"name\": \"\(String(describing: scriptsDict[key]!["name"]!))\"},\n"
    //                            let text = "\t<id>\(key)</id><name>\(String(describing: scriptsDict[key]!["name"]!))</name>\n"    // old - xml format
                                classesLogFileOp.write(text.data(using: String.Encoding.utf8)!)
                            }
                        }   // for (key, _) in scriptsDict - end
                        classesLogFileOp.seekToEndOfFile()
                        classesLogFileOp.write("\n]}".data(using: String.Encoding.utf8)!)
    //                    scriptLogFileOp.write("</unusedScripts>".data(using: String.Encoding.utf8)!)
                        classesLogFileOp.closeFile()
                        exportedItems.append("\tUnused Classes")
                    }
                } catch {
                    WriteToLog.shared.message("failed to write the following: <unusedClasses>")
                }
            }
            
            if self.computerGroupsButtonState == "on" {
                var firstComputerGroup = true
                let computerGroupLogFile = "pruneComputerGroups_\(timeStamp).json"
                let exportURL = getDownloadDirectory().appendingPathComponent(computerGroupLogFile)

                do {
                    try "{\(header),\n \"unusedComputerGroups\":[\n".write(to: exportURL, atomically: true, encoding: .utf8)
                    
                    if let computerGroupLogFileOp = try? FileHandle(forUpdating: exportURL) {
                        for key in sortedArrayFromDict(theDict: masterObjectDict["computerGroups"]!) {
                            if masterObjectDict["computerGroups"]![key]?["used"]! == "false" {
                                computerGroupLogFileOp.seekToEndOfFile()
    //                            let text = "\t{\"id\": \"\(String(describing: computerGroupsDict[key]!["id"]!))\", \"name\": \"\(key.escapeDoubleQuotes)\", \"groupType\": \"\(String(describing: computerGroupsDict[key]!["groupType"]!))\"},\n"
                                if firstComputerGroup {
                                    text = "\t{\"id\": \"\(String(describing: masterObjectDict["computerGroups"]![key]!["id"]!))\", \"name\": \"\(key.escapeDoubleQuotes)\", \"groupType\": \"\(String(describing: masterObjectDict["computerGroups"]![key]!["groupType"]!))\"}"
                                    firstComputerGroup = false
                                } else {
                                    text = ",\n\t{\"id\": \"\(String(describing: masterObjectDict["computerGroups"]![key]!["id"]!))\", \"name\": \"\(key.escapeDoubleQuotes)\", \"groupType\": \"\(String(describing: masterObjectDict["computerGroups"]![key]!["groupType"]!))\"}"
                                }
    //                            let text = "\t<id>\(String(describing: computerGroupsDict[key]!["id"]!))</id><name>\(key)</name>\n"
                                computerGroupLogFileOp.write(text.data(using: String.Encoding.utf8)!)
                            }
                        }   // for (key, _) in
                        computerGroupLogFileOp.seekToEndOfFile()
                        computerGroupLogFileOp.write("\n]}".data(using: String.Encoding.utf8)!)
    //                    computerGroupLogFileOp.write("</unusedComputerGroups>".data(using: String.Encoding.utf8)!)
                        computerGroupLogFileOp.closeFile()
                        exportedItems.append("\tUnused Computer Groups")
                    }
                } catch {
                    WriteToLog.shared.message("failed to write the following: <unusedComputerGroups>")
                }
            }   // if self.computerGroupsButtonState == "on" - end
                        
            if self.computerProfilesButtonState == "on" {
                var firstComputerProfile = true
                let ComputerProfileLogFile = "pruneComputerProfiles_\(timeStamp).json"
                let exportURL = getDownloadDirectory().appendingPathComponent(ComputerProfileLogFile)

                do {
                    try "{\(header),\n \"unusedComputerProfiles\":[\n".write(to: exportURL, atomically: true, encoding: .utf8)
                    
                    if let computerProfileLogFileOp = try? FileHandle(forUpdating: exportURL) {
                        for key in sortedArrayFromDict(theDict: masterObjectDict["osxconfigurationprofiles"]!) {
                            if masterObjectDict["osxconfigurationprofiles"]![key]?["used"]! == "false" {
                                computerProfileLogFileOp.seekToEndOfFile()
//                                let text = "\t{\"id\": \"\(String(describing: masterObjectDict["osxconfigurationprofiles"]![key]!["id"]!))\", \"name\": \"\(key.escapeDoubleQuotes)\"},\n"
                                if firstComputerProfile {
                                    text = "\t{\"id\": \"\(String(describing: masterObjectDict["osxconfigurationprofiles"]![key]!["id"]!))\", \"name\": \"\(key.escapeDoubleQuotes)\"}"
                                    firstComputerProfile = false
                                } else {
                                    text = ",\n\t{\"id\": \"\(String(describing: masterObjectDict["osxconfigurationprofiles"]![key]!["id"]!))\", \"name\": \"\(key.escapeDoubleQuotes)\"}"
                                }
    //                            let text = "\t<id>\(String(describing: computerGroupsDict[key]!["id"]!))</id><name>\(key)</name>\n"
                                computerProfileLogFileOp.write(text.data(using: String.Encoding.utf8)!)
                                firstComputerProfile = false
                            }
                        }   // for (key, _) in
                        computerProfileLogFileOp.seekToEndOfFile()
                        computerProfileLogFileOp.write("\n]}".data(using: String.Encoding.utf8)!)
    //                    computerGroupLogFileOp.write("</unusedComputerGroups>".data(using: String.Encoding.utf8)!)
                        computerProfileLogFileOp.closeFile()
                        exportedItems.append("\tUnused Computer Configuration Profiles")
                    }
                } catch {
                    WriteToLog.shared.message("failed to write the following: <unusedComputerProfiles>")
                }
            }   // if self.computerGroupsButtonState == "on" - end
            
            
            
            if self.macAppsButtonState == "on" {
                var firstMacApp = true
                let macAppLogFile = "pruneMacApps_\(timeStamp).json"

                let exportURL = getDownloadDirectory().appendingPathComponent(macAppLogFile)

                do {
                    try "{\(header),\n \"unusedMacApps\":[\n".write(to: exportURL, atomically: true, encoding: .utf8)
                    
                    if let macAppLogFileOp = try? FileHandle(forUpdating: exportURL) {
                        for key in sortedArrayFromDict(theDict: masterObjectDict["macapplications"]!) {
                            if masterObjectDict["macapplications"]![key]?["used"]! == "false" {
                                macAppLogFileOp.seekToEndOfFile()
//                                let text = "\t{\"id\": \"\(String(describing: policiesDict[key]!["id"]!))\", \"name\": \"\(key.escapeDoubleQuotes)\"},\n"
                                let displayName = key.escapeDoubleQuotes
                                if firstMacApp {
                                    text = "\t{\"id\": \"\(String(describing: masterObjectDict["macapplications"]![key]!["id"]!))\", \"name\": \"\(displayName)\"}"
                                    firstMacApp = false
                                } else {
                                    text = ",\n\t{\"id\": \"\(String(describing: masterObjectDict["macapplications"]![key]!["id"]!))\", \"name\": \"\(displayName)\"}"
                                }
    //                            let text = "\t{\"id\": \"\(key)\", \"name\": \"\(String(describing: packagesDict[key]!["name"]!))\"},\n"
    //                            let text = "\t{\"id\": \"\(key)\",\n\"name\": \"\(String(describing: packagesDict[key]!["name"]!))\",\n\"used\": \"false\"},\n"
    //                            let text = "\t<id>\(key)</id><name>\(String(describing: packagesDict[key]!["name"]!))</name>\n"
                                macAppLogFileOp.write(text.data(using: String.Encoding.utf8)!)
                            }
                        }   // for (key, _) in packagesDict - end
                        macAppLogFileOp.seekToEndOfFile()
                        macAppLogFileOp.write("\n]}".data(using: String.Encoding.utf8)!)
                        macAppLogFileOp.closeFile()
                        exportedItems.append("\tUnused Mac Apps")
                    }
                } catch {
                    WriteToLog.shared.message("failed to write the following: <unusedMacApps>")
                }
            }
            
            if self.policiesButtonState == "on" {
                var firstPolicy = true
                let policyLogFile = "prunePolicies_\(timeStamp).json"
                let exportURL = getDownloadDirectory().appendingPathComponent(policyLogFile)

                do {
                    try "{\(header),\n \"unusedPolicies\":[\n".write(to: exportURL, atomically: true, encoding: .utf8)
                    
                    if let policyLogFileOp = try? FileHandle(forUpdating: exportURL) {
                        for key in sortedArrayFromDict(theDict: masterObjectDict["policies"]!) {
                            if masterObjectDict["policies"]![key]?["used"]! == "false" || masterObjectDict["policies"]![key]?["enabled"]! == "false" {
                                policyLogFileOp.seekToEndOfFile()

                                var displayName = key.escapeDoubleQuotes
                                if masterObjectDict["policies"]![key]?["enabled"]! == "false" {
                                    displayName.append("    [disabled]")
                                }

                                if firstPolicy {
                                    text = "\t{\"id\": \"\(String(describing: masterObjectDict["policies"]![key]!["id"]!))\", \"name\": \"\(displayName)\"}"
                                    firstPolicy = false
                                } else {
                                    text = ",\n\t{\"id\": \"\(String(describing: masterObjectDict["policies"]![key]!["id"]!))\", \"name\": \"\(displayName)\"}"
                                }
    //                            let text = "\t{\"id\": \"\(key)\", \"name\": \"\(String(describing: packagesDict[key]!["name"]!))\"},\n"
    //                            let text = "\t{\"id\": \"\(key)\",\n\"name\": \"\(String(describing: packagesDict[key]!["name"]!))\",\n\"used\": \"false\"},\n"
    //                            let text = "\t<id>\(key)</id><name>\(String(describing: packagesDict[key]!["name"]!))</name>\n"
                                policyLogFileOp.write(text.data(using: String.Encoding.utf8)!)
                            }
                        }   // for (key, _) in packagesDict - end
                        policyLogFileOp.seekToEndOfFile()
                        policyLogFileOp.write("\n]}".data(using: String.Encoding.utf8)!)
                        policyLogFileOp.closeFile()
                        exportedItems.append("\tUnused Policies")
                    }
                } catch {
                    WriteToLog.shared.message("failed to write the following: <unusedPolicies>")
                }
            }
            
            if self.printersButtonState == "on" {
                var firstPolicy = true
                let printerLogFile = "prunePrinters_\(timeStamp).json"
                let exportURL = getDownloadDirectory().appendingPathComponent(printerLogFile)

                do {
                    try "{\(header),\n \"unusedPrinters\":[\n".write(to: exportURL, atomically: true, encoding: .utf8)
                    
                    if let printerLogFileOp = try? FileHandle(forUpdating: exportURL) {
                        for key in sortedArrayFromDict(theDict: masterObjectDict["printers"]!) {
                            if masterObjectDict["printers"]![key]?["used"]! == "false" {
                                printerLogFileOp.seekToEndOfFile()

                                var displayName = key.escapeDoubleQuotes

                                if firstPolicy {
                                    text = "\t{\"id\": \"\(String(describing: masterObjectDict["printers"]![key]!["id"]!))\", \"name\": \"\(displayName)\"}"
                                    firstPolicy = false
                                } else {
                                    text = ",\n\t{\"id\": \"\(String(describing: masterObjectDict["printers"]![key]!["id"]!))\", \"name\": \"\(displayName)\"}"
                                }
                                printerLogFileOp.write(text.data(using: String.Encoding.utf8)!)
                            }
                        }   // for (key, _) in packagesDict - end
                        printerLogFileOp.seekToEndOfFile()
                        printerLogFileOp.write("\n]}".data(using: String.Encoding.utf8)!)
                        printerLogFileOp.closeFile()
                        exportedItems.append("\tUnused Printers")
                    }
                } catch {
                    WriteToLog.shared.message("failed to write the following: <unusedPrinters>")
                }
            }
            
            if self.restrictedSoftwareButtonState == "on" {
                var firstTitle = true
                let rsLogFile = "pruneRestrictedSoftware_\(timeStamp).json"
//                let rsLogFile = "pruneRestrictedSoftware_\(timeStamp).xml"
                let exportURL = getDownloadDirectory().appendingPathComponent(rsLogFile)

                do {
                    try "{\(header),\n \"unusedRestrictedSoftware\":[\n".write(to: exportURL, atomically: true, encoding: .utf8)
                    
                    if let logFileOp = try? FileHandle(forUpdating: exportURL) {
                        for key in sortedArrayFromDict(theDict: masterObjectDict["restrictedsoftware"]!) {
                            if masterObjectDict["restrictedsoftware"]![key]?["used"]! == "false" {
                                logFileOp.seekToEndOfFile()
//                                let text = "\t{\"id\": \"\(String(describing: masterObjectDict["restrictedsoftware"]![key]!["id"]!))\", \"name\": \"\(key.escapeDoubleQuotes)\"},\n"
                                if firstTitle {
                                    text = "\t{\"id\": \"\(String(describing: masterObjectDict["restrictedsoftware"]![key]!["id"]!))\", \"name\": \"\(key.escapeDoubleQuotes)\"}"
                                    firstTitle = false
                                } else {
                                    text = ",\n\t{\"id\": \"\(String(describing: masterObjectDict["restrictedsoftware"]![key]!["id"]!))\", \"name\": \"\(key.escapeDoubleQuotes)\"}"
                                }
    //                            let text = "\t<id>\(String(describing: masterObjectDict["restrictedsoftware"]![key]!["id"]!))</id><name>\(key)</name>\n"
                                logFileOp.write(text.data(using: String.Encoding.utf8)!)
                            }
                        }   // for (key, _) in
                        logFileOp.seekToEndOfFile()
                        logFileOp.write("\n]}".data(using: String.Encoding.utf8)!)
    //                    logFileOp.write("</unusedRestrictedSoftware>".data(using: String.Encoding.utf8)!)
                        logFileOp.closeFile()
                        exportedItems.append("\tUnused Restricted Software")
                    }
                } catch {
                    WriteToLog.shared.message("failed to write the following: <unusedRestrictedSoftware>")
                }
            }
            
            if self.computerEAsButtonState == "on" {
                var firstTitle = true
                let rsLogFile = "pruneComputerEAs_\(timeStamp).json"
                let exportURL = getDownloadDirectory().appendingPathComponent(rsLogFile)

                do {
                    try "{\(header),\n \"unusedComputerEAs\":[\n".write(to: exportURL, atomically: true, encoding: .utf8)
                    
                    if let logFileOp = try? FileHandle(forUpdating: exportURL) {
                        for key in sortedArrayFromDict(theDict: masterObjectDict["computerextensionattributes"]!) {
                            if masterObjectDict["computerextensionattributes"]![key]?["used"]! == "false" {
                                logFileOp.seekToEndOfFile()
//                                let text = "\t{\"id\": \"\(String(describing: masterObjectDict["restrictedsoftware"]![key]!["id"]!))\", \"name\": \"\(key.escapeDoubleQuotes)\"},\n"
                                if firstTitle {
                                    text = "\t{\"id\": \"\(String(describing: masterObjectDict["computerextensionattributes"]![key]!["id"]!))\", \"name\": \"\(key.escapeDoubleQuotes)\"}"
                                    firstTitle = false
                                } else {
                                    text = ",\n\t{\"id\": \"\(String(describing: masterObjectDict["computerextensionattributes"]![key]!["id"]!))\", \"name\": \"\(key.escapeDoubleQuotes)\"}"
                                }
    //                            let text = "\t<id>\(String(describing: masterObjectDict["restrictedsoftware"]![key]!["id"]!))</id><name>\(key)</name>\n"
                                logFileOp.write(text.data(using: String.Encoding.utf8)!)
                            }
                        }   // for (key, _) in
                        logFileOp.seekToEndOfFile()
                        logFileOp.write("\n]}".data(using: String.Encoding.utf8)!)
    //                    logFileOp.write("</unusedRestrictedSoftware>".data(using: String.Encoding.utf8)!)
                        logFileOp.closeFile()
                        exportedItems.append("\tUnused Computer EAs")
                    }
                } catch {
                    WriteToLog.shared.message("failed to write the following: <unusedComputerEAs>")
                }
            }
                        
            if self.mobileDeviceGroupsButtonState == "on" {
                var firstMobileDeviceGrp = true
                let mobileDeviceGroupLogFile = "pruneMobileDeviceGroups_\(timeStamp).json"
                let exportURL = getDownloadDirectory().appendingPathComponent(mobileDeviceGroupLogFile)

                do {
                    try "{\(header),\n \"unusedMobileDeviceGroups\":[\n".write(to: exportURL, atomically: true, encoding: .utf8)
                    
                    if let mobileDeviceGroupLogFileOp = try? FileHandle(forUpdating: exportURL) {
                        for key in sortedArrayFromDict(theDict: masterObjectDict["mobileDeviceGroups"]!) {
                            if masterObjectDict["mobileDeviceGroups"]![key]?["used"]! == "false" {
                                mobileDeviceGroupLogFileOp.seekToEndOfFile()
//                                let text = "\t{\"id\": \"\(String(describing: mobileDeviceGroupsDict[key]!["id"]!))\", \"name\": \"\(key.escapeDoubleQuotes)\", \"groupType\": \"\(String(describing: mobileDeviceGroupsDict[key]!["groupType"]!))\"},\n"
                                if firstMobileDeviceGrp {
                                    text = "\t{\"id\": \"\(String(describing: masterObjectDict["mobileDeviceGroups"]![key]!["id"]!))\", \"name\": \"\(key.escapeDoubleQuotes)\", \"groupType\": \"\(String(describing: masterObjectDict["mobileDeviceGroups"]![key]!["groupType"]!))\"}"
                                    firstMobileDeviceGrp = false
                                } else {
                                    text = ",\n\t{\"id\": \"\(String(describing: masterObjectDict["mobileDeviceGroups"]![key]!["id"]!))\", \"name\": \"\(key.escapeDoubleQuotes)\", \"groupType\": \"\(String(describing: masterObjectDict["mobileDeviceGroups"]![key]!["groupType"]!))\"}"
                                }
    //                            let text = "\t<id>\(String(describing: mobileDeviceGroupLogFileOp[key]!["id"]!))</id><name>\(key)</name>\n"
                                mobileDeviceGroupLogFileOp.write(text.data(using: String.Encoding.utf8)!)
                            }
                        }   // for (key, _) in
                        mobileDeviceGroupLogFileOp.seekToEndOfFile()
                        mobileDeviceGroupLogFileOp.write("\n]}".data(using: String.Encoding.utf8)!)
    //                    mobileDeviceGroupLogFileOp.write("</unusedMobileDeviceGroups>".data(using: String.Encoding.utf8)!)
                        mobileDeviceGroupLogFileOp.closeFile()
                        exportedItems.append("\tUnused Mobile Device Groups")
                    }
                } catch {
                    WriteToLog.shared.message("failed to write the following: <unusedMobileDeviceGroups>")
                }
            }   // if self.mobileDeviceGroupsButtonState == "on" - end
            
            if self.mobileDeviceAppsButtonState == "on" {
                var firstMobileDeviceApp = true
                let logFile = "pruneMobileDeviceApps_\(timeStamp).json"
                let exportURL = getDownloadDirectory().appendingPathComponent(logFile)

                do {
                    try "{\(header),\n \"unusedMobileDeviceApps\":[\n".write(to: exportURL, atomically: true, encoding: .utf8)
                    
                    if let logFileOp = try? FileHandle(forUpdating: exportURL) {
                        for key in sortedArrayFromDict(theDict: masterObjectDict["mobiledeviceapplications"]!) {
                            if masterObjectDict["mobiledeviceapplications"]![key]?["used"]! == "false" {
                                logFileOp.seekToEndOfFile()
//                                let text = "\t{\"id\": \"\(String(describing: masterObjectDict["mobiledeviceapplications"]![key]!["id"]!))\", \"name\": \"\(key.escapeDoubleQuotes)\"},\n"
                                if firstMobileDeviceApp {
                                    text = "\t{\"id\": \"\(String(describing: masterObjectDict["mobiledeviceapplications"]![key]!["id"]!))\", \"name\": \"\(key.escapeDoubleQuotes)\"}"
                                    firstMobileDeviceApp = false
                                } else {
                                    text = ",\n\t{\"id\": \"\(String(describing: masterObjectDict["mobiledeviceapplications"]![key]!["id"]!))\", \"name\": \"\(key.escapeDoubleQuotes)\"}"
                                }
    //                            let text = "\t<id>\(String(describing: masterObjectDict["mobiledeviceapplications"]![key]!["id"]!))</id><name>\(key)</name>\n"
                                logFileOp.write(text.data(using: String.Encoding.utf8)!)
                            }
                        }   // for (key, _) in
                        logFileOp.seekToEndOfFile()
                        logFileOp.write("\n]}".data(using: String.Encoding.utf8)!)
    //                    logFileOp.write("</unusedMobileDeviceApps>".data(using: String.Encoding.utf8)!)
                        logFileOp.closeFile()
                        exportedItems.append("\tUnused Mobile Device Apps")
                    }
                } catch {
                    WriteToLog.shared.message("failed to write the following: <unusedMobileDeviceApps>")
                }
            }   // if self.mobileDeviceAppsButtonState == "on" - end
                        
            if self.configurationProfilesButtonState == "on" {
                var firstConfigurationProfile = true
                let logFile = "pruneMobileDeviceConfigurationProfiles_\(timeStamp).json"
                let exportURL = getDownloadDirectory().appendingPathComponent(logFile)

                do {
                    try "{\(header),\n \"unusedMobileDeviceConfigurationProfiles\":[\n".write(to: exportURL, atomically: true, encoding: .utf8)
                    
                    if let logFileOp = try? FileHandle(forUpdating: exportURL) {
                        for key in sortedArrayFromDict(theDict: masterObjectDict["mobiledeviceconfigurationprofiles"]!) {
                            if masterObjectDict["mobiledeviceconfigurationprofiles"]![key]?["used"]! == "false" {
                                logFileOp.seekToEndOfFile()
//                                let text = "\t{\"id\": \"\(String(describing: masterObjectDict["mobiledeviceconfigurationprofiles"]![key]!["id"]!))\", \"name\": \"\(key.escapeDoubleQuotes)\"},\n"
                                if firstConfigurationProfile {
                                    text = "\t{\"id\": \"\(String(describing: masterObjectDict["mobiledeviceconfigurationprofiles"]![key]!["id"]!))\", \"name\": \"\(key.escapeDoubleQuotes)\"}"
                                    firstConfigurationProfile = false
                                } else {
                                    text = ",\n\t{\"id\": \"\(String(describing: masterObjectDict["mobiledeviceconfigurationprofiles"]![key]!["id"]!))\", \"name\": \"\(key.escapeDoubleQuotes)\"}"
                                }
    //                            let text = "\t<id>\(String(describing: masterObjectDict["mobiledeviceconfigurationprofiles"]![key]!["id"]!))</id><name>\(key)</name>\n"
                                logFileOp.write(text.data(using: String.Encoding.utf8)!)
                            }
                        }   // for (key, _) in
                        logFileOp.seekToEndOfFile()
                        logFileOp.write("\n]}".data(using: String.Encoding.utf8)!)
    //                    logFileOp.write("</unusedMobileDeviceConfigurationProfiles>".data(using: String.Encoding.utf8)!)
                        logFileOp.closeFile()
                        exportedItems.append("\tUnused Mobile Device Configuration Profiles")
                    }
                } catch {
                    WriteToLog.shared.message("failed to write the following: <unusedMobileDeviceConfigurationProfiles>")
                }
            }   // if self.configurationProfilesButtonState == "on" - end
            
            if self.mobileDeviceEAsButtonState == "on" {
                var firstTitle = true
                let rsLogFile = "pruneMobileDeviceEAs_\(timeStamp).json"
                let exportURL = getDownloadDirectory().appendingPathComponent(rsLogFile)

                do {
                    try "{\(header),\n \"unusedMobileDeviceEAs\":[\n".write(to: exportURL, atomically: true, encoding: .utf8)
                    
                    if let logFileOp = try? FileHandle(forUpdating: exportURL) {
                        for key in sortedArrayFromDict(theDict: masterObjectDict["mobiledeviceextensionattributes"]!) {
                            if masterObjectDict["mobiledeviceextensionattributes"]![key]?["used"]! == "false" {
                                logFileOp.seekToEndOfFile()
//                                let text = "\t{\"id\": \"\(String(describing: masterObjectDict["restrictedsoftware"]![key]!["id"]!))\", \"name\": \"\(key.escapeDoubleQuotes)\"},\n"
                                if firstTitle {
                                    text = "\t{\"id\": \"\(String(describing: masterObjectDict["mobiledeviceextensionattributes"]![key]!["id"]!))\", \"name\": \"\(key.escapeDoubleQuotes)\"}"
                                    firstTitle = false
                                } else {
                                    text = ",\n\t{\"id\": \"\(String(describing: masterObjectDict["mobiledeviceextensionattributes"]![key]!["id"]!))\", \"name\": \"\(key.escapeDoubleQuotes)\"}"
                                }
    //                            let text = "\t<id>\(String(describing: masterObjectDict["restrictedsoftware"]![key]!["id"]!))</id><name>\(key)</name>\n"
                                logFileOp.write(text.data(using: String.Encoding.utf8)!)
                            }
                        }   // for (key, _) in
                        logFileOp.seekToEndOfFile()
                        logFileOp.write("\n]}".data(using: String.Encoding.utf8)!)
    //                    logFileOp.write("</unusedRestrictedSoftware>".data(using: String.Encoding.utf8)!)
                        logFileOp.closeFile()
                        exportedItems.append("\tUnused Mobile Device EAs")
                    }
                } catch {
                    WriteToLog.shared.message("failed to write the following: <unusedMobileDeviceEAs>")
                }
            }
            
            if (exportedItems.count + failedExported.count > 2) {
                var exportSummary = ""
                if exportedItems.count > 1 {
                    for exportLine in exportedItems {
                        exportSummary  = "\(exportSummary)\n\(exportLine)"
                    }
                }
                if failedExported.count > 1 {
                    for failedExportLine in failedExported {
                        exportSummary  = "\(exportSummary)\n\(failedExportLine)"
                    }
                }
                Alert.shared.summary(header: "Export Summary", message: exportSummary)
            }
            working(isWorking: false)
        }   // exportQ.sync - end
    }
    
    // remove objects from the list to be deleted - start
    @IBAction func removeObject_Action(_ sender: Any) {
        DispatchQueue.main.async {
            var withOptionKey = false
            let theRow = self.object_TableView.selectedRow

            if self.unusedItems_TableArray?.count != nil {
                if let itemName = self.unusedItems_TableArray?[theRow] {
        //                print("[removeObject_Action] itemName: \(itemName)")
        //                print("[removeObject_Action] unusedItems_TableDict: \(String(describing: unusedItems_TableDict))")
                    if let itemDict = self.unusedItems_TableDict?[theRow] {
                        if (self.itemSeperators.firstIndex(of: itemName) ?? -1) == -1 {
                            for (_, objectType) in itemDict as [String:String] {
                                if NSEvent.modifierFlags.contains(.option) {
    //                               print("check for option key - success")
                                    withOptionKey = true
                                }
                                WriteToLog.shared.message("[removeObject_Action]      itemDict: \(itemName) and type \(objectType)")
                                WriteToLog.shared.message("[removeObject_Action] withOptionKey: \(withOptionKey)")
                                
                                switch objectType {
                                    case "packages":
                                        if withOptionKey {
                                            self.masterObjectDict["packages"]!.removeValue(forKey: itemName)
                                        } else {
                                            WriteToLog.shared.message("[removeObject_Action] single click \(objectType) - without option key")
                                            return
                                        }
                                    
                                    case "printers":
                                        if withOptionKey {
                                            self.masterObjectDict["printers"]!.removeValue(forKey: itemName)
                                        } else {
                                            WriteToLog.shared.message("[removeObject_Action] single click \(objectType) - without option key")
                                            return
                                        }
                                    
                                    case "scripts":
                                        if withOptionKey {
                                            self.masterObjectDict["scripts"]!.removeValue(forKey: itemName)
                                        } else {
                                            WriteToLog.shared.message("[removeObject_Action] single click \(objectType) - without option key")
                                            return
                                        }
                                        
                                    case "ebooks":
                                        if withOptionKey {
                                            self.masterObjectDict["ebooks"]!.removeValue(forKey: itemName)
                                        } else {
                                            WriteToLog.shared.message("[removeObject_Action] single click \(objectType) - without option key")
                                            return
                                        }
                                        
                                    case "classes":
                                        if withOptionKey {
                                            self.masterObjectDict["classes"]!.removeValue(forKey: itemName)
                                        } else {
                                            WriteToLog.shared.message("[removeObject_Action] single click \(objectType) - without option key")
                                            return
                                        }
                                    
                                    case "computergroups":
                                        if withOptionKey {
                                          self.masterObjectDict["computerGroups"]!.removeValue(forKey: itemName)
                                        } else {
                                          WriteToLog.shared.message("[removeObject_Action] single click \(objectType) - without option key")
                                          return
                                        }
                                    
                                    case "osxconfigurationprofiles":
                                        if withOptionKey {
                                          self.masterObjectDict["osxconfigurationprofiles"]?.removeValue(forKey: itemName)
                                        } else {
                                          WriteToLog.shared.message("[removeObject_Action] single click \(objectType) - without option key")
                                          return
                                        }
                                    
                                    case "policies":
                                        if withOptionKey {
                                            self.masterObjectDict["policies"]?.removeValue(forKey: itemName.replacingOccurrences(of: ")    [disabled]", with: ")"))
                                        } else {
                                            WriteToLog.shared.message("[removeObject_Action] single click \(objectType) - without option key")
                                            return
                                        }
                                    
                                    case "restrictedsoftware":
                                        if withOptionKey {
                                            self.masterObjectDict["restrictedsoftware"]?.removeValue(forKey: itemName)
                                        } else {
                                            WriteToLog.shared.message("[removeObject_Action] single click \(objectType) - without option key")
                                            return
                                        }
                                    
                                    case "computerextensionattributes":
                                        if withOptionKey {
                                            self.masterObjectDict["computerextensionattributes"]?.removeValue(forKey: itemName)
                                        } else {
                                            WriteToLog.shared.message("[removeObject_Action] single click \(objectType) - without option key")
                                            return
                                        }

                                    case "mobiledevicegroups":
                                        if withOptionKey {
                                            self.masterObjectDict["mobileDeviceGroups"]!.removeValue(forKey: itemName)
                                        } else {
                                            WriteToLog.shared.message("[removeObject_Action] single click \(objectType) - without option key")
                                            return
                                        }

                                    case "mobiledeviceapplications":
                                        if withOptionKey {
                                            self.masterObjectDict["mobiledeviceapplications"]?.removeValue(forKey: itemName)
                                        } else {
                                            WriteToLog.shared.message("[removeObject_Action] single click \(objectType) - without option key")
                                            return
                                        }
                                    
                                    case "mobiledeviceconfigurationprofiles":
                                        if withOptionKey {
                                            self.masterObjectDict[objectType]?.removeValue(forKey: itemName)
                                        } else {
                                            WriteToLog.shared.message("[removeObject_Action] single click \(objectType) - without option key")
                                            return
                                        }
                                    
                                case "mobiledeviceextensionattributes":
                                    if withOptionKey {
                                        self.masterObjectDict["mobiledeviceextensionattributes"]?.removeValue(forKey: itemName)
                                    } else {
                                        WriteToLog.shared.message("[removeObject_Action] single click \(objectType) - without option key")
                                        return
                                    }

                                    default:
                                        WriteToLog.shared.message("[removeObject_Action] unknown objectType: \(String(describing: self.removeObject_Action))")
                                        return
                                }
                            self.unusedItems_TableDict?.remove(at: theRow)
                            self.unusedItems_TableArray?.remove(at: theRow)
                            }
                            self.object_TableView.reloadData()
                        }
                    }
                }
            }   // if theRow < self.unusedItems_TableArray!.count - end
        }   // dispatchQueue.main.async - end
    }
    // remove objects from the list to be deleted - end
        
    // remove objects from the server - start
    @IBAction func remove_Action(_ sender: Any) {
        
        working(isWorking: true)
        
        let removeDisabledPolicies = NSEvent.modifierFlags.contains(.option) ? true : false
        
        JamfProServer.source = jamfServer_TextField.stringValue.replacingOccurrences(of: "?failover", with: "")
        jamfCreds            = "\(JamfProServer.username):\(JamfProServer.password)"
        let jamfUtf8Creds    = jamfCreds.data(using: String.Encoding.utf8)
        jamfBase64Creds      = (jamfUtf8Creds?.base64EncodedString())!
        
        theDeleteQ.maxConcurrentOperationCount = 4
        
        let viewing = view_PopUpButton.title
        
        var masterItemsToDeleteArray = [[String:String]]()
        if (viewing == "All" && packages_Button.state.rawValue == 1) || viewing == "Packages" {
            for (key, _) in masterObjectDict["packages"]! {
                if masterObjectDict["packages"]![key]?["used"] == "false" {
                    let id = "\(String(describing: masterObjectDict["packages"]![key]!["id"]!))"
                    WriteToLog.shared.message("[remove_Action] remove package with id: \(key)")
                    masterItemsToDeleteArray.append(["packages":id])
                }
            }
        }

        if (viewing == "All" && scripts_Button.state.rawValue == 1) || viewing == "Scripts" {
            for (key, _) in masterObjectDict["scripts"]! {
                if masterObjectDict["scripts"]![key]?["used"] == "false" {
                    let id = "\(String(describing: masterObjectDict["scripts"]![key]!["id"]!))"
                    WriteToLog.shared.message("[remove_Action] remove script with id: \(id)")
                    masterItemsToDeleteArray.append(["scripts":id])
                }
            }
        }

        if (viewing == "All" && computerGroups_Button.state.rawValue == 1) || viewing == "Computer Groups" {
            for (key, _) in masterObjectDict["computerGroups"]! {
                if masterObjectDict["computerGroups"]![key]?["used"] == "false" {
                    let id = "\(String(describing: masterObjectDict["computerGroups"]![key]!["id"]!))"
                    WriteToLog.shared.message("[remove_Action] remove computer group with id: \(id)")
                    masterItemsToDeleteArray.append(["computergroups":id])
                }
            }
        }

        if (viewing == "All" && computerProfiles_Button.state.rawValue == 1) || viewing == "Configuration Policies" {
            for (key, _) in masterObjectDict["osxconfigurationprofiles"]! {
                if masterObjectDict["osxconfigurationprofiles"]?[key]?["used"] == "false" {
                    let id = "\(String(describing: masterObjectDict["osxconfigurationprofiles"]![key]!["id"]!))"
                    WriteToLog.shared.message("[remove_Action] remove computer configuration profile with id: \(id)")
                    masterItemsToDeleteArray.append(["osxconfigurationprofiles":id])
                }
            }
        }
        
        if (viewing == "All" && ebooks_Button.state.rawValue == 1) || viewing == "eBooks" {
            for (key, _) in masterObjectDict["ebooks"]! {
                if masterObjectDict["ebooks"]?[key]?["used"] == "false" {
                    let id = "\(String(describing: masterObjectDict["ebooks"]![key]!["id"]!))"
                    WriteToLog.shared.message("[remove_Action] remove eBook with id: \(key)")
                    masterItemsToDeleteArray.append(["ebooks":id])
                }
            }
        }

        if (viewing == "All" && policies_Button.state.rawValue == 1) || viewing == "Policies" {
            print("[remove_Action] removeDisabledPolicies: \(removeDisabledPolicies)")
            for (key, _) in masterObjectDict["policies"]! {
                if masterObjectDict["policies"]?[key]?["used"] == "false" || (removeDisabledPolicies && masterObjectDict["policies"]?[key]?["enabled"] == "false") {
                    let id = "\(String(describing: masterObjectDict["policies"]![key]!["id"]!))"
                    WriteToLog.shared.message("[remove_Action] remove policy with id: \(id)")
                    masterItemsToDeleteArray.append(["policies":id])
                }
            }
        }
        
        if (viewing == "All" && printers_Button.state.rawValue == 1) || viewing == "Printers" {
            for (key, _) in masterObjectDict["printers"]! {
                if masterObjectDict["printers"]?[key]?["used"] == "false" {
                    let id = "\(String(describing: masterObjectDict["printers"]![key]!["id"]!))"
                    WriteToLog.shared.message("[remove_Action] remove printer with id: \(id)")
                    masterItemsToDeleteArray.append(["printers":id])
                }
            }
        }
        
        if (viewing == "All" && restrictedSoftware_Button.state.rawValue == 1) || viewing == "Restricted Software" {
            for (key, _) in masterObjectDict["restrictedsoftware"]! {
                if masterObjectDict["restrictedsoftware"]?[key]?["used"] == "false" {
                    let id = "\(String(describing: masterObjectDict["restrictedsoftware"]![key]!["id"]!))"
                    WriteToLog.shared.message("[remove_Action] remove restricted software with id: \(id)")
                    masterItemsToDeleteArray.append(["restrictedsoftware":id])
                }
            }
        }
        
        if (viewing == "All" && computerEAs_Button.state.rawValue == 1) || viewing == "Computer EAs" {
            for (key, _) in masterObjectDict["computerextensionattributes"]! {
                if masterObjectDict["computerextensionattributes"]?[key]?["used"] == "false" {
                    let id = "\(String(describing: masterObjectDict["computerextensionattributes"]![key]!["id"]!))"
                    WriteToLog.shared.message("[remove_Action] remove computer extension attribute with id: \(id)")
                    masterItemsToDeleteArray.append(["computerextensionattributes":id])
                }
            }
        }

        if (viewing == "All" && mobileDeviceGroups_Button.state.rawValue == 1) || viewing == "Mobile Device Groups" {
            for (key, _) in masterObjectDict["mobileDeviceGroups"]! {
                if masterObjectDict["mobileDeviceGroups"]?[key]?["used"] == "false" {
                    let id = "\(String(describing: masterObjectDict["mobileDeviceGroups"]![key]!["id"]!))"
                    WriteToLog.shared.message("[remove_Action] remove mobile device group with id: \(id)")
                    masterItemsToDeleteArray.append(["mobiledevicegroups":id])
                }
            }
        }

        if (viewing == "All" && mobileDeviceApps_Button.state.rawValue == 1) || viewing == "Mobile Device Apps" {
            for (key, _) in masterObjectDict["mobiledeviceapplications"]! {
                if masterObjectDict["mobiledeviceapplications"]?[key]?["used"] == "false" {
                    let id = "\(String(describing: masterObjectDict["mobiledeviceapplications"]![key]!["id"]!))"
                    WriteToLog.shared.message("[remove_Action] remove mobile device application with id: \(id)")
                    masterItemsToDeleteArray.append(["mobiledeviceapplications":id])
                }
            }
        }

        if (viewing == "All" && configurationProfiles_Button.state.rawValue == 1) || viewing == "Mobile Device Config. Profiles" {
            for (key, _) in masterObjectDict["mobiledeviceconfigurationprofiles"]! {
                if masterObjectDict["mobiledeviceconfigurationprofiles"]?[key]?["used"] == "false" {
                    let id = "\(String(describing: masterObjectDict["mobiledeviceconfigurationprofiles"]![key]!["id"]!))"
                    WriteToLog.shared.message("[remove_Action] remove mobile device configuration profile with id: \(id)")
                    masterItemsToDeleteArray.append(["mobiledeviceconfigurationprofiles":id])
                }
            }
        }
        
        if (viewing == "All" && classes_Button.state.rawValue == 1) || viewing == "Classes" {
            for (key, _) in masterObjectDict["classes"]! {
                if masterObjectDict["classes"]?[key]?["used"] == "false" {
                    let id = "\(String(describing: masterObjectDict["classes"]![key]!["id"]!))"
                    WriteToLog.shared.message("[remove_Action] remove class with id: \(id)")
                    masterItemsToDeleteArray.append(["classes":id])
                }
            }
        }
        
        if (viewing == "All" && mobileDeviceEAs_Button.state.rawValue == 1) || viewing == "Mobile Device EAs" {
            for (key, _) in masterObjectDict["mobiledeviceextensionattributes"]! {
                if masterObjectDict["mobiledeviceextensionattributes"]?[key]?["used"] == "false" {
                    let id = "\(String(describing: masterObjectDict["mobiledeviceextensionattributes"]![key]!["id"]!))"
                    WriteToLog.shared.message("[remove_Action] remove mobile device extension attribute with id: \(id)")
                    masterItemsToDeleteArray.append(["mobiledeviceextensionattributes":id])
                }
            }
        }
        
//        print("masterItemsToDeleteArray: \(masterItemsToDeleteArray)")

        // alert the user before deleting
        let continueDelete = Alert.shared.warning(header: "Caution:", message: "You are about to remove \(masterItemsToDeleteArray.count) objects, are you sure you want to continue?")

        if continueDelete == "OK" {
            theDeleteQ.addOperation { [self] in
                self.counter = 0
                var completed = false
                // loop through master list and delete items - start
                
                DispatchQueue.main.async {
                    self.process_TextField.isHidden = false
                }
                DispatchQueue.main.async {
                    self.spinner_ProgressIndicator.increment(by: -100.0)
                    self.spinner_ProgressIndicator.isIndeterminate = false
                }
                
                var deleteCount       = 0
                var failedDeleteCount = 0
                var extraMessage      = ""
                self.itemsToDelete    = masterItemsToDeleteArray.count
                
                for item in masterItemsToDeleteArray {
                    // pause on the first record in a category to make sure we have the permissions to delete
                    completed = false
                    for (category, id) in item {
//                        DispatchQueue.main.async {
//                            self.process_TextField.stringValue = "\nProcessed item \(counter+1) of \(masterItemsToDeleteArray.count)"
//                        }
//                        if category == "packages" {
//                            WriteToLog.shared.message("[remove_Action] removing \(category) from JCDS")
//                        }
                        xmlAction(action: "DELETE", theServer: JamfProServer.source, base64Creds: self.jamfBase64Creds, theCategory: category, theEndpoint: "\(category)/id/\(id)") {
                            (xmlResult: (Int,String)) in
//
                            let (statusCode, _) = xmlResult
                            if !(statusCode >= 200 && statusCode <= 299) {
                                if "\(statusCode)" == "401" {
                                    self.working(isWorking: false)
                                    Alert.shared.display(header: "Alert", message: "Verify username and password.")
                                    return
                                }
                                failedDeleteCount+=1
                                WriteToLog.shared.message("[remove_Action] failed to removed category \(category) with id: \(id)")
                            } else {
                                deleteCount+=1
                                WriteToLog.shared.message("[remove_Action] removed category \(category) with id: \(id)")
                            }
                            self.counter += 1
                            
                            completed = true

        //                        print("json returned packages: \(result)")
                            if self.counter == masterItemsToDeleteArray.count {
                                if failedDeleteCount > 0 {
                                    let item = (failedDeleteCount == 1) ? "item was":"items were"
                                    extraMessage = "\nNote, \(failedDeleteCount) \(item) not deleted."
                                }
                                Alert.shared.display(header: "Removal process complete.\(extraMessage)", message: "")
                                DispatchQueue.main.async {
                                    self.spinner_ProgressIndicator.isIndeterminate = true
                                }
                                self.working(isWorking: false)
                                self.process_TextField.isHidden = true
                            }

                        }   // Xml().action - end
                        while !completed {
                            usleep(50000)
                        }
                    }
                }
                // loop through master list and delete items - end
            }
        } else {
            self.working(isWorking: false)
        }
    }
    // remove objects from the server - end
    
    @IBAction func updateViewButton_Action(_ sender: NSButton) {
        var withOptionKey = false
        // check for option key - start
        if NSEvent.modifierFlags.contains(.option) {
            withOptionKey = true
        }
        // check for option key - end
        
        if view_PopUpButton.itemArray.count > 1 {
            setViewButton(setOn: false)
//            view_PopUpButton.removeAllItems()
//            view_PopUpButton.addItem(withTitle: "All")
//            view_PopUpButton.isEnabled = false
//            unusedItems_TableArray?.removeAll()
//            object_TableView.reloadData()
        }
        
        let state = (sender.state.rawValue == 1) ? "on":"off"
        if withOptionKey {
            setAllButtonsState(theState: state)
        } else {
            let title = sender.title
            
//            if let ident = sender.identifier?.rawValue {
//                print("set masterObjectDict for \(ident)")
//                masterObjectDict[ident] = [:]
//            }
//            if state == "on" {
//                view_PopUpButton.addItem(withTitle: "\(title)")
//            } else {
//                if view_PopUpButton.indexOfItem(withTitle: title) >= 0 {
//                    view_PopUpButton.removeItem(withTitle: "\(title)")
//                }
//            }
            switch title {
            case "Packages":
                packagesButtonState = "\(state)"
            case "Scripts":
                scriptsButtonState = "\(state)"
            case "Computer Groups":
                computerGroupsButtonState = "\(state)"
            case "Computer Profiles":
                computerProfilesButtonState = "\(state)"
            case "Mac Apps":
                macAppsButtonState = "\(state)"
            case "Policies":
                policiesButtonState = "\(state)"
            case "Printers":
                printersButtonState = "\(state)"
            case "Restricted Software":
                restrictedSoftwareButtonState = "\(state)"
            case "Computer EAs":
                computerEAsButtonState = "\(state)"
            case "Mobile Device Groups":
                mobileDeviceGroupsButtonState = "\(state)"
            case "Mobile Device Apps":
                mobileDeviceAppsButtonState = "\(state)"
            case "Mobile Device Config. Profiles":
                configurationProfilesButtonState = "\(state)"
            case "Classes":
                classesButtonState = "\(state)"
            case "eBooks":
                ebooksButtonState = "\(state)"
            case "Mobile Device EAs":
                mobileDeviceEAsButtonState = "\(state)"
            default:
                if state == "on" {
                    
                }
            }
        }
    }
    
    func xmlAction(action: String, theServer: String, base64Creds: String, theCategory: String = "", theEndpoint: String, completion: @escaping (_ result: (Int,String)) -> Void) {
        

        JamfPro.shared.getToken(serverUrl: JamfProServer.source, whichServer: "source", base64creds: JamfProServer.base64Creds) { [self]
            (result: (Int,String)) in
            let (statusCode, theResult) = result
//            print("[xmlAction] token check")
            if theResult == "success" {
                let getRecordQ = OperationQueue()   //DispatchQueue(label: "com.jamf.getRecordQ", qos: DispatchQoS.background)
            
                URLCache.shared.removeAllCachedResponses()
                var existingDestUrl = ""
                
                existingDestUrl = "\(theServer)/JSSResource/\(theEndpoint)"
                existingDestUrl = existingDestUrl.replacingOccurrences(of: "//JSSResource", with: "/JSSResource")
                
        //        if LogLevel.debug { WriteToLog.shared.message(stringOfText: "[Json.getRecord] Looking up: \(existingDestUrl)\n") }
                WriteToLog.shared.message("[Xml.\(action.uppercased())] existing endpoint URL: \(existingDestUrl)")
                let destEncodedURL = URL(string: existingDestUrl)
                let xmlRequest     = NSMutableURLRequest(url: destEncodedURL! as URL)
                
                let semaphore = DispatchSemaphore(value: 1)
                getRecordQ.maxConcurrentOperationCount = 4
                getRecordQ.addOperation {
                    
                    xmlRequest.httpMethod = "\(action.uppercased())"
                    let destConf = URLSessionConfiguration.default
                    
                    destConf.httpAdditionalHeaders = ["Authorization" : "\(JamfProServer.authType) \(JamfProServer.accessToken)", "Content-Type" : "text/xml", "Accept" : "text/xml", "User-Agent" : AppInfo.userAgentHeader]
                    
                    
                    let destSession = Foundation.URLSession(configuration: destConf, delegate: self, delegateQueue: OperationQueue.main)
                    let task = destSession.dataTask(with: xmlRequest as URLRequest, completionHandler: { [self]
                        (data, response, error) -> Void in
                        destSession.finishTasksAndInvalidate()
                        if let httpResponse = response as? HTTPURLResponse {
                            
                            if action == "DELETE" {
                                DispatchQueue.main.async { [self] in
                                    process_TextField.stringValue = "\nProcessed item \(counter+1) of \(itemsToDelete)"
                                    spinner_ProgressIndicator.increment(by: 100.0/Double(itemsToDelete))
                                    if (counter+1) == self.itemsToDelete {
                                        spinner_ProgressIndicator.increment(by: 100.0)
                                    }
                                }
                            }
                            
                            if httpResponse.statusCode >= 200 && httpResponse.statusCode <= 299 {
                                do {
                                    if action == "DELETE" {
                                        WriteToLog.shared.message("[Xml.\(action.uppercased())] successfully removed: \(theEndpoint) from Jamf Pro")
//                                        if theCategory == "packages" {
//                                            let endpointArray = theEndpoint.components(separatedBy: "/")
//                                            if endpointArray.count == 3 {
//                                                WriteToLog.shared.message("[remove_Action] removing \(String(describing: packageIdFileNameDict[endpointArray[2]])) from JCDS")
//                                                removeFromJcds(fileId: endpointArray[2]) {
//                                                    (result: String) in
//                                                    print("[xmlAction.removeFromJcds] result: \(result)")
//                                                    completion((httpResponse.statusCode,result))
//                                                }
//                                            } else {
//                                                completion((100,"skipped"))
//                                            }
//                                            
//                                        } else {
                                            let returnedXML = String(data: data!, encoding: String.Encoding(rawValue: String.Encoding.utf8.rawValue))!
                                            completion((httpResponse.statusCode,returnedXML))
//                                        }
                                    } else {
                                        WriteToLog.shared.message("[Xml.\(action.uppercased())] successfully retrieved: \(theEndpoint)")
                                        let returnedXML = String(data: data!, encoding: String.Encoding(rawValue: String.Encoding.utf8.rawValue))!
                                        
                                        completion((httpResponse.statusCode,returnedXML))
                                    }
                                }
                            } else {
                                WriteToLog.shared.message("[Xml.\(action.uppercased())] error HTTP Status Code: \(httpResponse.statusCode)\n")
                                WriteToLog.shared.message("[Xml.action] Nothing returned for server: \(theServer) endpoint: \(theEndpoint)")
                                if let theId = Int(destEncodedURL?.lastPathComponent ?? "") {
                                    failedLookupDict(theEndpoint: theEndpoint, theId: "\(theId)")
                                }
                                completion((httpResponse.statusCode,""))
                            }
                        } else {
                            WriteToLog.shared.message("[Xml.action] no response from \(existingDestUrl)")
                            WriteToLog.shared.message("[Xml.action] Nothing returned for server: \(theServer) endpoint: \(theEndpoint)")
                            if let theId = Int(destEncodedURL?.lastPathComponent ?? "") {
                                failedLookupDict(theEndpoint: theEndpoint, theId: "\(theId)")
                            }
                            completion((0,""))
                        }   // if let httpResponse - end
                        semaphore.signal()
                        if error != nil {
                        }
                    })  // let task = destSession - end
                    //print("GET")
                    task.resume()
                }   // getRecordQ - end
            }
        }
    }
    
    func allButtonsEnabledState(theState: Bool) {
        packages_Button.isEnabled              = theState
        scripts_Button.isEnabled               = theState
        computerGroups_Button.isEnabled        = theState
        computerProfiles_Button.isEnabled      = theState
        policies_Button.isEnabled              = theState
        printers_Button.isEnabled              = theState
        macApps_Button.isEnabled               = theState
        restrictedSoftware_Button.isEnabled    = theState
        computerEAs_Button.isEnabled           = theState
        mobileDeviceGroups_Button.isEnabled    = theState
        mobileDeviceApps_Button.isEnabled      = theState
        configurationProfiles_Button.isEnabled = theState
        classes_Button.isEnabled               = theState
        ebooks_Button.isEnabled                = theState
        mobileDeviceEAs_Button.isEnabled       = theState
    }
    
    func setAllButtonsState(theState: String) {
        let state = (theState == "on") ? 1:0
        
        packages_Button.state = NSControl.StateValue(rawValue: state)
        scripts_Button.state = NSControl.StateValue(rawValue: state)
        ebooks_Button.state = NSControl.StateValue(rawValue: state)
        classes_Button.state = NSControl.StateValue(rawValue: state)
        computerGroups_Button.state = NSControl.StateValue(rawValue: state)
        computerProfiles_Button.state = NSControl.StateValue(rawValue: state)
        macApps_Button.state = NSControl.StateValue(rawValue: state)
        policies_Button.state = NSControl.StateValue(rawValue: state)
        printers_Button.state = NSControl.StateValue(rawValue: state)
        restrictedSoftware_Button.state = NSControl.StateValue(rawValue: state)
        computerEAs_Button.state = NSControl.StateValue(rawValue: state)
        mobileDeviceGroups_Button.state = NSControl.StateValue(rawValue: state)
        mobileDeviceApps_Button.state = NSControl.StateValue(rawValue: state)
        configurationProfiles_Button.state = NSControl.StateValue(rawValue: state)
        mobileDeviceEAs_Button.state = NSControl.StateValue(rawValue: state)
        
        if theState == "on" {
            let availableButtons = ["Packages", "Scripts", "eBooks", "Classes", "Computer Groups", "Computer Profiles", "Mac Apps", "Policies", "Printers", "Restricted Software", "Computer EAs", "Mobile Device Groups", "Mobile Device Apps", "Mobile Device Config. Profiles", "Mobile Device EAs"]
            for theButton in availableButtons {
                view_PopUpButton.addItem(withTitle: "\(theButton)")
            }
        } else {
            view_PopUpButton.removeAllItems()
            view_PopUpButton.addItem(withTitle: "All")
            view_PopUpButton.isEnabled = false
        }
        packagesButtonState              = "\(theState)"
        scriptsButtonState               = "\(theState)"
        ebooksButtonState                = "\(theState)"
        classesButtonState               = "\(theState)"
        computerGroupsButtonState        = "\(theState)"
        computerProfilesButtonState      = "\(theState)"
        macAppsButtonState               = "\(theState)"
        policiesButtonState              = "\(theState)"
        printersButtonState              = "\(theState)"
        restrictedSoftwareButtonState    = "\(theState)"
        computerEAsButtonState           = "\(theState)"
        mobileDeviceGroupsButtonState    = "\(theState)"
        mobileDeviceAppsButtonState      = "\(theState)"
        configurationProfilesButtonState = "\(theState)"
        mobileDeviceEAsButtonState       = "\(theState)"
    }
    
    func setViewButton(setOn: Bool) {
        if setOn {
            if packagesButtonState == "on" {
                view_PopUpButton.addItem(withTitle: "Packages")
            }
            if scriptsButtonState == "on" {
                view_PopUpButton.addItem(withTitle: "Scripts")
            }
            if ebooksButtonState == "on" {
                view_PopUpButton.addItem(withTitle: "eBooks")
            }
            if classesButtonState == "on" {
                view_PopUpButton.addItem(withTitle: "Classes")
            }
            if computerGroupsButtonState == "on" {
                view_PopUpButton.addItem(withTitle: "Computer Groups")
            }
            if computerProfilesButtonState == "on" {
                view_PopUpButton.addItem(withTitle: "Computer Profiles")
            }
            if macAppsButtonState == "on" {
                view_PopUpButton.addItem(withTitle: "Mac Apps")
            }
            if policiesButtonState == "on" {
                view_PopUpButton.addItem(withTitle: "Policies")
            }
            if printersButtonState == "on" {
                view_PopUpButton.addItem(withTitle: "Printers")
            }
            if restrictedSoftwareButtonState == "on" {
                view_PopUpButton.addItem(withTitle: "Restricted Software")
            }
            if computerEAsButtonState == "on" {
                view_PopUpButton.addItem(withTitle: "Computer EAs")
            }
            if mobileDeviceGroupsButtonState == "on" {
                view_PopUpButton.addItem(withTitle: "Mobile Device Groups")
            }
            if mobileDeviceAppsButtonState == "on" {
                view_PopUpButton.addItem(withTitle: "Mobile Device Apps")
            }
            if configurationProfilesButtonState == "on" {
                view_PopUpButton.addItem(withTitle: "Mobile Device Config. Profiles")
            }
            if mobileDeviceEAsButtonState == "on" {
                view_PopUpButton.addItem(withTitle: "Mobile Device EAs")
            }
        } else {
            view_PopUpButton.removeAllItems()
            view_PopUpButton.addItem(withTitle: "All")
            view_PopUpButton.isEnabled = false
            unusedItems_TableArray?.removeAll()
            object_TableView.reloadData()
        }
    }
        
    func updateProcessTextfield(currentCount: String) {
        DispatchQueue.main.async { [self] in
            let theText = self.process_TextField.stringValue.components(separatedBy: "...")[0]
            let progressText = NSMutableAttributedString(string: "\(theText)... \(currentCount)", attributes: [.paragraphStyle: myParagraphStyle])
            self.process_TextField.attributedStringValue = progressText
    
//            self.process_TextField.stringValue = "\(theText)... \(currentCount)"
        }
    }
    
    func getDownloadDirectory() -> URL {
        let downloadsDirectory = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0]
        return downloadsDirectory
    }
    
    func isScoped(scope: [String:AnyObject]) -> Bool {
//        print("[isScoped] scope: \(scope)")
        // Note checking limitations or exclusions
        let scopeObjects = ["all_computers","all_jss_users","buildings","departments","computers","computer_groups","jss_users","jss_user_groups", "all_mobile_devices","mobile_devices","mobile_device_groups"]
        for theObject in scopeObjects {
            switch theObject {
            case "all_computers", "all_mobile_devices", "all_jss_users":
                if let test = scope[theObject] {
                    if (test as! Bool) {
                        return true
                    }
                }
            default:
//                print("[isScoped] scope[theObject]: \(String(describing: scope[theObject]))")
                if let test = scope[theObject] {
//                    print("[isScoped]-passed test - \(theObject): \(test)")
                    if (test.count > 0) {
                        return true
                    }
                }
            }
        }
        
        return false
    }
    
//    @IBAction func savePassword_Action(_ sender: Any) {
//        if savePassword_Button.state.rawValue == 1 {
//            userDefaults.set(1, forKey: "saveCreds")
////            print("save password")
//        } else {
//            userDefaults.set(0, forKey: "saveCreds")
////            print("don't save password")
//        }
//    }
    
    func working(isWorking: Bool) {
        if isWorking {
            DispatchQueue.main.async {
                self.scan_Button.isEnabled = false
                self.spinner_ProgressIndicator.startAnimation(self)
            }
        } else {
            DispatchQueue.main.async {
                self.scan_Button.isEnabled = true
                self.spinner_ProgressIndicator.stopAnimation(self)
            }
        }
        allButtonsEnabledState(theState: !isWorking)
    }
    
    @objc func viewSelectObject() {
//        print("[\(#line)] doubleClicked Row: \(String(object_TableView.clickedRow))")

        DispatchQueue.main.async {
            let theRow = self.object_TableView.selectedRow

            if let displayedName = self.unusedItems_TableArray?[theRow] {
                let itemName = displayedName.replacingOccurrences(of: ")    [disabled]", with: ")")
                
                if let itemDict = self.unusedItems_TableDict?[theRow] {
                    if (self.itemSeperators.firstIndex(of: itemName) ?? -1) == -1 {
                        for (_, objectType) in itemDict as [String:String] {
                            
                            WriteToLog.shared.message("[viewSelectObject] open itemDict: \(itemName) of type \(objectType) in browser")
                            
                            switch objectType {
                                case "packages":
                                    if let objectId = self.masterObjectDict[objectType]?[itemName]?["id"], let objectURL = URL(string: "\(JamfProServer.source)/view/settings/computer-management/\(objectType.lowercased())/\(objectId)?tab=general") {
                                        NSWorkspace.shared.open(objectURL)
                                    }
                                
                                case "scripts":
                                let scriptPath = (JamfProServer.majorVersion == 10 && JamfProServer.minorVersion > 39) || JamfProServer.majorVersion > 10 ? "computer-management":"computer"
                                    if let objectId = self.masterObjectDict["scripts"]?[itemName]?["id"], let objectURL = URL(string: "\(JamfProServer.source)/view/settings/\(scriptPath)/scripts/\(objectId)") {
                                      NSWorkspace.shared.open(objectURL)
                                    }
                                
                                case "classes":
                                    if let objectId = self.masterObjectDict["classes"]?[itemName]?["id"], let objectURL = URL(string: "\(JamfProServer.source)/classes.html/?id=\(objectId)") {
                                      NSWorkspace.shared.open(objectURL)
                                    }
                                
                                case "computergroups":
                                      if let objectId = self.masterObjectDict["computerGroups"]?[itemName]?["id"], let groupType = self.masterObjectDict["computerGroups"]?[itemName]?["groupType"], let objectURL = URL(string: "\(JamfProServer.source)/\(groupType)s.html/?id=\(objectId)&o=r") {
                                        NSWorkspace.shared.open(objectURL)
                                      }
                                
                                case "osxconfigurationprofiles":
                                      if let objectId = self.masterObjectDict["osxconfigurationprofiles"]?[itemName]?["id"], let objectURL = URL(string: "\(JamfProServer.source)/OSXConfigurationProfiles.html?id=\(objectId)&o=r") {
                                          NSWorkspace.shared.open(objectURL)
                                      }
                                
                                case "policies":
                                    if let objectId = self.masterObjectDict["policies"]?[itemName]?["id"], let objectURL = URL(string: "\(JamfProServer.source)/policies.html?id=\(objectId)&o=r") {
                                        NSWorkspace.shared.open(objectURL)
                                    }
                                
                                case "printers":
                                    if let objectId = self.masterObjectDict["printers"]?[itemName]?["id"], let objectURL = URL(string: "\(JamfProServer.source)/printers.html?id=\(objectId)&o=r") {
                                        NSWorkspace.shared.open(objectURL)
                                    }
                                
                                case "restrictedsoftware":
                                    if let objectId = self.masterObjectDict["restrictedsoftware"]?[itemName]?["id"], let objectURL = URL(string: "\(JamfProServer.source)/restrictedSoftware.html?id=\(objectId)&o=r") {
                                        NSWorkspace.shared.open(objectURL)
//
                                    }
                                
                                case "computerextensionattributes":
                                    if let objectId = self.masterObjectDict[objectType]?[itemName]?["id"], let objectURL = URL(string: "\(JamfProServer.source)/view/settings/computer-management/computer-extension-attributes/\(objectId)") {
                                        NSWorkspace.shared.open(objectURL)
                                    }

                                case "mobiledevicegroups":
                                    if let objectId = self.masterObjectDict["mobileDeviceGroups"]?[itemName]?["id"], let groupType = self.masterObjectDict["mobileDeviceGroups"]?[itemName]?["groupType"], let objectURL = URL(string: "\(JamfProServer.source)/\(groupType)s.html/?id=\(objectId)&o=r") {
                                        NSWorkspace.shared.open(objectURL)
                                    }

                                case "mobiledeviceapplications":
                                    if let objectId = self.masterObjectDict["mobiledeviceapplications"]?[itemName]?["id"], let objectURL = URL(string: "\(JamfProServer.source)/mobileDeviceApps.html?id=\(objectId)&o=r") {
                                        NSWorkspace.shared.open(objectURL)
                                    }
                                
                                case "mobiledeviceconfigurationprofiles":
                                    if let objectId = self.masterObjectDict[objectType]?[itemName]?["id"], let objectURL = URL(string: "\(JamfProServer.source)/iOSConfigurationProfiles.html?id=\(objectId)&o=r") {
                                        NSWorkspace.shared.open(objectURL)
                                    }
                                
                                case "ebooks":
                                    if let objectId = self.masterObjectDict["ebooks"]?[itemName]?["id"], let objectURL = URL(string: "\(JamfProServer.source)/eBooks.html/?id=\(objectId)") {
                                      NSWorkspace.shared.open(objectURL)
                                    }
                                    
                                case "mobiledeviceextensionattributes":
                                    if let objectId = self.masterObjectDict[objectType]?[itemName]?["id"], let objectURL = URL(string: "\(JamfProServer.source)/view/settings/device-management/mobile-device-extension-attributes/\(objectId)") {
                                        NSWorkspace.shared.open(objectURL)
                                    }

                                default:
                                    WriteToLog.shared.message("[viewSelectObject] unknown objectType: \(String(describing: self.removeObject_Action))")
                            }
                            return
                        }
                    }
                }   //if let itemDict - end
            }   // if let itemName - end
        }   // dispatchQueue.main.async - end
    }   // func viewSelectObject - end
    
    // Delegate Methods - start
    func sendLoginInfo(loginInfo: (String,String,String,String,Int)) {
        
        var saveCredsState: Int?
        (_, jamfServer_TextField.stringValue, _, _,saveCredsState) = loginInfo
//        (_,jamfServer_TextField.stringValue,uname_TextField.stringValue,passwd_TextField.stringValue,saveCredsState) = loginInfo
        
        let enteredServer = JamfProServer.source.replacingOccurrences(of: "://", with: "/")
        let tmpArray = enteredServer.components(separatedBy: "/")
        if !(tmpArray.count > 1 && JamfProServer.source.contains("://")) {
            _ = Alert.shared.display(header: "", message: "Invalid server URL.")
            DispatchQueue.main.async {
                self.performSegue(withIdentifier: "loginView", sender: nil)
                self.working(isWorking: false)
            }
        }
        
        
        JamfProServer.source = jamfServer_TextField.stringValue
        jamfCreds            = "\(JamfProServer.username):\(JamfProServer.password)"
        let jamfUtf8Creds    = jamfCreds.data(using: String.Encoding.utf8)
        jamfBase64Creds      = (jamfUtf8Creds?.base64EncodedString())!
        
        saveCreds = (saveCredsState == 1) ? true:false
        // check authentication, set auth method - start

        JamfPro.shared.getToken(serverUrl: JamfProServer.source, whichServer: "source", base64creds: jamfBase64Creds) {
            (result: (Int,String)) in
            let (statusCode, theResult) = result
            if theResult == "success" {
                DispatchQueue.main.async {
                    LoginWindow.show = false
                    
                    defaults.set(JamfProServer.source, forKey: "currentServer")
                    defaults.set(JamfProServer.username, forKey: "username")
                    useApiClient = 1
                    
                    // save password if checked - start
                    if self.saveCreds {
                        Credentials().save(service: JamfProServer.source.fqdnFromUrl, account: JamfProServer.username, credential: JamfProServer.password)
                    }
                    
                    self.logout = false
                    WriteToLog.shared.message("[ViewController] successfully authenticated to \(JamfProServer.source)")
                    // save password if checked - end
                }
            } else {
                DispatchQueue.main.async {
                    self.performSegue(withIdentifier: "loginView", sender: nil)
                    self.working(isWorking: false)
                }
            }
        }
            // check authentication - stop
    }
    
    func selectedFile(fileURL: URL) {
        print("[ViewController] fileURL: \(fileURL)")
    }
    // Delegate Methods - end
    
    override func prepare(for segue: NSStoryboardSegue, sender: Any?) {
        if segue.identifier == "loginView" {
            let loginVC: LoginViewController = segue.destinationController as! LoginViewController
            loginVC.delegate = self
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        myParagraphStyle.lineSpacing = 5
        myParagraphStyle.alignment   = .center
        
        
        let logFileURL: URL
        let fileManager = FileManager.default
        let logFileName = getCurrentTime().replacingOccurrences(of: ":", with: "") + "_" + Log.file
        // Get the Logs directory in the app's container
        let logsDirectory = fileManager.urls(for: .libraryDirectory, in: .userDomainMask).first!.appendingPathComponent("Logs")
        Log.path = logsDirectory.path
        // Create the directory if it doesn't exist
        if !fileManager.fileExists(atPath: Log.path) {
            do {
                try fileManager.createDirectory(at: logsDirectory, withIntermediateDirectories: true, attributes: nil)
                print("[ViewController.viewDidLoad] Created Logs directory at \(logsDirectory)")
            } catch {
                print("[ViewController.viewDidLoad] Failed to create Logs directory: \(error.localizedDescription)")
            }
        }
        
        // Set up the log file URL
        logFileURL = logsDirectory.appendingPathComponent(logFileName)
        Log.filePath = logFileURL.path
        
        // Create the log file if it doesn't exist
        if !fileManager.fileExists(atPath: logFileURL.path) {
            print("[ViewController.viewDidLoad] Create log file: \(logFileURL.path)")
            fileManager.createFile(atPath: logFileURL.path, contents: nil, attributes: nil)
        }
        
        
        let appBuild          = Bundle.main.infoDictionary!["CFBundleVersion"] as! String
        WriteToLog.shared.message("-------------------------------------------------------")
        WriteToLog.shared.message("-     Prune Version: \(AppInfo.version) Build: \(appBuild )")
        WriteToLog.shared.message("-------------------------------------------------------")
        
        object_TableView.delegate     = self
        object_TableView.dataSource   = self
        object_TableView.doubleAction = #selector(viewSelectObject)
        
        importLayer.importDelegate    = self
    }

    override func viewDidAppear() {
        super.viewDidAppear()

        if LoginWindow.show {
            performSegue(withIdentifier: "loginView", sender: nil)
            LoginWindow.show = false
        }
    }
    
    override func viewWillDisappear() {
//        print("[viewWillDisappear] log file: \(Log.path!)\(Log.file)")
        if !didRun {
            if FileManager.default.fileExists(atPath: Log.path + Log.file) {
                do {
                    try FileManager.default.removeItem(atPath: Log.path + Log.file)
                } catch {
                    print("[viewWillDisappear] failed to remove log file: \(Log.path)\(Log.file)")
                }
            }
        }
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
//            print("hidden column 1")
            object_TableView.tableColumns[1].isHidden = true
        }
//        } else if tableColumn == object_TableView.tableColumns[1] {
//            let result:NSPopUpButton = tableView.make(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "objectType"), owner: self) as! NSPopUpButton
//            cellIdentifier = CellIdentifiers.TypeCell
//        }
    
        if let cell = object_TableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: cellIdentifier), owner: nil) as? NSTableCellView {
            cell.textField?.stringValue = text
            cell.toolTip = text
            return cell
        }
        return nil
    }
    
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping(  URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        completionHandler(.useCredential, URLCredential(trust: challenge.protectionSpace.serverTrust!))
    }
}

extension String {
    var fqdnFromUrl: String {
        get {
            var fqdn = ""
            let nameArray = self.components(separatedBy: "/")
            if nameArray.count > 2 {
                fqdn = nameArray[2]
            } else {
                fqdn =  self
            }
            if fqdn.contains(":") {
                let fqdnArray = fqdn.components(separatedBy: ":")
                fqdn = fqdnArray[0]
            }
            return fqdn
        }
    }
    var escapeDoubleQuotes: String {
        get {
            let newString = self.replacingOccurrences(of: "\"", with: "\\\"")
            return newString
        }
    }
}

extension Notification.Name {
    public static let logoutNotification = Notification.Name("logoutNotification")
}
