//
//  ViewController.swift
//  prune
//
//  Created by Leslie Helou on 12/11/19.
//  Copyright © 2019 Leslie Helou. All rights reserved.
//

import Cocoa
import Foundation
import SwiftyXMLParser

class ViewController: NSViewController, SendingLoginInfoDelegate, URLSessionDelegate {
    
    var theGetQ    = OperationQueue() // create operation queue for API POST/PUT calls
    var theDeleteQ = OperationQueue() // queue for delete API calls
    
    @IBOutlet weak var jamfServer_TextField: NSTextField!
    @IBOutlet weak var uname_TextField: NSTextField!
    @IBOutlet weak var passwd_TextField: NSSecureTextField!
    @IBOutlet weak var savePassword_Button: NSButton!
    
    @IBOutlet weak var scan_Button: NSButton!
    @IBOutlet weak var view_PopUpButton: NSPopUpButton!
    @IBOutlet weak var packages_Button: NSButton!
    @IBOutlet weak var scripts_Button: NSButton!
    @IBOutlet weak var ebooks_Button: NSButton!
    @IBOutlet weak var classes_Button: NSButton!
    @IBOutlet weak var computerGroups_Button: NSButton!
    @IBOutlet weak var computerProfiles_Button: NSButton!
    @IBOutlet weak var policies_Button: NSButton!
    @IBOutlet weak var restrictedSoftware_Button: NSButton!
    @IBOutlet weak var computerEAs_Button: NSButton!
    @IBOutlet weak var mobileDeviceGroups_Button: NSButton!
    @IBOutlet weak var mobileDeviceApps_Button: NSButton!
    @IBOutlet weak var configurationProfiles_Button: NSButton!
    @IBOutlet weak var mobileDeviceEAs_Button: NSButton!
    
    @IBOutlet weak var object_TableView: NSTableView!
    
    @IBOutlet weak var spinner_ProgressIndicator: NSProgressIndicator!
    
    @IBOutlet weak var import_Button: NSPathControl!
    
    @IBOutlet weak var process_TextField: NSTextField!
    
    let defaults = UserDefaults.standard
    
    var username       = ""
    var password       = ""
    
    var currentServer   = ""
    var jamfCreds       = ""
    var jamfBase64Creds = ""
    var saveCreds       = false
    var jpapiToken      = ""
    var completed       = 0
    var logout          = false
    var counter         = 0
    var incrememt       = 0.0
    var itemsToDelete   = 0
    // define master dictionary of items
    // ex. masterObjectDict["packages"] = [package1Name:["id":id1,"name":name1],package2Name:["id":id2,"name":name2]]
    var masterObjectDict = [String:[String:[String:String]]]()
    var masterObjects    = ["advancedcomputersearches", "advancedmobiledevicesearches", "packages", "osxconfigurationprofiles", "scripts", "ebooks", "classes", "computerGroups", "policies", "restrictedsoftware", "computerextensionattributes", "mobileDeviceGroups", "mobiledeviceapplications", "mobiledeviceconfigurationprofiles", "computer-prestages", "patchpolicies", "patchsoftwaretitles", "mobiledeviceextensionattributes"]

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
    var policiesButtonState              = "off"
    var restrictedSoftwareButtonState    = "off"
    var computerEAsButtonState           = "off"
    var mobileDeviceGroupsButtonState      = "off"
    var mobileDeviceAppsButtonState      = "off"
    var configurationProfilesButtonState = "off"
    var mobileDeviceEAsButtonState       = "off"
    
    var computerGroupsScanned            = false
    
    var msgText    = ""
    var nextObject = ""
    
    let backgroundQ = DispatchQueue(label: "com.jamf.prune.backgroundQ", qos: DispatchQoS.background)
    
    @IBAction func logout_Action(_ sender: Any) {
//        let url  = URL(fileURLWithPath: Bundle.main.resourcePath!)
//        let path = url.deletingLastPathComponent().deletingLastPathComponent().absoluteString
//        let task = Process()
//        task.launchPath = "/usr/bin/open"
//        task.arguments  = [path]
//        task.launch()
//        exit(0)
        
        performSegue(withIdentifier: "loginView", sender: nil)
    }
    
    
    @IBAction func go_action(_ sender: Any) {
        
        working(isWorking: true)
        
        waitFor.deviceGroup             = true   // used for both computer and mobile device groups
        waitFor.computerConfiguration   = true
        waitFor.computerPrestage        = true
        waitFor.osxconfigurationprofile = true
        waitFor.policy                  = true
        waitFor.mobiledeviceobject      = true
        waitFor.ebook                   = true
        waitFor.classes                 = true
        waitFor.advancedsearch          = true
        
        computerGroupsScanned           = false
        
        view_PopUpButton.isEnabled = false
        setViewButton(setOn: true)
        view_PopUpButton.selectItem(at: 0)

        mobileGroupNameByIdDict.removeAll()
        masterObjectDict.removeAll()
        
        unusedItems_TableArray?.removeAll()
        unusedItems_TableDict?.removeAll()
        
//        process_TextField.textColor   = NSColor.blue
        process_TextField.font        = NSFont(name: "HelveticaNeue", size: CGFloat(12))
        process_TextField.stringValue = ""
        
        currentServer       = jamfServer_TextField.stringValue.replacingOccurrences(of: "?failover", with: "")
        jamfCreds           = "\(uname_TextField.stringValue):\(passwd_TextField.stringValue)"
        let jamfUtf8Creds   = jamfCreds.data(using: String.Encoding.utf8)
        jamfBase64Creds     = (jamfUtf8Creds?.base64EncodedString())!
        completed           = 0
        
        if unusedItems_TableArray?.count == 0 {
            object_TableView.reloadData()
        }
        
        JamfPro().getToken(serverUrl: currentServer, whichServer: "source", base64creds: jamfBase64Creds) { [self]
            (result: String) in
            if result == "success" {
                jpapiToken = result
                DispatchQueue.main.async { [self] in
                    defaults.set(currentServer, forKey: "server")
                    defaults.set("\(uname_TextField.stringValue)", forKey: "username")
                    process_TextField.isHidden = false
                    process_TextField.stringValue = "Starting lookups..."
                }
                // initialize masterObjectsDict
                for theObject in masterObjects {
                    masterObjectDict[theObject] = [String:[String:String]]()
                }
                WriteToLog().message(theString: "[Scan] start scanning...")
                
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
        if (FileManager.default.fileExists(atPath: Log.path!, isDirectory: &isDir)) {
            NSWorkspace.shared.open(URL(fileURLWithPath: Log.path!))
        } else {
            Alert().display(header: "Alert", message: "There are currently no log files to display.")
        }
    }
    
    func processItems(type: String) {
        
        WriteToLog().message(theString: "[processItems] Starting to process \(type)")
//        let semaphore = DispatchSemaphore(value: 0)
        theGetQ.maxConcurrentOperationCount = 4
        var groupType = ""

        theGetQ.addOperation { [self] in
                        
            switch type {
            case "computerextensionattributes","mobiledeviceextensionattributes":
                var deviceText = ""

                WriteToLog().message(theString: "[processItems] \(type)")
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
                   
                    self.xmlAction(action: "GET", theServer: self.currentServer, base64Creds: self.jamfBase64Creds, theEndpoint: type) {
                       (result: (Int,String)) in
                        let (statusCode,returnedXml) = result
                        //                                    print("[processItems] restrictedsoftware GET statusCode: \(statusCode)")
//                        var enabled       = true
                        var nameFixedXml  = returnedXml.replacingOccurrences(of: "<name>", with: "<Name>")
                        nameFixedXml      = nameFixedXml.replacingOccurrences(of: "</name>", with: "</Name>")
                        let xmlData       = nameFixedXml.data(using: .utf8)
                        let parsedXmlData = XML.parse(xmlData!)

                        let allEAs = (type == "computerextensionattributes") ? parsedXmlData.computer_extension_attributes.computer_extension_attribute: parsedXmlData.mobile_device_extension_attributes.mobile_device_extension_attribute

                        for eaInfo in allEAs {
                            if let id = eaInfo.id.text, let name = eaInfo.Name.text {

//                                if type == "computerextensionattributes" {
                                let enabled = eaInfo.enabled.bool ?? true
//                                }
                                WriteToLog().message(theString: "\(deviceText.lowercased()) extension attribute title id: \(eaInfo.id.text!) \t name: \(eaInfo.Name.text!) \t enabled: \(enabled)")
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
                       /*
                        let eaArrayCount = eaArray.count
                        if eaArrayCount > 0 {
                            DispatchQueue.main.async {
                                self.process_TextField.stringValue = "Scanning Advanced Computer Searches for groups..."
                            }
                         
                            WriteToLog().message(theString: "[processItems] call recursiveLookup for \(type)")
                            self.recursiveLookup(theServer: self.currentServer, base64Creds: self.jamfBase64Creds, theEndpoint: type, theData: eaArray, index: 0)
                            waitFor.advancedsearch = true
                            self.backgroundQ.async { [self] in
                                while true {
                                    usleep(10)
                                    if !waitFor.advancedsearch {
                                        WriteToLog().message(theString: "[processItems] advanced computer searches complete - call \(nextObject)")
                                        DispatchQueue.main.async { [self] in
                                            self.processItems(type: nextObject)
                                        }
                                        break
                                    }
                                }
                            }
                         
                        } else {
                            // no restricted software configurations exist
                            WriteToLog().message(theString: "[processItems] no advanced computer searches - call \(nextObject)")
                            DispatchQueue.main.async {
                                self.processItems(type: nextObject)
                            }
                        }

                        */
                        
                    }
                } else {
                    // skip EAs
                    WriteToLog().message(theString: "[processItems] skipping \(deviceText.lowercased()) extension attributes, calling - \(nextObject)")
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
                   
                    Json().getRecord(theServer: self.currentServer, base64Creds: self.jamfBase64Creds, theEndpoint: groupEndpoint) {
                        (result: [String:AnyObject]) in
//                            print("json returned scripts: \(result)")
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
                            WriteToLog().message(theString: "[processItems] call recursiveLookup for \(type)")
                            self.recursiveLookup(theServer: self.currentServer, base64Creds: self.jamfBase64Creds, theEndpoint: groupEndpoint, theData: computerGroupsArray, index: 0)
                            waitFor.deviceGroup = true
                            self.backgroundQ.async { [self] in
                                while true {
                                    usleep(10)
                                    if !waitFor.deviceGroup {
                                        if type == "computerGroups" || (!computerGroupsScanned && computerEAsButtonState == "on") {
//                                                print("[processItems] skipping \(type) - call mobileDeviceGroups")
                                            WriteToLog().message(theString: "[processItems] skipping \(type) - call mobileDeviceGroups")
                                            computerGroupsScanned = true
                                            DispatchQueue.main.async {
                                                self.processItems(type: "mobileDeviceGroups")
                                            }
                                            
                                        } else {
//                                                print("[processItems] skipping \(type) - call packages")
                                            WriteToLog().message(theString: "[processItems] skipping \(type) - call packages")
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
                        WriteToLog().message(theString: "[processItems] skipping \(type) - call mobileDeviceGroups")
                        DispatchQueue.main.async {
                            self.processItems(type: "mobileDeviceGroups")
                        }
                        
                    } else {
                        WriteToLog().message(theString: "[processItems] skipping \(type) - call packages")
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
                    Json().getRecord(theServer: self.currentServer, base64Creds: self.jamfBase64Creds, theEndpoint: "packages") {
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
                            }
                        }
                        WriteToLog().message(theString: "[processItems] call scripts")
                        DispatchQueue.main.async {
                            self.processItems(type: "scripts")
                        }
                    }
                } else {
                    WriteToLog().message(theString: "[processItems] skipping packages - call scripts")
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
                        
                        WriteToLog().message(theString: "[processItems] scripts complete - call eBooks")
                        DispatchQueue.main.async {
                            self.processItems(type: "ebooks")
                        }
                    }
                } else {
                    WriteToLog().message(theString: "[processItems] skipping scripts - call eBooks")
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
                    Json().getRecord(theServer: self.currentServer, base64Creds: self.jamfBase64Creds, theEndpoint: "ebooks") { [self]
                        (result: [String:AnyObject]) in
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
                            
                            WriteToLog().message(theString: "[processItems] call recursiveLookup for \(type)")
                            self.recursiveLookup(theServer: self.currentServer, base64Creds: self.jamfBase64Creds, theEndpoint: type, theData: ebooksArray, index: 0)
                            waitFor.ebook = true
                            self.backgroundQ.async { [self] in
                                while true {
                                    usleep(10)
                                    if !waitFor.ebook {
                                        WriteToLog().message(theString: "[processItems] \(msgText) complete - next object: \(nextObject)")
                                        DispatchQueue.main.async { [self] in
                                            self.processItems(type: nextObject)
                                        }
                                        break
                                    }
                                }
                            }
                        } else {
                            WriteToLog().message(theString: "[processItems] \(msgText) complete - call \(nextObject)")
                            DispatchQueue.main.async { [self] in
                                self.processItems(type: "\(nextObject)")
                            }
                        }
                    }
                } else {
                    WriteToLog().message(theString: "[processItems] skipping \(msgText) - call \(nextObject)")
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
                    Json().getRecord(theServer: self.currentServer, base64Creds: self.jamfBase64Creds, theEndpoint: "classes") { [self]
                        (result: [String:AnyObject]) in
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
                            
                            WriteToLog().message(theString: "[processItems] call recursiveLookup for \(type)")
                            self.recursiveLookup(theServer: self.currentServer, base64Creds: self.jamfBase64Creds, theEndpoint: type, theData: classesArray, index: 0)
                            waitFor.classes = true
                            self.backgroundQ.async { [self] in
                                while true {
                                    usleep(10)
                                    if !waitFor.classes {
                                        WriteToLog().message(theString: "[processItems] \(msgText) complete - next object: \(nextObject)")
                                        DispatchQueue.main.async { [self] in
                                            self.processItems(type: nextObject)
                                        }
                                        break
                                    }
                                }
                            }
                        } else {
                            WriteToLog().message(theString: "[processItems] \(msgText) complete - call \(nextObject)")
                            DispatchQueue.main.async { [self] in
                                self.processItems(type: "\(nextObject)")
                            }
                        }
                    }
                } else {
                    WriteToLog().message(theString: "[processItems] skipping \(msgText) - call \(nextObject)")
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
//                        Json().getRecord(theServer: self.currentServer, base64Creds: self.jamfBase64Creds, theEndpoint: "computerconfigurations") {
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
//                                self.recursiveLookup(theServer: self.currentServer, base64Creds: self.jamfBase64Creds, theEndpoint: "computerconfigurations", theData: computerConfigurationsArray, index: 0)
//                                waitFor.computerConfiguration = true
//                                self.backgroundQ.async {
//                                    while true {
//                                        usleep(10)
//                                        if !waitFor.computerConfiguration {
//                                            WriteToLog().message(theString: "[processItems] computerConfigurations complete - call osxconfigurationprofiles")
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
//                                WriteToLog().message(theString: "[processItems] no computerConfigurations - call osxconfigurationprofiles")
//                                DispatchQueue.main.async {
//                                    self.processItems(type: "osxconfigurationprofiles")
//                                }
//                            }
//                        }   //         Json().getRecord - computerConfigurations - end
//                    } else {
//                        WriteToLog().message(theString: "[processItems] skipping computerConfigurations - call osxconfigurationprofiles")
//                        DispatchQueue.main.async {
//                            self.processItems(type: "osxconfigurationprofiles")
//                        }
//                    }
                                                
            case "osxconfigurationprofiles":
                if self.computerGroupsButtonState == "on" || self.computerProfilesButtonState == "on" {
                    DispatchQueue.main.async {
                        self.process_TextField.stringValue = "Fetching Computer Configuration Profiles..."
                    }
                    Json().getRecord(theServer: self.currentServer, base64Creds: self.jamfBase64Creds, theEndpoint: type) {
                        (result: [String:AnyObject]) in
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
                                
                                WriteToLog().message(theString: "[processItems] call recursiveLookup for osxconfigurationprofiles")
                                self.recursiveLookup(theServer: self.currentServer, base64Creds: self.jamfBase64Creds, theEndpoint: "osxconfigurationprofiles", theData: osxconfigurationprofilesArray, index: 0)
                                waitFor.osxconfigurationprofile = true
                                self.backgroundQ.async {
                                    while true {
                                        usleep(10)
                                        if !waitFor.osxconfigurationprofile {
                                            WriteToLog().message(theString: "[processItems] osxconfigurationprofiles complete - call mobiledeviceapplications")
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
                            } else {
                                // no computer profiles exist
                                waitFor.osxconfigurationprofile = false
                                WriteToLog().message(theString: "[processItems] computer configuration profiles complete - call mobiledeviceapplications")
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
                            WriteToLog().message(theString: "[processItems] unable to read computer configuration profiles - call mobiledeviceapplications")
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
                    WriteToLog().message(theString: "[processItems] skipping computer configuration profiles - call mobiledeviceapplications")
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
                nextObject = "patchsoftwaretitles"
                
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
                    Json().getRecord(theServer: self.currentServer, base64Creds: self.jamfBase64Creds, theEndpoint: type) { [self]
                        (result: [String:AnyObject]) in
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

                                WriteToLog().message(theString: "[processItems] call recursiveLookup for \(type)")
                                self.recursiveLookup(theServer: self.currentServer, base64Creds: self.jamfBase64Creds, theEndpoint: type, theData: mobileDeviceObjectArray, index: 0)
                                waitFor.mobiledeviceobject = true
                                self.backgroundQ.async { [self] in
                                    while true {
                                        usleep(10)
                                        if !waitFor.mobiledeviceobject {
                                            WriteToLog().message(theString: "[processItems] \(msgText) complete - next object: \(nextObject)")
                                            DispatchQueue.main.async { [self] in
                                                self.processItems(type: nextObject)
                                            }
                                            break
                                        }
                                    }
                                }
                            } else {
                                // no computer configurations exist
                                WriteToLog().message(theString: "[processItems] \(msgText) complete - \(nextObject)")
                                DispatchQueue.main.async { [self] in
                                    self.processItems(type: nextObject)
                                }
                            }
                        } else {
                            WriteToLog().message(theString: "[processItems] unable to read \(msgText) - \(nextObject)")
                            waitFor.mobiledeviceobject = false
                            DispatchQueue.main.async { [self] in
                                self.processItems(type: nextObject)
                            }
                        }
                    }
                } else {
                    // skip \(msgText)
                    WriteToLog().message(theString: "[processItems] skipping \(msgText) - call \(nextObject)")
                    waitFor.mobiledeviceobject = false
                    DispatchQueue.main.async { [self] in
                        self.processItems(type: nextObject)
                    }
                }
                            
            case "patchsoftwaretitles":
                // look for packages used in patch policies
                WriteToLog().message(theString: "[processItems] patchsoftwaretitles")
        //        let nextObject = "patchsoftwaretitles"
                let nextObject = "patchpolicies"
//                    if self.computerGroupsButtonState == "on" || self.packagesButtonState == "on" {
                if self.packagesButtonState == "on" {
                    DispatchQueue.main.async {
                           self.process_TextField.stringValue = "Fetching Patch Software Titles..."
                    }

//                        self.masterObjectDict[type] = [String:[String:String]]()
                    var patchPoliciesArray = [[String:Any]]()
                    
                    self.xmlAction(action: "GET", theServer: self.currentServer, base64Creds: self.jamfBase64Creds, theEndpoint: "patchsoftwaretitles") {
                        (result: (Int,String)) in
                        let (statusCode,returnedXml) = result
//                            print("[patchsoftwaretitles] patchpolicies GET statusCode: \(statusCode)")
//                            print("[patchsoftwaretitles] patchpolicies GET xml: \(returnedXml)")
                        var nameFixedXml = returnedXml.replacingOccurrences(of: "<name>", with: "<Name>")
                        nameFixedXml = nameFixedXml.replacingOccurrences(of: "</name>", with: "</Name>")
                        let xmlData = nameFixedXml.data(using: .utf8)
                        let parsedXmlData = XML.parse(xmlData!)

                        for thePolicy in parsedXmlData.patch_software_titles.patch_software_title {
                            if let id = thePolicy.id.text, let name = thePolicy.Name.text {

                                WriteToLog().message(theString: "patchPolicy id: \(thePolicy.id.text!) \t name: \(thePolicy.Name.text!)")
                                patchPoliciesArray.append(["id": "\(thePolicy.id.text!)", "name": "\(thePolicy.Name.text!)"])
                                // mark patch policies as unused (reporting only) - start
                                self.masterObjectDict[type]!["\(name)"] = ["id":"\(id)", "used":"false"]
                                // mark patch policies as unused (reporting only) - end
                            }
                        }

                       let patchPoliciesArrayCount = patchPoliciesArray.count
                       if patchPoliciesArrayCount > 0 {
                           DispatchQueue.main.async {
                               self.process_TextField.stringValue = "Scanning Patch Policies for packages..."
                           }
                        
                           WriteToLog().message(theString: "[processItems] call recursiveLookup for \(type)")
                           self.recursiveLookup(theServer: self.currentServer, base64Creds: self.jamfBase64Creds, theEndpoint: type, theData: patchPoliciesArray, index: 0)
                           waitFor.policy = true
                           self.backgroundQ.async {
                               while true {
                                   usleep(10)
                                   if !waitFor.policy {
                                       WriteToLog().message(theString: "[processItems] patch policies complete - call \(nextObject)")
                                       DispatchQueue.main.async {
                                           self.processItems(type: nextObject)
                                       }
                                       break
                                   }
                               }
                           }    // self.backgroundQ.async - end
                           
                       } else {
                           // no patch policies exist
                           WriteToLog().message(theString: "[processItems] no patch policies - call \(nextObject)")
                           DispatchQueue.main.async {
                               self.processItems(type: nextObject)
                           }
                       }
                   }   //         Json().getRecord - patchpolicies - end
                } else {
                   WriteToLog().message(theString: "[processItems] skipping patch policies - call \(nextObject)")
                   DispatchQueue.main.async {
                       self.processItems(type: nextObject)
                   }
                }
                
            case "patchpolicies":
                    // look for groups used in patch policies
                    WriteToLog().message(theString: "[processItems] patchpolicies")
                    let nextObject = "computer-prestages"
                    if self.computerGroupsButtonState == "on" {
                        DispatchQueue.main.async {
                               self.process_TextField.stringValue = "Fetching Patch Policies..."
                        }

//                                self.masterObjectDict[type] = [String:[String:String]]()
                        var patchPoliciesArray = [[String:Any]]()
                        
                        self.xmlAction(action: "GET", theServer: self.currentServer, base64Creds: self.jamfBase64Creds, theEndpoint: "patchpolicies") {
                            (result: (Int,String)) in
                            let (statusCode,returnedXml) = result
//                                    print("[processItems] patchpolicies GET statusCode: \(statusCode)")
//                                    print("[processItems] patchpolicies GET xml: \(returnedXml)")
                            var nameFixedXml = returnedXml.replacingOccurrences(of: "<name>", with: "<Name>")
                            nameFixedXml = nameFixedXml.replacingOccurrences(of: "</name>", with: "</Name>")
                            let xmlData = nameFixedXml.data(using: .utf8)
                            let parsedXmlData = XML.parse(xmlData!)

                            for thePolicy in parsedXmlData.patch_policies.patch_policy {
                                if let id = thePolicy.id.text, let name = thePolicy.Name.text {

                                    WriteToLog().message(theString: "patchPolicy id: \(thePolicy.id.text!) \t name: \(thePolicy.Name.text!)")
                                    patchPoliciesArray.append(["id": "\(thePolicy.id.text!)", "name": "\(thePolicy.Name.text!)"])
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
                            
                               WriteToLog().message(theString: "[processItems] call recursiveLookup for \(type)")
                               self.recursiveLookup(theServer: self.currentServer, base64Creds: self.jamfBase64Creds, theEndpoint: type, theData: patchPoliciesArray, index: 0)
                               waitFor.policy = true
                               self.backgroundQ.async {
                                   while true {
                                       usleep(10)
                                       if !waitFor.policy {
                                           WriteToLog().message(theString: "[processItems] patch policies complete - call \(nextObject)")
                                           DispatchQueue.main.async {
                                               self.processItems(type: nextObject)
                                           }
                                           break
                                       }
                                   }
                               }
                               
                           } else {
                               // no patch policies exist
                               WriteToLog().message(theString: "[processItems] no patch policies - call \(nextObject)")
                               DispatchQueue.main.async {
                                   self.processItems(type: nextObject)
                               }
                           }
                       }   //         Json().getRecord - patchpolicies - end
                    } else {
                       WriteToLog().message(theString: "[processItems] skipping patch policies - call \(nextObject)")
                       DispatchQueue.main.async {
                           self.processItems(type: nextObject)
                       }
                    }
                
                
            case "computer-prestages":
                msgText    = "Computer Prestages"
                nextObject = "restrictedsoftware"
//                        let nextObject = "policies"

                
                if (self.packagesButtonState == "on" || self.computerProfilesButtonState == "on") {
                    var xmlTag = ""
//                            var name   = ""
                    DispatchQueue.main.async {
                        xmlTag = "results"
                        self.process_TextField.stringValue = "Fetching Computer Prestages..."
                    }
                    Json().getRecord(theServer: self.currentServer, base64Creds: self.jpapiToken, theEndpoint: type) { [self]
                        (result: [String:AnyObject]) in
//                                print("json returned prestages: \(result)")
//                                self.masterObjectDict[type] = [String:[String:String]]()
                        if let _ = result[xmlTag] {
                            let prestageObjectArray = result[xmlTag] as! [[String: Any]]
                            let prestageObjectArrayCount = prestageObjectArray.count
//                                    print("found \(prestageObjectArrayCount) prestages.")
                            if prestageObjectArrayCount > 0 {
                                WriteToLog().message(theString: "[processItems] scanning computer prestages for packages and computer profiles.")
                                for i in (0..<prestageObjectArrayCount) {
                                    self.updateProcessTextfield(currentCount: "\n(\(i+1)/\(prestageObjectArrayCount))")
                                    if let id = prestageObjectArray[i]["id"], let displayName = prestageObjectArray[i]["displayName"] {
                                        self.masterObjectDict[type]!["\(displayName)"] = ["id":"\(id)", "used":"false"]
                                        // mark used packages
                                        let customPackageIds  = prestageObjectArray[i]["customPackageIds"] as! [String]
//                                                print("prestage \(displayName) has the following package ids \(customPackageIds)")
                                        if self.packagesButtonState == "on" {
                                            for prestagePackageId in customPackageIds {
//                                                        print("mark package \(String(describing: self.packagesByIdDict[prestagePackageId]!)) as used.")
                                                self.masterObjectDict["packages"]!["\(String(describing: self.packagesByIdDict[prestagePackageId]!))"]?["used"] = "true"
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
//                                                print("osxconfigurationprofilesDict: \(self.osxconfigurationprofilesDict)")
                                    }
                                }
                                WriteToLog().message(theString: "[processItems] \(msgText) complete - next object: \(nextObject)")
                                DispatchQueue.main.async { [self] in
                                    self.processItems(type: nextObject)
                                }
                                
//                                        self.recursiveLookup(theServer: self.currentServer, base64Creds: self.jamfBase64Creds, theEndpoint: type, theData: mobileDeviceObjectArray, index: 0)
//                                        waitFor.computerPrestage = true
//                                        self.backgroundQ.async {
//                                            while true {
//                                                usleep(10)
//                                                if !waitFor.computerPrestage {
//                                                    WriteToLog().message(theString: "[processItems] \(msgText) complete - next object: \(nextObject)")
//                                                    DispatchQueue.main.async {
//                                                        self.processItems(type: nextObject)
//                                                    }
//                                                    break
//                                                }
//                                            }
//                                        }
                            } else {
                                // no computer Prestage exist
                                WriteToLog().message(theString: "[processItems] \(msgText) complete - \(nextObject)")
                                DispatchQueue.main.async { [self] in
                                    self.processItems(type: nextObject)
                                }
                            }
                        } else {
                            WriteToLog().message(theString: "[processItems] unable to read \(msgText) - \(nextObject)")
                            waitFor.computerPrestage = false
                            DispatchQueue.main.async { [self] in
                                self.processItems(type: nextObject)
                            }
                        }
                    }
                } else {
                    // skip computer-prestages
                    WriteToLog().message(theString: "[processItems] skipping \(msgText) - \(nextObject)")
                    waitFor.computerPrestage = false
                    DispatchQueue.main.async { [self] in
                        self.processItems(type: nextObject)
                    }
                }
        
        case "restrictedsoftware":
            WriteToLog().message(theString: "[processItems] restrictedsoftware")
            let nextObject = "advancedcomputersearches"
            if self.restrictedSoftwareButtonState == "on" || self.computerGroupsButtonState == "on" {
               DispatchQueue.main.async {
                      self.process_TextField.stringValue = "Fetching Restricted Software..."
               }

//                   self.masterObjectDict[type] = [String:[String:String]]()
               var restrictedsoftwareArray = [[String:Any]]()
               
                self.xmlAction(action: "GET", theServer: self.currentServer, base64Creds: self.jamfBase64Creds, theEndpoint: type) {
                   (result: (Int,String)) in
                   let (statusCode,returnedXml) = result
   //                                    print("[processItems] restrictedsoftware GET statusCode: \(statusCode)")
   //                                    print("[processItems] restrictedsoftware GET xml: \(returnedXml)")
                   var nameFixedXml  = returnedXml.replacingOccurrences(of: "<name>", with: "<Name>")
                   nameFixedXml      = nameFixedXml.replacingOccurrences(of: "</name>", with: "</Name>")
                   let xmlData       = nameFixedXml.data(using: .utf8)
                   let parsedXmlData = XML.parse(xmlData!)

                   for rsPolicy in parsedXmlData.restricted_software.restricted_software_title {
                       if let id = rsPolicy.id.text, let name = rsPolicy.Name.text {

//                               print("restricted software title id: \(rsPolicy.id.text!) \t name: \(rsPolicy.Name.text!)")
                           WriteToLog().message(theString: "restricted software title id: \(rsPolicy.id.text!) \t name: \(rsPolicy.Name.text!)")
                           restrictedsoftwareArray.append(["id": "\(rsPolicy.id.text!)", "name": "\(rsPolicy.Name.text!)"])
                           // mark restricted software title as unused (reporting only)
                           self.masterObjectDict[type]!["\(name)"] = ["id":"\(id)", "used":"false"]
                       }
                   }
                   
                   let restrictedsoftwareArrayCount = restrictedsoftwareArray.count
                   if restrictedsoftwareArrayCount > 0 {
                       DispatchQueue.main.async {
                           self.process_TextField.stringValue = "Scanning Restricted Software for groups..."
                       }
                    
                       WriteToLog().message(theString: "[processItems] call recursiveLookup for \(type)")
                       self.recursiveLookup(theServer: self.currentServer, base64Creds: self.jamfBase64Creds, theEndpoint: type, theData: restrictedsoftwareArray, index: 0)
                       waitFor.policy = true
                       self.backgroundQ.async {
                           while true {
                               usleep(10)
                               if !waitFor.policy {
                                   WriteToLog().message(theString: "[processItems] restricted software configurations complete - call \(nextObject)")
                                   DispatchQueue.main.async {
                                       self.processItems(type: nextObject)
                                   }
                                   break
                               }
                           }
                       }
                       
                   } else {
                       // no restricted software configurations exist
                       WriteToLog().message(theString: "[processItems] no restricted software configurations - call \(nextObject)")
                       DispatchQueue.main.async {
                           self.processItems(type: nextObject)
                       }
                   }
               }
            } else {
                // skip restrictedsoftware
                WriteToLog().message(theString: "[processItems] skipping restricted software, calling - \(nextObject)")
                DispatchQueue.main.async {
                    self.processItems(type: nextObject)
                }
            }
            
            case "advancedcomputersearches":
                WriteToLog().message(theString: "[processItems] \(type)")
                let nextObject = "advancedmobiledevicesearches"
                if self.computerGroupsButtonState == "on" || self.computerEAsButtonState == "on" {
                   DispatchQueue.main.async {
                          self.process_TextField.stringValue = "Fetching Advanced Computer Searches..."
                   }

    //                   self.masterObjectDict[type] = [String:[String:String]]()
                   var advancedcomputersearchArray = [[String:Any]]()
                   
                    self.xmlAction(action: "GET", theServer: self.currentServer, base64Creds: self.jamfBase64Creds, theEndpoint: type) {
                       (result: (Int,String)) in
                       let (statusCode,returnedXml) = result
       //                                    print("[processItems] restrictedsoftware GET statusCode: \(statusCode)")
       //                                    print("[processItems] restrictedsoftware GET xml: \(returnedXml)")
                       var nameFixedXml  = returnedXml.replacingOccurrences(of: "<name>", with: "<Name>")
                       nameFixedXml      = nameFixedXml.replacingOccurrences(of: "</name>", with: "</Name>")
                       let xmlData       = nameFixedXml.data(using: .utf8)
                       let parsedXmlData = XML.parse(xmlData!)

                       for acsPolicy in parsedXmlData.advanced_computer_searches.advanced_computer_search {
                           if let id = acsPolicy.id.text, let name = acsPolicy.Name.text {

    //                               print("restricted software title id: \(acsPolicy.id.text!) \t name: \(acsPolicy.Name.text!)")
                               WriteToLog().message(theString: "advanced computer search title id: \(acsPolicy.id.text!) \t name: \(acsPolicy.Name.text!)")
                               advancedcomputersearchArray.append(["id": "\(acsPolicy.id.text!)", "name": "\(acsPolicy.Name.text!)"])
                               // mark advanced computer search title as unused (reporting only)
                               self.masterObjectDict[type]!["\(name)"] = ["id":"\(id)", "used":"false"]
                           }
                       }
                       
                       let advancedcomputersearchArrayCount = advancedcomputersearchArray.count
                       if advancedcomputersearchArrayCount > 0 {
                           DispatchQueue.main.async {
                               self.process_TextField.stringValue = "Scanning Advanced Computer Searches for groups..."
                           }
                        
                           WriteToLog().message(theString: "[processItems] call recursiveLookup for \(type)")
                           self.recursiveLookup(theServer: self.currentServer, base64Creds: self.jamfBase64Creds, theEndpoint: type, theData: advancedcomputersearchArray, index: 0)
                           waitFor.advancedsearch = true
                           self.backgroundQ.async {
                               while true {
                                   usleep(10)
                                   if !waitFor.advancedsearch {
                                       WriteToLog().message(theString: "[processItems] advanced computer searches complete - call \(nextObject)")
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
                           WriteToLog().message(theString: "[processItems] no advanced computer searches - call \(nextObject)")
                           DispatchQueue.main.async {
                               self.processItems(type: nextObject)
                           }
                       }
                   }
                } else {
                    // skip restrictedsoftware
                    WriteToLog().message(theString: "[processItems] skipping advanced computer searches, calling - \(nextObject)")
                    DispatchQueue.main.async {
                        self.processItems(type: nextObject)
                    }
                }
                
            case "advancedmobiledevicesearches":
                WriteToLog().message(theString: "[processItems] \(type)")
                let nextObject = "policies"
                if self.mobileDeviceGroupsButtonState == "on" || self.mobileDeviceEAsButtonState == "on" {
                   DispatchQueue.main.async {
                          self.process_TextField.stringValue = "Fetching Advanced Mobile Device Searches..."
                   }

    //                   self.masterObjectDict[type] = [String:[String:String]]()
                   var advancedsearchArray = [[String:Any]]()
                   
                    self.xmlAction(action: "GET", theServer: self.currentServer, base64Creds: self.jamfBase64Creds, theEndpoint: type) {
                       (result: (Int,String)) in
                       let (statusCode,returnedXml) = result
       //                                    print("[processItems] restrictedsoftware GET statusCode: \(statusCode)")
       //                                    print("[processItems] restrictedsoftware GET xml: \(returnedXml)")
                       var nameFixedXml  = returnedXml.replacingOccurrences(of: "<name>", with: "<Name>")
                       nameFixedXml      = nameFixedXml.replacingOccurrences(of: "</name>", with: "</Name>")
                       let xmlData       = nameFixedXml.data(using: .utf8)
                       let parsedXmlData = XML.parse(xmlData!)

                       for amds in parsedXmlData.advanced_mobile_device_searches.advanced_mobile_device_search {
                           if let id = amds.id.text, let name = amds.Name.text {

    //                               print("restricted software title id: \(acsPolicy.id.text!) \t name: \(acsPolicy.Name.text!)")
                               WriteToLog().message(theString: "advanced mobile device search title id: \(id) \t name: \(name)")
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
                        
                           WriteToLog().message(theString: "[processItems] call recursiveLookup for \(type)")
                           self.recursiveLookup(theServer: self.currentServer, base64Creds: self.jamfBase64Creds, theEndpoint: type, theData: advancedsearchArray, index: 0)
                           waitFor.advancedsearch = true
                           self.backgroundQ.async {
                               while true {
                                   usleep(10)
                                   if !waitFor.advancedsearch {
                                       WriteToLog().message(theString: "[processItems] advanced mobile device searches complete - call \(nextObject)")
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
                           WriteToLog().message(theString: "[processItems] no advanced mobile device searches - call \(nextObject)")
                           DispatchQueue.main.async {
                               self.processItems(type: nextObject)
                           }
                       }
                   }
                } else {
                    // skip restrictedsoftware
                    WriteToLog().message(theString: "[processItems] skipping advanced mobile device searches, calling - \(nextObject)")
                    DispatchQueue.main.async {
                        self.processItems(type: nextObject)
                    }
                }
                      
            case "policies":
                if self.policiesButtonState == "on" || self.packagesButtonState == "on" || self.scriptsButtonState == "on" || self.computerGroupsButtonState == "on" {
                    DispatchQueue.main.async {
                        self.process_TextField.stringValue = "Fetching Policies..."
                    }
                    var policiesArray = [[String:Any]]()
                    Json().getRecord(theServer: self.currentServer, base64Creds: self.jamfBase64Creds, theEndpoint: "policies") {
                        (result: [String:AnyObject]) in
            //            print("json returned: \(result)")
                        self.completed = 0
                        let allPoliciesArray = result["policies"] as! [[String: Any]]
                        
                        // mark policies as unused and filter out policies generated with Jamf/Casper Remote - start
                        for thePolicy in allPoliciesArray {
                            if let id = thePolicy["id"], let name = thePolicy["name"] {
                                let policyName = "\(name)"
                                if policyName.range(of:"[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9] at", options: .regularExpression) == nil && policyName != "Update Inventory" && policyName != "" {
                                    policiesArray.append(thePolicy)
                                    // mark the policy as unused
                                    self.masterObjectDict[type]!["\(name) - (\(id))"] = ["id":"\(id)", "used":"false", "enabled":"false"]
                                }
                            }
                        }
                        // mark policies as unused and filter out policies generated with Jamf/Casper Remote - end
                        
                        let policiesArrayCount = policiesArray.count
                        if policiesArrayCount > 0 {
                            // loop through all the policies
                            DispatchQueue.main.async {
                                self.process_TextField.stringValue = "Scanning policies for packages, scripts, computer groups..."
                            }
                        
                            WriteToLog().message(theString: "[processItems] call recursiveLookup for \(type)")
                            self.recursiveLookup(theServer: self.currentServer, base64Creds: self.jamfBase64Creds, theEndpoint: "policies", theData: policiesArray, index: 0)
                            waitFor.policy = true
                            self.backgroundQ.async {
                                while true {
                                    usleep(10)
                                    if !waitFor.policy && !waitFor.osxconfigurationprofile {
                                        WriteToLog().message(theString: "[processItems] policies complete - call unused")
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
                                        if self.policiesButtonState == "on" {
                                            reportItems.append(["policies":self.masterObjectDict["policies"]!])
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
//                                            DispatchQueue.main.async {
                                            self.unused(itemDictionary: reportItems)
//                                            }
                                        
                                        break
                                    }
                                }
                            }
                                
                        } else {
                            // no policies found
                            WriteToLog().message(theString: "[processItems] no policies found or policies not searched")
                            waitFor.policy = false
                            self.backgroundQ.async {
                                while true {
                                    usleep(10)
                                    if !waitFor.policy && !waitFor.osxconfigurationprofile {
                                        WriteToLog().message(theString: "[processItems] policies complete - call unused")
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
                                        if self.policiesButtonState == "on" {
                                            reportItems.append(["policies":self.masterObjectDict["policies"]!])
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
//                                            DispatchQueue.main.async {
                                            self.unused(itemDictionary: reportItems)
//                                            }
                                        
                                        break
                                    }
                                }
                            }   // self.backgroundQ.async - end
                        }
                    }   //         Json().getRecord - policies - end
                } else {
                    // skipped policy check
                    waitFor.policy = false
                    self.backgroundQ.async {
                        while true {
                            usleep(10)
                            if !waitFor.policy && !waitFor.osxconfigurationprofile {
                                WriteToLog().message(theString: "[processItems] policies complete - call unused")
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
                                if self.policiesButtonState == "on" {
                                    reportItems.append(["policies":self.masterObjectDict["policies"]!])
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
//                                    DispatchQueue.main.async {
                                    self.unused(itemDictionary: reportItems)
//                                    }
                                
                                break
                            }
                        }
                    }   // self.backgroundQ.async - end
                }
                // object that have a scope - end
                    
                default:
                    WriteToLog().message(theString: "[default] unknown item, exiting...")
                    DispatchQueue.main.async {
                        NSApplication.shared.terminate(self)
                        self.processItems(type: "initialize")
                }
            }
        }
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
        case "policies":
            objectEndpoint = "policies/id"
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
            WriteToLog().message(theString: "[recursiveLookup] unknown endpoint: [\(theEndpoint)]")
            return
        }
                    
        let theObject = objectArray[index]
        WriteToLog().message(theString: "[recursiveLookup] start parsing \(theObject)")
        if let id = theObject["id"], let name = theObject["name"] {
            WriteToLog().message(theString: "[recursiveLookup] \(index+1) of \(objectArrayCount)\t lookup: name \(name) - id \(id)")
            updateProcessTextfield(currentCount: "\n(\(index+1)/\(objectArrayCount))")

            switch theEndpoint {
                case "patchpolicies", "patchsoftwaretitles":
//                    print("hello \(theEndpoint)")
                    // lookup patch software titles, loop through each by id
                    
                        // lookup complete record, XML format
//                        Xml().action(action: "GET", theServer: self.currentServer, base64Creds: self.jamfBase64Creds, theEndpoint: "patchpolicies/id/\(id)") {
                    // search for used packages using patchsoftwaretitles endpoint
                    self.xmlAction(action: "GET", theServer: self.currentServer, base64Creds: self.jamfBase64Creds, theEndpoint: "\(objectEndpoint)/\(id)") {
                            (xmlResult: (Int,String)) in
                            let (statusCode, returnedXml) = xmlResult
//                            print("[returnedXml] full XML: \(returnedXml)")
//                            print("statusCode: \(statusCode)")
                            if statusCode >= 200 && statusCode < 300 {
                                let patchPolicyXml = self.nameFixedXml(originalXml: returnedXml)
    //                            print("[patchpolicy] returnedXml: \(patchPolicyXml)")

        
                                let xmlData = patchPolicyXml.data(using: .utf8)
                                let parsedXmlData = XML.parse(xmlData!)
                                
                                if "\(theEndpoint)" == "patchsoftwaretitles" {
                                    // check of used packages - start
                                    let packageVersionArray = parsedXmlData.patch_software_title.versions.version
//                                    print("[patchPolicy] package name: \(packageVersionArray)")
                                    
                                    
                                    for thePackageInfo in packageVersionArray {
                                        if thePackageInfo.package.Name.text != nil {
//                                            print("thePackageInfo.package.Name.text: \(thePackageInfo.package.Name.text!)")
                                            self.masterObjectDict["packages"]!["\(thePackageInfo.package.Name.text!)"]?["used"] = "true"
                                        }

                                    }
                                    // check of used packages - end
                                } else {
                                    // check scoped groups
                                    let patchPolicyScopeArray = parsedXmlData.patch_policy.scope.computer_groups.computer_group
                                    for scopedGroup in patchPolicyScopeArray {
                                        if scopedGroup.Name.text != nil {
    //                                        print("theGroup: \(scopedGroup.Name.text!)")
    //                                        self.computerGroupsDict["\(scopedGroup.Name.text!)"]?["used"] = "true"
                                            self.masterObjectDict["computerGroups"]!["\(scopedGroup.Name.text!)"] = ["used":"true"]
                                        }
                                    }
                                    // check excluded groups
                                    let patchPolicyExcludeArray = parsedXmlData.patch_policy.scope.exclusions.computer_groups.computer_group
                                    for excludedGroup in patchPolicyExcludeArray {
                                        if excludedGroup.Name.text != nil {
    //                                        print("theExcludedGroup: \(excludedGroup.Name.text!)")
    //                                        self.computerGroupsDict["\(excludedGroup.Name.text!)"]?["used"] = "true"
                                            self.masterObjectDict["computerGroups"]!["\(excludedGroup.Name.text!)"] = ["used":"true"]
                                        }
                                    }
                                }
                            } else {
                                WriteToLog().message(theString: "[recursiveLookup.patch] Nothing returned for server: \(theServer) endpoint: \(theEndpoint)/\(id)")
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
                Json().getRecord(theServer: self.currentServer, base64Creds: self.jamfBase64Creds, theEndpoint: "\(objectEndpoint)/\(id)") { [self]
                        (result: [String:AnyObject]) in
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
//                                            self.masterObjectDict["computerGroups"]!["\(value)"] = ["used":"true"]
                                        case "Mobile Device Group":
                                            self.masterObjectDict["mobileDeviceGroups"]!["\(value)"]?["used"] = "true"
                                        default:
                                            if computerEAsButtonState == "on" {
                                                if self.masterObjectDict["computerextensionattributes"]!["\(name)"] != nil {
                                                    self.masterObjectDict["computerextensionattributes"]!["\(name)"]?["used"] = "true"
                                                }
                                            }
                                            if mobileDeviceEAsButtonState == "on" {
                                                if self.masterObjectDict["mobiledeviceextensionattributes"]!["\(name)"] != nil {
                                                    self.masterObjectDict["mobiledeviceextensionattributes"]!["\(name)"]?["used"] = "true"
                                                }
                                            }
                                            break
                                        }
                                    }
                                }
                                // look for nested device groups, groups used in advanced searches - end
                            
                            
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
            //                                        print("thePackage: \(thePackage)")
                                    let theComputerGroupName = theComputerGroup["name"]
            //                                        let theComputerGroupID = theComputerGroup["id"]
            //                                        print("packages id for policy id: \(id): \(thePackageID!)")
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
                                
                                // check for used computergroups - start
                                let profileScope = theConfigProfile["scope"] as! [String:AnyObject]
            //
                                if self.isScoped(scope: profileScope) {
                                    self.masterObjectDict["osxconfigurationprofiles"]!["\(name)"]!["used"] = "true"
                                }
//                                if let _ = self.masterObjectDict["computerGroups"] {
//                                    // we're ok
//                                } else {
//                                    self.masterObjectDict["computerGroups"] = [String:[String:String]]()
//                                }
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
                                    let policyScriptList = thePolicy["scripts"] as! [[String: Any]]
//                                    print("[scriptCheck] masterObjectDict[\"scripts\"]: \(self.masterObjectDict["scripts"])")
                                    for theScript in policyScriptList {
                //                                        print("thePackage: \(thePackage)")
                                        let theScriptName = theScript["name"]
                //                                        print("packages id for policy id: \(id): \(thePackageID!)")
                                        self.masterObjectDict["scripts"]!["\(theScriptName!)"]?["used"] = "true"
//                                        self.scriptsDict["\(theScriptName!)"]?["used"] = "true"
                                    }
                                    // check of used scripts - end
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
                                WriteToLog().message(theString: "[recursiveLookup] check usage for \(theEndpoint)")
                                
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
                                WriteToLog().message(theString: "[recursiveLookup] check usage for \(theEndpoint)")
                                
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
                                     WriteToLog().message(theString: "[recursiveLookup] check usage for \(theEndpoint)")
                                     
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
                                WriteToLog().message(theString: "[recursiveLookup] unknown endpoint: \(theEndpoint)")
                            }
                        } else {
                            WriteToLog().message(theString: "[recursiveLookup] Nothing returned for server: \(theServer) endpoint: \(theEndpoint)/\(id)")
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
                            case "policies","patchpolicies","patchsoftwaretitles","restrictedsoftware":
                                waitFor.policy = false
                            case "mobiledeviceapplications", "mobiledeviceconfigurationprofiles":
                                waitFor.mobiledeviceobject = false
                            default:
                                WriteToLog().message(theString: "[index == objectArrayCount-1] unknown endpoint: \(theEndpoint)")
                            }
                        } else {
                            // check the next item
                            self.recursiveLookup(theServer: theServer, base64Creds: base64Creds, theEndpoint: theEndpoint, theData: theData, index: index+1)
                        }
                    }   //Json().getRecord - end
            }
            
        } else {   // if let id = theObject["id"], let name = theObject["name"] - end
            WriteToLog().message(theString: "[recursiveLookup] unable to identify id and/or name of object")
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
                case "policies","patchpolicies","patchsoftwaretitles","restrictedsoftware":
                    waitFor.policy = false
                case "mobiledeviceapplications", "mobiledeviceconfigurationprofiles":
                    waitFor.mobiledeviceobject = false
                default:
                    WriteToLog().message(theString: "[index == objectArrayCount-1] unknown endpoint: \(theEndpoint)")
                }
            } else {
                // check the next item
                self.recursiveLookup(theServer: theServer, base64Creds: base64Creds, theEndpoint: theEndpoint, theData: theData, index: index+1)
            }
        }
    }

    func unused(itemDictionary: [[String:Any]]) {
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
                        if newDict["\(key)"]?["used"] == "false" {
                            if type == "policies" {
                                if newDict["\(key)"]?["enabled"] == "false" {
                                    sortedArray.append("\(key)    [disabled]")
                                } else {
                                    sortedArray.append("\(key)")
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
    //                print("unusedItems_TableArray: \(String(describing: unusedItems_TableArray))")
//                    DispatchQueue.main.async { [self] in
                        object_TableView.reloadData()
        //                displayUnused(key: type, theList: sortedArray)
                        unusedCount = 0
                        sortedArray.removeAll()
//                    }
                }
            }
//            DispatchQueue.main.async { [self] in
                view_PopUpButton.isEnabled = true
                working(isWorking: false)
                self.process_TextField.isHidden = true
//            }
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
//        WriteToLog().message(theString: "[processItems] scripts complete - call \(nextItem)")
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
        case "unusedPolicies":
            category = "policies"
        case "unusedRestrictedsoftware":
            category = "restrictedsoftware"
        case "unusedMobileDeviceGroups":
            category = "mobileDeviceGroups"
        case "unusedMobileDeviceApps":
            category = "mobiledeviceapplications"
        case "unusedMobileDeviceConfigurationProfiles":
            category = "mobiledeviceconfigurationprofiles"
        default:
            category = type
        }
        
        self.masterObjectDict["\(category)"] = [String:[String:String]]()
        
        if let listOfUnused = data[type] {
            for theDict in listOfUnused as! [[String:String]] {
                
                // change theDict["name"] for disabled policies
                
                if type != "unusedComputerGroups" && type != "unusedMobileDeviceGroups" {
                    print("theDict[\"name\"]: \(String(describing: theDict["name"]!))")
                    let theName = (type == "unusedPolicies") ? theDict["name"]!.replacingOccurrences(of: ")    [disabled]", with: ")"):theDict["name"]!
                    print("theName: \(String(describing: theName))\n")
                    unusedItemsDictionary[theDict["name"]!] = ["id":theDict["id"]!,"used":"false"]
                    masterObjectDict["\(category)"]![theName] = ["id":theDict["id"]!, "used":"false"]
//                    unusedItemsDictionary[theDict["name"]!] = ["id":theDict["id"]!,"used":"false"]
//                    masterObjectDict["\(category)"]![theDict["name"]!] = ["id":theDict["id"]!, "used":"false"]
                    // self.masterObjectDict["scripts"]!["\(name)"] = ["id":"\(id)", "used":"false"]
                } else {
                    unusedItemsDictionary[theDict["name"]!] = ["id":theDict["id"]!,"used":"false","groupType":theDict["groupType"]]
                    masterObjectDict["\(category)"]![theDict["name"]!] = ["id":theDict["id"]!,"used":"false"]
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
            reportItems.append(["packages":self.masterObjectDict["packages"]!])
        }
        if sender.title == "Scripts" || (sender.title == "All" && scriptsButtonState == "on") {
            reportItems.append(["scripts":self.masterObjectDict["scripts"]!])
        }
        if sender.title == "eBooks" || (sender.title == "All" && ebooksButtonState == "on") {
            reportItems.append(["ebooks":self.masterObjectDict["ebooks"]!])
        }
        if sender.title == "Classes" || (sender.title == "All" && classesButtonState == "on") {
            reportItems.append(["ebooks":self.masterObjectDict["classes"]!])
        }
        if sender.title == "Computer Groups" || (sender.title == "All" && computerGroupsButtonState == "on") {
            reportItems.append(["computergroups":self.masterObjectDict["computerGroups"]!])
        }
        if sender.title == "Computer Profiles" || (sender.title == "All" && computerProfilesButtonState == "on") {
            reportItems.append(["osxconfigurationprofiles":self.masterObjectDict["osxconfigurationprofiles"]!])
        }
        if sender.title == "Policies" || (sender.title == "All" && policiesButtonState == "on") {
            reportItems.append(["policies":self.masterObjectDict["policies"]!])
        }
        if sender.title == "Restricted Software" || (sender.title == "All" && restrictedSoftwareButtonState == "on") {
            reportItems.append(["restrictedsoftware":self.masterObjectDict["restrictedsoftware"]!])
        }
        if sender.title == "Computer EAs" || (sender.title == "All" && computerEAsButtonState == "on") {
            reportItems.append(["computerextensionattributes":self.masterObjectDict["computerextensionattributes"]!])
        }
        if sender.title == "Mobile Device Groups" || (sender.title == "All" && mobileDeviceGroupsButtonState == "on") {
            reportItems.append(["mobiledevicegroups":self.masterObjectDict["mobileDeviceGroups"]!])
        }
        if sender.title == "Mobile Device Apps" || (sender.title == "All" && mobileDeviceAppsButtonState == "on") {
            reportItems.append(["mobiledeviceapplications":self.masterObjectDict["mobiledeviceapplications"]!])
        }
        if sender.title == "Mobile Device Config. Profiles" || (sender.title == "All" && configurationProfilesButtonState == "on") {
            reportItems.append(["mobiledeviceconfigurationprofiles":self.masterObjectDict["mobiledeviceconfigurationprofiles"]!])
        }
        if sender.title == "Mobile Device EAs" || (sender.title == "All" && mobileDeviceEAsButtonState == "on") {
            reportItems.append(["mobiledeviceextensionattributes":self.masterObjectDict["mobiledeviceextensionattributes"]!])
        }
        self.unused(itemDictionary: reportItems)
    }
    
    @IBAction func import_Action(_ sender: Any) {
                
        if let pathToFile = import_Button.url {
            let objPath: URL!
            if let pathOrDirectory = import_Button.url {
//                print("fileOrPath: \(pathOrDirectory)")
                
                objPath = URL(string: "\(pathOrDirectory)")!
                var isDir : ObjCBool = false

                sleep(1)
                _ = FileManager.default.fileExists(atPath: objPath.path, isDirectory:&isDir)
                do {
                    setAllButtonsState(theState: "off")
                    let dataFile =  try Data(contentsOf:pathToFile, options: .mappedIfSafe)
                    let objectJSON = try JSONSerialization.jsonObject(with: dataFile, options: .mutableLeaves) as? [String:Any]
                    
//                    print("objectJSON: \(String(describing: objectJSON!))")
                    for (key, value) in objectJSON! {
//                        print("key: \(key)")
                        switch key {
                        case "jamfServer":
                            jamfServer_TextField.stringValue = "\(value)"
                            currentServer = "\(value)"
                        case "username":
                            uname_TextField.stringValue = "\(value)"
                        default:
                            unused(itemDictionary: [buildDictionary(type: key, used: "false", data: objectJSON!)])
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
                            case "unusedPolicies":
                                policies_Button.state = NSControl.StateValue(rawValue: 1)
                                policiesButtonState = "on"
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
                        }
                    }

                } catch {
                    WriteToLog().message(theString: "file read error")
                    return
                }
            }
        }
    }
    
    func sortedArrayFromDict(theDict: [String:[String:String]]) -> [String] {
        var sortedArray = [String]()
        for (key, _) in theDict {
            sortedArray.append(key)
        }
        sortedArray = sortedArray.sorted{$0.localizedCaseInsensitiveCompare($1) == .orderedAscending}
        return sortedArray
    }
    
    
    @IBAction func export_Action(_ sender: Any) {
        
        var text = ""
        var exportedItems:[String] = ["Exported Items"]
        let failedExported:[String] = ["Failed Exported Items"]
        let timeStamp = Time().getCurrent()
        let exportQ = DispatchQueue(label: "com.jamf.prune.exportQ", qos: DispatchQoS.background)
        working(isWorking: true)
        let header = "\"jamfServer\": \"\(currentServer)\",\n \"username\": \"\(uname_TextField.stringValue)\""
        exportQ.sync {
            if self.packagesButtonState == "on" {
                var firstPackage = true
                let packageLogFile = "prunePackages_\(timeStamp).json"
//                let packageLogFile = "prunePackages_\(timeStamp).xml"
                let exportURL = getDownloadDirectory().appendingPathComponent(packageLogFile)

                do {
                    try "{\(header),\n \"unusedPackages\":[\n".write(to: exportURL, atomically: true, encoding: .utf8)
//                    try "<unusedPackages>\n".write(to: exportURL, atomically: true, encoding: .utf8)
                    
                    if let packageLogFileOp = try? FileHandle(forUpdating: exportURL) {
                        for key in sortedArrayFromDict(theDict: masterObjectDict["packages"]!) {
                            if masterObjectDict["packages"]![key]?["used"]! == "false" {
                                packageLogFileOp.seekToEndOfFile()
                                if firstPackage {
                                    text = "\t{\"id\": \"\(String(describing: masterObjectDict["packages"]![key]!["id"]!))\", \"name\": \"\(key)\"}"
                                    firstPackage = false
                                } else {
                                    text = ",\n\t{\"id\": \"\(String(describing: masterObjectDict["packages"]![key]!["id"]!))\", \"name\": \"\(key)\"}"
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
                    WriteToLog().message(theString: "failed to write the following: <unusedPackages>")
                }
            }
            
            if self.scriptsButtonState == "on" {
                var firstScript = true
                let scriptLogFile = "pruneScripts_\(timeStamp).json"
//                let scriptLogFile = "pruneScripts_\(timeStamp).xml"
                let exportURL = getDownloadDirectory().appendingPathComponent(scriptLogFile)

                do {
                    try "{\(header),\n \"unusedScripts\":[\n".write(to: exportURL, atomically: true, encoding: .utf8)
//                    try "<unusedScripts>\n".write(to: exportURL, atomically: true, encoding: .utf8)
                    
                    if let scriptLogFileOp = try? FileHandle(forUpdating: exportURL) {
                        for key in sortedArrayFromDict(theDict: masterObjectDict["scripts"]!) {
                            if masterObjectDict["scripts"]![key]?["used"]! == "false" {
                                scriptLogFileOp.seekToEndOfFile()
//                                let text = "\t{\"id\": \"\(String(describing: scriptsDict[key]!["id"]!))\", \"name\": \"\(key)\"},\n"
                                if firstScript {
                                    text = "\t{\"id\": \"\(String(describing: masterObjectDict["scripts"]![key]!["id"]!))\", \"name\": \"\(key)\"}"
                                    firstScript = false
                                } else {
                                    text = ",\n\t{\"id\": \"\(String(describing: masterObjectDict["scripts"]![key]!["id"]!))\", \"name\": \"\(key)\"}"
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
                    WriteToLog().message(theString: "failed to write the following: <unusedScripts>")
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
//                                let text = "\t{\"id\": \"\(String(describing: ebooksDict[key]!["id"]!))\", \"name\": \"\(key)\"},\n"
                                if firstEbook {
                                    text = "\t{\"id\": \"\(String(describing: masterObjectDict["ebooks"]![key]!["id"]!))\", \"name\": \"\(key)\"}"
                                    firstEbook = false
                                } else {
                                    text = ",\n\t{\"id\": \"\(String(describing: masterObjectDict["ebooks"]![key]!["id"]!))\", \"name\": \"\(key)\"}"
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
                    WriteToLog().message(theString: "failed to write the following: <unusedEbooks>")
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
//                                let text = "\t{\"id\": \"\(String(describing: classesDict[key]!["id"]!))\", \"name\": \"\(key)\"},\n"
                                if firstClass {
                                    text = "\t{\"id\": \"\(String(describing: masterObjectDict["classes"]![key]!["id"]!))\", \"name\": \"\(key)\"}"
                                    firstClass = false
                                } else {
                                    text = ",\n\t{\"id\": \"\(String(describing: masterObjectDict["classes"]![key]!["id"]!))\", \"name\": \"\(key)\"}"
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
                    WriteToLog().message(theString: "failed to write the following: <unusedClasses>")
                }
            }
            
            if self.computerGroupsButtonState == "on" {
                var firstComputerGroup = true
                let computerGroupLogFile = "pruneComputerGroups_\(timeStamp).json"
//                let computerGroupLogFile = "pruneComputerGroups_\(timeStamp).xml"
                let exportURL = getDownloadDirectory().appendingPathComponent(computerGroupLogFile)

                do {
                    try "{\(header),\n \"unusedComputerGroups\":[\n".write(to: exportURL, atomically: true, encoding: .utf8)
//                    try "<unusedComputerGroups>\n".write(to: exportURL, atomically: true, encoding: .utf8)
                    
                    if let computerGroupLogFileOp = try? FileHandle(forUpdating: exportURL) {
                        for key in sortedArrayFromDict(theDict: masterObjectDict["computerGroups"]!) {
    //                    for (key, _) in computerGroupsDict {
                            if masterObjectDict["computerGroups"]![key]?["used"]! == "false" {
                                computerGroupLogFileOp.seekToEndOfFile()
    //                            let text = "\t{\"id\": \"\(String(describing: computerGroupsDict[key]!["id"]!))\", \"name\": \"\(key)\", \"groupType\": \"\(String(describing: computerGroupsDict[key]!["groupType"]!))\"},\n"
                                if firstComputerGroup {
                                    text = "\t{\"id\": \"\(String(describing: masterObjectDict["computerGroups"]![key]!["id"]!))\", \"name\": \"\(key)\", \"groupType\": \"\(String(describing: masterObjectDict["computerGroups"]![key]!["groupType"]!))\"}"
                                    firstComputerGroup = false
                                } else {
                                    text = ",\n\t{\"id\": \"\(String(describing: masterObjectDict["computerGroups"]![key]!["id"]!))\", \"name\": \"\(key)\", \"groupType\": \"\(String(describing: masterObjectDict["computerGroups"]![key]!["groupType"]!))\"}"
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
                    WriteToLog().message(theString: "failed to write the following: <unusedComputerGroups>")
                }
            }   // if self.computerGroupsButtonState == "on" - end
                        
            if self.computerProfilesButtonState == "on" {
                var firstComputerProfile = true
                let ComputerProfileLogFile = "pruneComputerProfiles_\(timeStamp).json"
//                let ComputerProfileLogFile = "pruneComputerProfiles_\(timeStamp).xml"
                let exportURL = getDownloadDirectory().appendingPathComponent(ComputerProfileLogFile)

                do {
                    try "{\(header),\n \"unusedComputerProfiles\":[\n".write(to: exportURL, atomically: true, encoding: .utf8)
//                    try "<unusedComputerProfiles>\n".write(to: exportURL, atomically: true, encoding: .utf8)
                    
                    if let computerProfileLogFileOp = try? FileHandle(forUpdating: exportURL) {
                        for key in sortedArrayFromDict(theDict: masterObjectDict["osxconfigurationprofiles"]!) {
    //                   for (key, _) in masterObjectDict["osxconfigurationprofiles"]! {
                            if masterObjectDict["osxconfigurationprofiles"]![key]?["used"]! == "false" {
                                computerProfileLogFileOp.seekToEndOfFile()
//                                let text = "\t{\"id\": \"\(String(describing: masterObjectDict["osxconfigurationprofiles"]![key]!["id"]!))\", \"name\": \"\(key)\"},\n"
                                if firstComputerProfile {
                                    text = "\t{\"id\": \"\(String(describing: masterObjectDict["osxconfigurationprofiles"]![key]!["id"]!))\", \"name\": \"\(key)\"}"
                                    firstComputerProfile = false
                                } else {
                                    text = ",\n\t{\"id\": \"\(String(describing: masterObjectDict["osxconfigurationprofiles"]![key]!["id"]!))\", \"name\": \"\(key)\"}"
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
                    WriteToLog().message(theString: "failed to write the following: <unusedComputerProfiles>")
                }
            }   // if self.computerGroupsButtonState == "on" - end

            if self.policiesButtonState == "on" {
                var firstPolicy = true
                let policyLogFile = "prunePolicies_\(timeStamp).json"
//                let policyLogFile = "prunePolicies_\(timeStamp).xml"
                let exportURL = getDownloadDirectory().appendingPathComponent(policyLogFile)

                do {
                    try "{\(header),\n \"unusedPolicies\":[\n".write(to: exportURL, atomically: true, encoding: .utf8)
//                    try "<unusedPackages>\n".write(to: exportURL, atomically: true, encoding: .utf8)
                    
                    if let policyLogFileOp = try? FileHandle(forUpdating: exportURL) {
                        for key in sortedArrayFromDict(theDict: masterObjectDict["policies"]!) {
    //                   for (key, _) in policiesDict {
                            if masterObjectDict["policies"]![key]?["used"]! == "false" || masterObjectDict["policies"]![key]?["enabled"]! == "false" {
                                policyLogFileOp.seekToEndOfFile()
//                                let text = "\t{\"id\": \"\(String(describing: policiesDict[key]!["id"]!))\", \"name\": \"\(key)\"},\n"
                                let displayName = (masterObjectDict["policies"]![key]?["enabled"]! == "true") ? key:"\(key)    [disabled]"
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
                    WriteToLog().message(theString: "failed to write the following: <unusedPolicies>")
                }
            }
            
            if self.restrictedSoftwareButtonState == "on" {
                var firstTitle = true
                let rsLogFile = "pruneRestrictedSoftware_\(timeStamp).json"
//                let rsLogFile = "pruneRestrictedSoftware_\(timeStamp).xml"
                let exportURL = getDownloadDirectory().appendingPathComponent(rsLogFile)

                do {
                    try "{\(header),\n \"unusedRestrictedSoftware\":[\n".write(to: exportURL, atomically: true, encoding: .utf8)
//                    try "<unusedRestrictedSoftware>\n".write(to: exportURL, atomically: true, encoding: .utf8)
                    
                    if let logFileOp = try? FileHandle(forUpdating: exportURL) {
                        for key in sortedArrayFromDict(theDict: masterObjectDict["restrictedsoftware"]!) {
    //                   for (key, _) in masterObjectDict["restrictedsoftware"]! {
                            if masterObjectDict["restrictedsoftware"]![key]?["used"]! == "false" {
                                logFileOp.seekToEndOfFile()
//                                let text = "\t{\"id\": \"\(String(describing: masterObjectDict["restrictedsoftware"]![key]!["id"]!))\", \"name\": \"\(key)\"},\n"
                                if firstTitle {
                                    text = "\t{\"id\": \"\(String(describing: masterObjectDict["restrictedsoftware"]![key]!["id"]!))\", \"name\": \"\(key)\"}"
                                    firstTitle = false
                                } else {
                                    text = ",\n\t{\"id\": \"\(String(describing: masterObjectDict["restrictedsoftware"]![key]!["id"]!))\", \"name\": \"\(key)\"}"
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
                    WriteToLog().message(theString: "failed to write the following: <unusedRestrictedSoftware>")
                }
            }
            
            if self.computerEAsButtonState == "on" {
                var firstTitle = true
                let rsLogFile = "pruneComputerEAs_\(timeStamp).json"
//                let rsLogFile = "pruneRestrictedSoftware_\(timeStamp).xml"
                let exportURL = getDownloadDirectory().appendingPathComponent(rsLogFile)

                do {
                    try "{\(header),\n \"unusedComputerEAs\":[\n".write(to: exportURL, atomically: true, encoding: .utf8)
//                    try "<unusedRestrictedSoftware>\n".write(to: exportURL, atomically: true, encoding: .utf8)
                    
                    if let logFileOp = try? FileHandle(forUpdating: exportURL) {
                        for key in sortedArrayFromDict(theDict: masterObjectDict["computerextensionattributes"]!) {
    //                   for (key, _) in masterObjectDict["restrictedsoftware"]! {
                            if masterObjectDict["computerextensionattributes"]![key]?["used"]! == "false" {
                                logFileOp.seekToEndOfFile()
//                                let text = "\t{\"id\": \"\(String(describing: masterObjectDict["restrictedsoftware"]![key]!["id"]!))\", \"name\": \"\(key)\"},\n"
                                if firstTitle {
                                    text = "\t{\"id\": \"\(String(describing: masterObjectDict["computerextensionattributes"]![key]!["id"]!))\", \"name\": \"\(key)\"}"
                                    firstTitle = false
                                } else {
                                    text = ",\n\t{\"id\": \"\(String(describing: masterObjectDict["computerextensionattributes"]![key]!["id"]!))\", \"name\": \"\(key)\"}"
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
                    WriteToLog().message(theString: "failed to write the following: <unusedComputerEAs>")
                }
            }
                        
            if self.mobileDeviceGroupsButtonState == "on" {
                var firstMobileDeviceGrp = true
                let mobileDeviceGroupLogFile = "pruneMobileDeviceGroups_\(timeStamp).json"
//                let mobileDeviceGroupLogFile = "pruneComputerGroups_\(timeStamp).xml"
                let exportURL = getDownloadDirectory().appendingPathComponent(mobileDeviceGroupLogFile)

                do {
                    try "{\(header),\n \"unusedMobileDeviceGroups\":[\n".write(to: exportURL, atomically: true, encoding: .utf8)
//                    try "<unusedMobileDeviceGroups>\n".write(to: exportURL, atomically: true, encoding: .utf8)
                    
                    if let mobileDeviceGroupLogFileOp = try? FileHandle(forUpdating: exportURL) {
                        for key in sortedArrayFromDict(theDict: masterObjectDict["mobileDeviceGroups"]!) {
    //                   for (key, _) in mobileDeviceGroupsDict {
                            if masterObjectDict["mobileDeviceGroups"]![key]?["used"]! == "false" {
                                mobileDeviceGroupLogFileOp.seekToEndOfFile()
//                                let text = "\t{\"id\": \"\(String(describing: mobileDeviceGroupsDict[key]!["id"]!))\", \"name\": \"\(key)\", \"groupType\": \"\(String(describing: mobileDeviceGroupsDict[key]!["groupType"]!))\"},\n"
                                if firstMobileDeviceGrp {
                                    text = "\t{\"id\": \"\(String(describing: masterObjectDict["mobileDeviceGroups"]![key]!["id"]!))\", \"name\": \"\(key)\", \"groupType\": \"\(String(describing: masterObjectDict["mobileDeviceGroups"]![key]!["groupType"]!))\"}"
                                    firstMobileDeviceGrp = false
                                } else {
                                    text = ",\n\t{\"id\": \"\(String(describing: masterObjectDict["mobileDeviceGroups"]![key]!["id"]!))\", \"name\": \"\(key)\", \"groupType\": \"\(String(describing: masterObjectDict["mobileDeviceGroups"]![key]!["groupType"]!))\"}"
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
                    WriteToLog().message(theString: "failed to write the following: <unusedMobileDeviceGroups>")
                }
            }   // if self.mobileDeviceGroupsButtonState == "on" - end
            
            if self.mobileDeviceAppsButtonState == "on" {
                var firstMobileDeviceApp = true
                let logFile = "pruneMobileDeviceApps_\(timeStamp).json"
//                let logFile = "pruneComputerProfiles_\(timeStamp).xml"
                let exportURL = getDownloadDirectory().appendingPathComponent(logFile)

                do {
                    try "{\(header),\n \"unusedMobileDeviceApps\":[\n".write(to: exportURL, atomically: true, encoding: .utf8)
//                    try "<unusedMobileDeviceApps>\n".write(to: exportURL, atomically: true, encoding: .utf8)
                    
                    if let logFileOp = try? FileHandle(forUpdating: exportURL) {
                        for key in sortedArrayFromDict(theDict: masterObjectDict["mobiledeviceapplications"]!) {
    //                   for (key, _) in masterObjectDict["mobiledeviceapplications"]! {
                            if masterObjectDict["mobiledeviceapplications"]![key]?["used"]! == "false" {
                                logFileOp.seekToEndOfFile()
//                                let text = "\t{\"id\": \"\(String(describing: masterObjectDict["mobiledeviceapplications"]![key]!["id"]!))\", \"name\": \"\(key)\"},\n"
                                if firstMobileDeviceApp {
                                    text = "\t{\"id\": \"\(String(describing: masterObjectDict["mobiledeviceapplications"]![key]!["id"]!))\", \"name\": \"\(key)\"}"
                                    firstMobileDeviceApp = false
                                } else {
                                    text = ",\n\t{\"id\": \"\(String(describing: masterObjectDict["mobiledeviceapplications"]![key]!["id"]!))\", \"name\": \"\(key)\"}"
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
                    WriteToLog().message(theString: "failed to write the following: <unusedMobileDeviceApps>")
                }
            }   // if self.mobileDeviceAppsButtonState == "on" - end
                        
            if self.configurationProfilesButtonState == "on" {
                var firstConfigurationProfile = true
                let logFile = "pruneMobileDeviceConfigurationProfiles_\(timeStamp).json"
//                let logFile = "pruneMobileDeviceConfigurationProfiles_\(timeStamp).xml"
                let exportURL = getDownloadDirectory().appendingPathComponent(logFile)

                do {
                    try "{\(header),\n \"unusedMobileDeviceConfigurationProfiles\":[\n".write(to: exportURL, atomically: true, encoding: .utf8)
//                    try "<unusedMobileDeviceConfigurationProfiles>\n".write(to: exportURL, atomically: true, encoding: .utf8)
                    
                    if let logFileOp = try? FileHandle(forUpdating: exportURL) {
                        for key in sortedArrayFromDict(theDict: masterObjectDict["mobiledeviceconfigurationprofiles"]!) {
    //                    for (key, _) in masterObjectDict["mobiledeviceconfigurationprofiles"]! {
                            if masterObjectDict["mobiledeviceconfigurationprofiles"]![key]?["used"]! == "false" {
                                logFileOp.seekToEndOfFile()
//                                let text = "\t{\"id\": \"\(String(describing: masterObjectDict["mobiledeviceconfigurationprofiles"]![key]!["id"]!))\", \"name\": \"\(key)\"},\n"
                                if firstConfigurationProfile {
                                    text = "\t{\"id\": \"\(String(describing: masterObjectDict["mobiledeviceconfigurationprofiles"]![key]!["id"]!))\", \"name\": \"\(key)\"}"
                                    firstConfigurationProfile = false
                                } else {
                                    text = ",\n\t{\"id\": \"\(String(describing: masterObjectDict["mobiledeviceconfigurationprofiles"]![key]!["id"]!))\", \"name\": \"\(key)\"}"
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
                    WriteToLog().message(theString: "failed to write the following: <unusedMobileDeviceConfigurationProfiles>")
                }
            }   // if self.configurationProfilesButtonState == "on" - end
            
            if self.mobileDeviceEAsButtonState == "on" {
                var firstTitle = true
                let rsLogFile = "pruneMobileDeviceEAs_\(timeStamp).json"
//                let rsLogFile = "pruneRestrictedSoftware_\(timeStamp).xml"
                let exportURL = getDownloadDirectory().appendingPathComponent(rsLogFile)

                do {
                    try "{\(header),\n \"unusedMobileDeviceEAs\":[\n".write(to: exportURL, atomically: true, encoding: .utf8)
//                    try "<unusedRestrictedSoftware>\n".write(to: exportURL, atomically: true, encoding: .utf8)
                    
                    if let logFileOp = try? FileHandle(forUpdating: exportURL) {
                        for key in sortedArrayFromDict(theDict: masterObjectDict["mobiledeviceextensionattributes"]!) {
    //                   for (key, _) in masterObjectDict["restrictedsoftware"]! {
                            if masterObjectDict["mobiledeviceextensionattributes"]![key]?["used"]! == "false" {
                                logFileOp.seekToEndOfFile()
//                                let text = "\t{\"id\": \"\(String(describing: masterObjectDict["restrictedsoftware"]![key]!["id"]!))\", \"name\": \"\(key)\"},\n"
                                if firstTitle {
                                    text = "\t{\"id\": \"\(String(describing: masterObjectDict["mobiledeviceextensionattributes"]![key]!["id"]!))\", \"name\": \"\(key)\"}"
                                    firstTitle = false
                                } else {
                                    text = ",\n\t{\"id\": \"\(String(describing: masterObjectDict["mobiledeviceextensionattributes"]![key]!["id"]!))\", \"name\": \"\(key)\"}"
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
                    WriteToLog().message(theString: "failed to write the following: <unusedMobileDeviceEAs>")
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
                Alert().summary(header: "Export Summary", message: exportSummary)
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
                                WriteToLog().message(theString: "[removeObject_Action]      itemDict: \(itemName) and type \(objectType)")
                                WriteToLog().message(theString: "[removeObject_Action] withOptionKey: \(withOptionKey)")
                                
                                switch objectType {
                                    case "packages":
                                        if withOptionKey {
                                            self.masterObjectDict["packages"]!.removeValue(forKey: itemName)
                                        } else {
                                            WriteToLog().message(theString: "[removeObject_Action] single click \(objectType) - without option key")
                                            return
                                        }
                                    
                                    case "scripts":
                                        if withOptionKey {
                                            self.masterObjectDict["scripts"]!.removeValue(forKey: itemName)
                                        } else {
                                            WriteToLog().message(theString: "[removeObject_Action] single click \(objectType) - without option key")
                                            return
                                        }
                                        
                                    case "ebooks":
                                        if withOptionKey {
                                            self.masterObjectDict["ebooks"]!.removeValue(forKey: itemName)
                                        } else {
                                            WriteToLog().message(theString: "[removeObject_Action] single click \(objectType) - without option key")
                                            return
                                        }
                                        
                                    case "classes":
                                        if withOptionKey {
                                            self.masterObjectDict["classes"]!.removeValue(forKey: itemName)
                                        } else {
                                            WriteToLog().message(theString: "[removeObject_Action] single click \(objectType) - without option key")
                                            return
                                        }
                                    
                                    case "computergroups":
                                        if withOptionKey {
                                          self.masterObjectDict["computerGroups"]!.removeValue(forKey: itemName)
                                        } else {
                                          WriteToLog().message(theString: "[removeObject_Action] single click \(objectType) - without option key")
                                          return
                                        }
                                    
                                    case "osxconfigurationprofiles":
                                        if withOptionKey {
                                          self.masterObjectDict["osxconfigurationprofiles"]?.removeValue(forKey: itemName)
                                        } else {
                                          WriteToLog().message(theString: "[removeObject_Action] single click \(objectType) - without option key")
                                          return
                                        }
                                    
                                    case "policies":
                                        if withOptionKey {
                                            self.masterObjectDict["policies"]?.removeValue(forKey: itemName.replacingOccurrences(of: ")    [disabled]", with: ")"))
                                        } else {
                                            WriteToLog().message(theString: "[removeObject_Action] single click \(objectType) - without option key")
                                            return
                                        }
                                    
                                    case "restrictedsoftware":
                                        if withOptionKey {
                                            self.masterObjectDict["restrictedsoftware"]?.removeValue(forKey: itemName)
                                        } else {
                                            WriteToLog().message(theString: "[removeObject_Action] single click \(objectType) - without option key")
                                            return
                                        }
                                    
                                    case "computerextensionattributes":
                                        if withOptionKey {
                                            self.masterObjectDict["computerextensionattributes"]?.removeValue(forKey: itemName)
                                        } else {
                                            WriteToLog().message(theString: "[removeObject_Action] single click \(objectType) - without option key")
                                            return
                                        }

                                    case "mobiledevicegroups":
                                        if withOptionKey {
                                            self.masterObjectDict["mobileDeviceGroups"]!.removeValue(forKey: itemName)
                                        } else {
                                            WriteToLog().message(theString: "[removeObject_Action] single click \(objectType) - without option key")
                                            return
                                        }

                                    case "mobiledeviceapplications":
                                        if withOptionKey {
                                            self.masterObjectDict["mobiledeviceapplications"]?.removeValue(forKey: itemName)
                                        } else {
                                            WriteToLog().message(theString: "[removeObject_Action] single click \(objectType) - without option key")
                                            return
                                        }
                                    
                                    case "mobiledeviceconfigurationprofiles":
                                        if withOptionKey {
                                            self.masterObjectDict[objectType]?.removeValue(forKey: itemName)
                                        } else {
                                            WriteToLog().message(theString: "[removeObject_Action] single click \(objectType) - without option key")
                                            return
                                        }
                                    
                                case "mobiledeviceextensionattributes":
                                    if withOptionKey {
                                        self.masterObjectDict["mobiledeviceextensionattributes"]?.removeValue(forKey: itemName)
                                    } else {
                                        WriteToLog().message(theString: "[removeObject_Action] single click \(objectType) - without option key")
                                        return
                                    }

                                    default:
                                        WriteToLog().message(theString: "[removeObject_Action] unknown objectType: \(String(describing: self.removeObject_Action))")
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
        
        currentServer       = jamfServer_TextField.stringValue.replacingOccurrences(of: "?failover", with: "")
        jamfCreds           = "\(uname_TextField.stringValue):\(passwd_TextField.stringValue)"
        let jamfUtf8Creds   = jamfCreds.data(using: String.Encoding.utf8)
        jamfBase64Creds     = (jamfUtf8Creds?.base64EncodedString())!
        
        theDeleteQ.maxConcurrentOperationCount = 4
        
        let viewing = view_PopUpButton.title
        
        var masterItemsToDeleteArray = [[String:String]]()
        if (viewing == "All" && packages_Button.state.rawValue == 1) || viewing == "Packages" {
            for (key, _) in masterObjectDict["packages"]! {
                if masterObjectDict["packages"]![key]?["used"] == "false" {
                    let id = "\(String(describing: masterObjectDict["packages"]![key]!["id"]!))"
                    WriteToLog().message(theString: "[remove_Action] remove package with id: \(key)")
                    masterItemsToDeleteArray.append(["packages":id])
                }
            }
        }

//        if (viewing == "All" && scriptsButtonState == "on") || viewing == "Scripts" {
        if (viewing == "All" && scripts_Button.state.rawValue == 1) || viewing == "Scripts" {
            for (key, _) in masterObjectDict["scripts"]! {
                if masterObjectDict["scripts"]![key]?["used"] == "false" {
                    let id = "\(String(describing: masterObjectDict["scripts"]![key]!["id"]!))"
                    WriteToLog().message(theString: "[remove_Action] remove script with id: \(id)")
                    masterItemsToDeleteArray.append(["scripts":id])
                }
            }
        }

        if (viewing == "All" && computerGroups_Button.state.rawValue == 1) || viewing == "Computer Groups" {
            for (key, _) in masterObjectDict["computerGroups"]! {
                if masterObjectDict["computerGroups"]![key]?["used"] == "false" {
                    let id = "\(String(describing: masterObjectDict["computerGroups"]![key]!["id"]!))"
                    WriteToLog().message(theString: "[remove_Action] remove computer group with id: \(id)")
                    masterItemsToDeleteArray.append(["computergroups":id])
                }
            }
        }

        if (viewing == "All" && computerProfiles_Button.state.rawValue == 1) || viewing == "Configuration Policies" {
            for (key, _) in masterObjectDict["osxconfigurationprofiles"]! {
                if masterObjectDict["osxconfigurationprofiles"]?[key]?["used"] == "false" {
                    let id = "\(String(describing: masterObjectDict["osxconfigurationprofiles"]![key]!["id"]!))"
                    WriteToLog().message(theString: "[remove_Action] remove computer configuration profile with id: \(id)")
                    masterItemsToDeleteArray.append(["osxconfigurationprofiles":id])
                }
            }
        }
        
        if (viewing == "All" && ebooks_Button.state.rawValue == 1) || viewing == "eBooks" {
            for (key, _) in masterObjectDict["ebooks"]! {
                if masterObjectDict["ebooks"]?[key]?["used"] == "false" {
                    let id = "\(String(describing: masterObjectDict["ebooks"]![key]!["id"]!))"
                    WriteToLog().message(theString: "[remove_Action] remove eBook with id: \(key)")
                    masterItemsToDeleteArray.append(["ebooks":id])
                }
            }
        }

        if (viewing == "All" && policies_Button.state.rawValue == 1) || viewing == "Policies" {
            for (key, _) in masterObjectDict["policies"]! {
                if masterObjectDict["policies"]?[key]?["used"] == "false" {
                    let id = "\(String(describing: masterObjectDict["policies"]![key]!["id"]!))"
                    WriteToLog().message(theString: "[remove_Action] remove policy with id: \(id)")
                    masterItemsToDeleteArray.append(["policies":id])
                }
            }
        }
        
        if (viewing == "All" && restrictedSoftware_Button.state.rawValue == 1) || viewing == "Restricted Software" {
            for (key, _) in masterObjectDict["restrictedsoftware"]! {
                if masterObjectDict["restrictedsoftware"]?[key]?["used"] == "false" {
                    let id = "\(String(describing: masterObjectDict["restrictedsoftware"]![key]!["id"]!))"
                    WriteToLog().message(theString: "[remove_Action] remove restricted software with id: \(id)")
                    masterItemsToDeleteArray.append(["restrictedsoftware":id])
                }
            }
        }

        if (viewing == "All" && mobileDeviceGroups_Button.state.rawValue == 1) || viewing == "Mobile Device Groups" {
            for (key, _) in masterObjectDict["mobileDeviceGroups"]! {
                if masterObjectDict["mobileDeviceGroups"]?[key]?["used"] == "false" {
                    let id = "\(String(describing: masterObjectDict["mobileDeviceGroups"]![key]!["id"]!))"
                    WriteToLog().message(theString: "[remove_Action] remove mobile device group with id: \(id)")
                    masterItemsToDeleteArray.append(["mobiledevicegroups":id])
                }
            }
        }

        if (viewing == "All" && mobileDeviceApps_Button.state.rawValue == 1) || viewing == "Mobile Device Apps" {
            for (key, _) in masterObjectDict["mobiledeviceapplications"]! {
                if masterObjectDict["mobiledeviceapplications"]?[key]?["used"] == "false" {
                    let id = "\(String(describing: masterObjectDict["mobiledeviceapplications"]![key]!["id"]!))"
                    WriteToLog().message(theString: "[remove_Action] remove mobile device application with id: \(id)")
                    masterItemsToDeleteArray.append(["mobiledeviceapplications":id])
                }
            }
        }

        if (viewing == "All" && configurationProfiles_Button.state.rawValue == 1) || viewing == "Mobile Device Config. Profiles" {
            for (key, _) in masterObjectDict["mobiledeviceconfigurationprofiles"]! {
                if masterObjectDict["mobiledeviceconfigurationprofiles"]?[key]?["used"] == "false" {
                    let id = "\(String(describing: masterObjectDict["mobiledeviceconfigurationprofiles"]![key]!["id"]!))"
                    WriteToLog().message(theString: "[remove_Action] remove mobile device configuration profile with id: \(id)")
                    masterItemsToDeleteArray.append(["mobiledeviceconfigurationprofiles":id])
                }
            }
        }
        
        if (viewing == "All" && classes_Button.state.rawValue == 1) || viewing == "Classes" {
            for (key, _) in masterObjectDict["classes"]! {
                if masterObjectDict["classes"]?[key]?["used"] == "false" {
                    let id = "\(String(describing: masterObjectDict["classes"]![key]!["id"]!))"
                    WriteToLog().message(theString: "[remove_Action] remove class with id: \(id)")
                    masterItemsToDeleteArray.append(["classes":id])
                }
            }
        }
        
//        print("masterItemsToDeleteArray: \(masterItemsToDeleteArray)")

        // alert the user before deleting
        let continueDelete = Alert().warning(header: "Caution:", message: "You are about to remove \(masterItemsToDeleteArray.count) objects, are you sure you want to continue?")

        if continueDelete == "OK" {
            theDeleteQ.addOperation {
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
                        self.xmlAction(action: "DELETE", theServer: self.currentServer, base64Creds: self.jamfBase64Creds, theEndpoint: "\(category)/id/\(id)") {
                            (xmlResult: (Int,String)) in
//
                            let (statusCode, _) = xmlResult
                            if !(statusCode >= 200 && statusCode <= 299) {
                                if "\(statusCode)" == "401" {
                                    self.working(isWorking: false)
                                    Alert().display(header: "Alert", message: "Verify username and password.")
                                    return
                                }
                                failedDeleteCount+=1
                                WriteToLog().message(theString: "[remove_Action] failed to removed category \(category) with id: \(id)")
                            } else {
                                deleteCount+=1
                                WriteToLog().message(theString: "[remove_Action] removed category \(category) with id: \(id)")
                            }
                            self.counter += 1
                            
                            completed = true

        //                        print("json returned packages: \(result)")
                            if self.counter == masterItemsToDeleteArray.count {
                                if failedDeleteCount > 0 {
                                    let item = (failedDeleteCount == 1) ? "item was":"items were"
                                    extraMessage = "\nNote, \(failedDeleteCount) \(item) not deleted."
                                }
                                Alert().display(header: "Removal process complete.\(extraMessage)", message: "")
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
        
        DispatchQueue.main.async { [self] in
            if (import_Button.url?.path.suffix(5) == ".json") {
                import_Button.url = import_Button.url?.deletingLastPathComponent()
                unusedItems_TableArray?.removeAll()
                object_TableView.reloadData()
            }
        }
        
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
            case "Policies":
                policiesButtonState = "\(state)"
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
    
    func xmlAction(action: String, theServer: String, base64Creds: String, theEndpoint: String, completion: @escaping (_ result: (Int,String)) -> Void) {

        let getRecordQ = OperationQueue()   //DispatchQueue(label: "com.jamf.getRecordQ", qos: DispatchQoS.background)
    
        URLCache.shared.removeAllCachedResponses()
        var existingDestUrl = ""
        
        existingDestUrl = "\(theServer)/JSSResource/\(theEndpoint)"
        existingDestUrl = existingDestUrl.replacingOccurrences(of: "//JSSResource", with: "/JSSResource")
        
//        if LogLevel.debug { WriteToLog().message(stringOfText: "[Json.getRecord] Looking up: \(existingDestUrl)\n") }
        WriteToLog().message(theString: "[Xml.\(action.uppercased())] existing endpoints URL: \(existingDestUrl)")
        let destEncodedURL = URL(string: existingDestUrl)
        let xmlRequest     = NSMutableURLRequest(url: destEncodedURL! as URL)
        
        let semaphore = DispatchSemaphore(value: 1)
        getRecordQ.maxConcurrentOperationCount = 4
        getRecordQ.addOperation {
            
            xmlRequest.httpMethod = "\(action.uppercased())"
            let destConf = URLSessionConfiguration.default
                        
            switch JamfProServer.authType {
            case "Basic":
                destConf.httpAdditionalHeaders = ["Authorization" : "Basic \(base64Creds)", "Content-Type" : "text/xml", "Accept" : "text/xml", "User-Agent" : appInfo.userAgentHeader]
            default:
                destConf.httpAdditionalHeaders = ["Authorization" : "Bearer \(JamfProServer.authCreds)", "Content-Type" : "text/xml", "Accept" : "text/xml", "User-Agent" : appInfo.userAgentHeader]
            }
            let destSession = Foundation.URLSession(configuration: destConf, delegate: self, delegateQueue: OperationQueue.main)
            let task = destSession.dataTask(with: xmlRequest as URLRequest, completionHandler: {
                (data, response, error) -> Void in
                destSession.finishTasksAndInvalidate()
                if let httpResponse = response as? HTTPURLResponse {
//                    print("[Xml.action] httpResponse: \(String(describing: httpResponse))")
                    
                    if action == "DELETE" {
                        DispatchQueue.main.async {
                            self.process_TextField.stringValue = "\nProcessed item \(self.counter+1) of \(self.itemsToDelete)"
                            self.spinner_ProgressIndicator.increment(by: 100.0/Double(self.itemsToDelete))
                            if (self.counter+1) == self.itemsToDelete {
                                self.spinner_ProgressIndicator.increment(by: 100.0)
                            }
                        }
                    }
                    
                    if httpResponse.statusCode >= 200 && httpResponse.statusCode <= 299 {
                        do {
                            WriteToLog().message(theString: "[Xml.\(action.uppercased())] successfully retrieved: \(theEndpoint)\n")
                            let returnedXML = String(data: data!, encoding: String.Encoding(rawValue: String.Encoding.utf8.rawValue))!

                            completion((httpResponse.statusCode,returnedXML))
                        }
                    } else {
                        WriteToLog().message(theString: "[Xml.\(action.uppercased())] error HTTP Status Code: \(httpResponse.statusCode)\n")
//                        if action != "DELETE" {
                            completion((httpResponse.statusCode,""))
//                        } else {
//                            completion((httpResponse.statusCode,""))
//                        }
                    }
                } else {
//                    WriteToLog().message(stringOfText: "[Xml.action] error parsing JSON for \(existingDestUrl)\n")
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
    
    func setAllButtonsState(theState: String) {
        let state = (theState == "on") ? 1:0
        
        packages_Button.state = NSControl.StateValue(rawValue: state)
        scripts_Button.state = NSControl.StateValue(rawValue: state)
        ebooks_Button.state = NSControl.StateValue(rawValue: state)
        classes_Button.state = NSControl.StateValue(rawValue: state)
        computerGroups_Button.state = NSControl.StateValue(rawValue: state)
        computerProfiles_Button.state = NSControl.StateValue(rawValue: state)
        policies_Button.state = NSControl.StateValue(rawValue: state)
        restrictedSoftware_Button.state = NSControl.StateValue(rawValue: state)
        computerEAs_Button.state = NSControl.StateValue(rawValue: state)
        mobileDeviceGroups_Button.state = NSControl.StateValue(rawValue: state)
        mobileDeviceApps_Button.state = NSControl.StateValue(rawValue: state)
        configurationProfiles_Button.state = NSControl.StateValue(rawValue: state)
        mobileDeviceEAs_Button.state = NSControl.StateValue(rawValue: state)
        
        if theState == "on" {
            let availableButtons = ["Packages", "Scripts", "eBooks", "Classes", "Computer Groups", "Computer Profiles", "Policies", "Restricted Software", "Computer EAs", "Mobile Device Groups", "Mobile Device Apps", "Mobile Device Config. Profiles", "Mobile Device EAs"]
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
        policiesButtonState              = "\(theState)"
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
            if policiesButtonState == "on" {
                view_PopUpButton.addItem(withTitle: "Policies")
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
        DispatchQueue.main.async {
            let theText = self.process_TextField.stringValue.components(separatedBy: "...")[0]
            self.process_TextField.stringValue = "\(theText)... \(currentCount)"
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
    
    @IBAction func savePassword_Action(_ sender: Any) {
        if savePassword_Button.state.rawValue == 1 {
            self.defaults.set(1, forKey: "passwordButton")
//            print("save password")
        } else {
            self.defaults.set(0, forKey: "passwordButton")
//            print("don't save password")
        }
    }
    
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
    }
    
    @objc func viewSelectObject() {
//        print("doubleClicked Row: \(String(object_TableView.clickedRow))")

        DispatchQueue.main.async {
            let theRow = self.object_TableView.selectedRow

            if let displayedName = self.unusedItems_TableArray?[theRow] {
                let itemName = displayedName.replacingOccurrences(of: ")    [disabled]", with: ")")
//                print("itemName: \(String(itemName))")
                
                if let itemDict = self.unusedItems_TableDict?[theRow] {
                    if (self.itemSeperators.firstIndex(of: itemName) ?? -1) == -1 {
                        for (_, objectType) in itemDict as [String:String] {
                            
                            WriteToLog().message(theString: "[viewSelectObject] open itemDict: \(itemName) of type \(objectType) in browser")
                            
                            switch objectType {
                                case "packages":
                                    if let objectId = self.masterObjectDict["packages"]?[itemName]?["id"], let objectURL = URL(string: "\(self.currentServer)/packages.html?id=\(objectId)&o=r") {
                                        NSWorkspace.shared.open(objectURL)
                                        return
                                    }
                                
                                case "scripts":
                                    if let objectId = self.masterObjectDict["scripts"]?[itemName]?["id"], let objectURL = URL(string: "\(self.currentServer)/view/settings/computer/scripts/\(objectId)") {
                                      NSWorkspace.shared.open(objectURL)
                                        return
                                    }
                                    
                                case "ebooks":
                                    if let objectId = self.masterObjectDict["ebooks"]?[itemName]?["id"], let objectURL = URL(string: "\(self.currentServer)/eBooks.html/?id=\(objectId)") {
                                      NSWorkspace.shared.open(objectURL)
                                        return
                                    }
                                        
                                case "classes":
                                    if let objectId = self.masterObjectDict["classes"]?[itemName]?["id"], let objectURL = URL(string: "\(self.currentServer)/classes.html/?id=\(objectId)") {
                                      NSWorkspace.shared.open(objectURL)
                                        return
                                    }
                                
                                case "computergroups":
                                      if let objectId = self.masterObjectDict["computerGroups"]?[itemName]?["id"], let groupType = self.masterObjectDict["computerGroups"]?[itemName]?["groupType"], let objectURL = URL(string: "\(self.currentServer)/\(groupType)s.html/?id=\(objectId)&o=r") {
                                        NSWorkspace.shared.open(objectURL)
                                          return
                                      }
                                
                                case "osxconfigurationprofiles":
                                      if let objectId = self.masterObjectDict["osxconfigurationprofiles"]?[itemName]?["id"], let objectURL = URL(string: "\(self.currentServer)/OSXConfigurationProfiles.html?id=\(objectId)&o=r") {
                                          NSWorkspace.shared.open(objectURL)
                                          return
                                      }
                                
                                case "policies":
                                    if let objectId = self.masterObjectDict["policies"]?[itemName]?["id"], let objectURL = URL(string: "\(self.currentServer)/policies.html?id=\(objectId)&o=r") {
                                        NSWorkspace.shared.open(objectURL)
                                        return
                                    }
                                
                                case "restrictedsoftware":
                                    if let objectId = self.masterObjectDict["restrictedsoftware"]?[itemName]?["id"], let objectURL = URL(string: "\(self.currentServer)/restrictedSoftware.html?id=\(objectId)&o=r") {
                                        NSWorkspace.shared.open(objectURL)
                                        return
                                    }
                                
                            case "computerextensionattributes":
                                if let objectId = self.masterObjectDict["computerextensionattributes"]?[itemName]?["id"], let objectURL = URL(string: "\(self.currentServer)/computerExtensionAttributes.html?id=\(objectId)&o=r") {
                                    NSWorkspace.shared.open(objectURL)
                                    return
                                }

                                case "mobiledevicegroups":
                                    if let objectId = self.masterObjectDict["mobileDeviceGroups"]?[itemName]?["id"], let groupType = self.masterObjectDict["mobileDeviceGroups"]?[itemName]?["groupType"], let objectURL = URL(string: "\(self.currentServer)/\(groupType)s.html/?id=\(objectId)&o=r") {
                                        NSWorkspace.shared.open(objectURL)
                                        return
                                    }

                                case "mobiledeviceapplications":
                                    if let objectId = self.masterObjectDict["mobiledeviceapplications"]?[itemName]?["id"], let objectURL = URL(string: "\(self.currentServer)/mobileDeviceApps.html?id=\(objectId)&o=r") {
                                        NSWorkspace.shared.open(objectURL)
                                        return
                                    }
                                
                                case "mobiledeviceconfigurationprofiles":
                                    if let objectId = self.masterObjectDict[objectType]?[itemName]?["id"], let objectURL = URL(string: "\(self.currentServer)/iOSConfigurationProfiles.html?id=\(objectId)&o=r") {
                                        NSWorkspace.shared.open(objectURL)
                                        return
                                    }
                                
                            case "mobiledeviceextensionattributes":
                                if let objectId = self.masterObjectDict["mobiledeviceextensionattributes"]?[itemName]?["id"], let objectURL = URL(string: "\(self.currentServer)/mobileDeviceExtensionAttributes.html?id=\(objectId)&o=r") {
                                    NSWorkspace.shared.open(objectURL)
                                    return
                                }

                                default:
                                    WriteToLog().message(theString: "[viewSelectObject] unknown objectType: \(String(describing: self.removeObject_Action))")
                                    return
                            }
                        }
                    }
                }   //if let itemDict - end
            }   // if let itemName - end
        }   // dispatchQueue.main.async - end
    }   // func viewSelectObject - end
    
    // Delegate Method
    func sendLoginInfo(loginInfo: (String,String,String,Int)) {
        var saveCredsState: Int?
        (jamfServer_TextField.stringValue,uname_TextField.stringValue,passwd_TextField.stringValue,saveCredsState) = loginInfo
        currentServer = jamfServer_TextField.stringValue
        jamfCreds           = "\(uname_TextField.stringValue):\(passwd_TextField.stringValue)"
        let jamfUtf8Creds   = jamfCreds.data(using: String.Encoding.utf8)
        jamfBase64Creds     = (jamfUtf8Creds?.base64EncodedString())!
        
        saveCreds = (saveCredsState == 1) ? true:false
        // check authentication, check version, set auth method - start
        WriteToLog().message(theString: "[ViewController] Running Prune v\(appInfo.version)")
            JamfPro().getToken(serverUrl: currentServer, whichServer: "source", base64creds: jamfBase64Creds) {
                (result: String) in
                if result == "success" {
                    self.jpapiToken = result
                    DispatchQueue.main.async {
                        // save password if checked - start
                    let regexKey = try! NSRegularExpression(pattern: "http(.*?)://", options:.caseInsensitive)
                        if self.saveCreds {
                            let credKey = regexKey.stringByReplacingMatches(in: self.currentServer, options: [], range: NSRange(0..<self.currentServer.utf16.count), withTemplate: "")
                            Credentials2().save(service: "prune - "+credKey, account: self.uname_TextField.stringValue, data: self.passwd_TextField.stringValue)
                        }
                        
                        self.defaults.set(self.currentServer, forKey: "server")
                        self.defaults.set("\(self.uname_TextField.stringValue)", forKey: "username")
                        self.logout = false
                        WriteToLog().message(theString: "[ViewController] successfully authenticated to \(self.currentServer)")
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
    
    override func prepare(for segue: NSStoryboardSegue, sender: Any?) {
        if segue.identifier == "loginView" {
            let loginVC: LoginViewController = segue.destinationController as! LoginViewController
            loginVC.delegate = self
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        object_TableView.delegate     = self
        object_TableView.dataSource   = self
        object_TableView.doubleAction = #selector(viewSelectObject)
        
                
        // configure import button
        import_Button.url          = getDownloadDirectory().appendingPathComponent("/.")
        import_Button.allowedTypes = ["json"]
        
    }

    override func viewDidAppear() {
        super.viewDidAppear()

        if LoginWindow.show {
            performSegue(withIdentifier: "loginView", sender: nil)
            LoginWindow.show = false
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
            return cell
        }
        return nil
    }
    
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping(  URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        completionHandler(.useCredential, URLCredential(trust: challenge.protectionSpace.serverTrust!))
    }
}
