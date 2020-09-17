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

class ViewController: NSViewController {

    
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
    @IBOutlet weak var computerGroups_Button: NSButton!
    @IBOutlet weak var computerProfiles_Button: NSButton!
    @IBOutlet weak var policies_Button: NSButton!
    @IBOutlet weak var mobileDeviceGroups_Button: NSButton!
    @IBOutlet weak var mobileDeviceApps_Button: NSButton!
    @IBOutlet weak var configurationProfiles_Button: NSButton!
    
    @IBOutlet weak var object_TableView: NSTableView!
    
    @IBOutlet weak var spinner_ProgressIndicator: NSProgressIndicator!
    
    @IBOutlet weak var import_Button: NSPathControl!
    
    @IBOutlet weak var process_TextField: NSTextField!
    
    let defaults = UserDefaults.standard
    
    var currentServer   = ""
    var jamfCreds       = ""
    var jamfBase64Creds = ""
    var completed       = 0
    // define master dictionary of items
    // ex. masterObjectDict["packages"] = [[package1Name:["id":id1,"name":name1]],[package2Name:["id":id2,"name":name2]]]
    var masterObjectDict             = [String:[String:[String:String]]]()
    var packagesDict                 = Dictionary<String,Dictionary<String,String>>()    // id, name, used
    var scriptsDict                  = Dictionary<String,Dictionary<String,String>>()    // id, name, used
    var policiesDict                 = [String:[String:String]]()    //:Dictionary<String,String> = [:]
    var computerConfigurationDict    = [String:String]()
    var computerGroupsDict           = Dictionary<String,Dictionary<String,String>>()
    var osxconfigurationprofilesDict = [String:[String:String]]()
    var mobileDeviceGroupsDict       = [String:[String:String]]()
    var mobileDeviceAppsDict         = [String:[String:String]]()
    var allUnused                    = [[String:[String:String]]]() //Dictionary<String,Dictionary<String,String>>()    // currently unused var
    var unusedItems_TableArray: [String]?
    var unusedItems_TableDict: [[String:String]]?
    
    var itemSeperators              = [String]()
    
    var packagesButtonState         = "off"
    var scriptsButtonState          = "off"
    var computerGroupsButtonState   = "off"
    var computerProfilesButtonState = "off"
    var policiesButtonState         = "off"
    var mobileDeviceGrpsButtonState = "off"
    var mobileDeviceAppsButtonState = "off"
    var configurationProfilesButtonState = "off"
    
    let backgroundQ = DispatchQueue(label: "com.jamf.prune.backgroundQ", qos: DispatchQoS.background)
    
    @IBAction func go_action(_ sender: Any) {
        
        working(isWorking: true)
        
        view_PopUpButton.isEnabled = false
        view_PopUpButton.selectItem(at: 0)
        packagesDict.removeAll()
        scriptsDict.removeAll()
        policiesDict.removeAll()
        osxconfigurationprofilesDict.removeAll()
        computerConfigurationDict.removeAll()
        computerGroupsDict.removeAll()
        mobileDeviceGroupsDict.removeAll()
        mobileDeviceAppsDict.removeAll()
        for (key, _) in masterObjectDict {
            masterObjectDict[key]?.removeAll()
        }
        
        unusedItems_TableArray?.removeAll()
        unusedItems_TableDict?.removeAll()
        
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
                    // save password if checked - start
                let regexKey = try! NSRegularExpression(pattern: "http(.*?)://", options:.caseInsensitive)
                    if self.savePassword_Button.state.rawValue == 1 {
                        let credKey = regexKey.stringByReplacingMatches(in: self.currentServer, options: [], range: NSRange(0..<self.currentServer.utf16.count), withTemplate: "")
                        Credentials2().save(service: "prune - "+credKey, account: self.uname_TextField.stringValue, data: self.passwd_TextField.stringValue)
                    }
                    
                    self.defaults.set(self.currentServer, forKey: "server")
                    self.defaults.set("\(self.uname_TextField.stringValue)", forKey: "username")
                    // save password if checked - end
                    if self.savePassword_Button.state.rawValue == 1 {
                        self.defaults.set(self.passwd_TextField.stringValue, forKey: "password")
                    }
                    self.process_TextField.isHidden = false
                    self.process_TextField.stringValue = "Starting lookups..."
                }
                print("[go_action caller] start lookups...")
                if self.computerGroupsButtonState == "on" {
                    self.processItems(type: "computerGroups")
                } else {
                    self.processItems(type: "mobileDeviceGroups")
                }
//                self.processItems(type: "packages")
            } else {
                DispatchQueue.main.async {
                    self.working(isWorking: false)
                }
            }
        }
    }
    
    
    func processItems(type: String) {
        
//        let semaphore = DispatchSemaphore(value: 0)
        theGetQ.maxConcurrentOperationCount = 4
        var groupType = ""

        theGetQ.addOperation {
            switch type {
                case "computerGroups", "mobileDeviceGroups":
                    if self.computerGroupsButtonState == "on" || self.mobileDeviceGrpsButtonState == "on" {
                        DispatchQueue.main.async {
                            self.process_TextField.stringValue = "Fetching Computer Groups..."
                        }
                        let groupEndpoint = (type == "computerGroups") ? "computergroups":"mobiledevicegroups"
                        Json().getRecord(theServer: self.currentServer, base64Creds: self.jamfBase64Creds, theEndpoint: groupEndpoint) {
                            (result: [String:AnyObject]) in
    //                            print("json returned scripts: \(result)")
                            let computerGroupsArray = (type == "computerGroups") ? result["computer_groups"] as! [Dictionary<String, Any>]:result["mobile_device_groups"] as! [Dictionary<String, Any>]
                            let computerGroupsArrayCount = computerGroupsArray.count
                            if computerGroupsArrayCount > 0 {
//                                    var groupType = (type == "computerGroups") ? "smartComputerGroup":"smartMobileDeviceGroup"
                                // loop through all computer groups and mark as unused
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
                                                self.computerGroupsDict["\(name)"] = ["id":"\(id)", "used":"false", "groupType":"\(groupType)"]
                                            }
                                        } else {
                                            if "\(name)" != "All Managed iPads" && "\(name)" != "All Managed iPhones" && "\(name)" != "All Managed iPod touches" {
                                                self.mobileDeviceGroupsDict["\(name)"] = ["id":"\(id)", "used":"false", "groupType":"\(groupType)"]
                                            }
                                        }
                                            
                                    }
                                }   // for i in (0..<computerGroupsArrayCount) - end
                                // look for nested device groups
                                DispatchQueue.main.async {
                                    self.process_TextField.stringValue = "Scanning for nested device groups..."
                                }
                                self.recursiveLookup(theServer: self.currentServer, base64Creds: self.jamfBase64Creds, theEndpoint: groupEndpoint, theData: computerGroupsArray, index: 0)
                                waitFor.deviceGroup = true
                                self.backgroundQ.async {
                                    while true {
                                        usleep(10)
                                        if !waitFor.deviceGroup {
                                            if type == "computerGroups" {
                                                print("[processItems] skipping \(type) - call mobileDeviceGroups")
                                                DispatchQueue.main.async {
                                                    self.processItems(type: "mobileDeviceGroups")
                                                }
                                                
                                            } else {
                                                print("[processItems] skipping \(type) - call packages")
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
                            print("[processItems] skipping \(type) - call mobileDeviceGroups")
                            DispatchQueue.main.async {
                                self.processItems(type: "mobileDeviceGroups")
                            }
                            
                        } else {
                            print("[processItems] skipping \(type) - call packages")
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
        //                    print("json returned packages: \(result)")
                            if let _ = result["packages"] {
                                let packagesArray = result["packages"] as! [Dictionary<String, Any>]
                                let packagesArrayCount = packagesArray.count
                                // loop through all packages and mark as unused
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
                        }
                    } else {
                        print("[processItems] skipping packages - call scripts")
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
                            print("[processItems] scripts complete - call computerConfigurations")
                            DispatchQueue.main.async {
                                self.processItems(type: "computerConfigurations")
                            }
                        }
                    } else {
                        print("[processItems] skipping scripts - call computerConfigurations")
                        DispatchQueue.main.async {
                            self.processItems(type: "computerConfigurations")
                        }
                   }
                               
                // object that have a scope - start
                case "computerConfigurations":
                    if self.packagesButtonState == "on" || self.scriptsButtonState == "on" {
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
                                self.recursiveLookup(theServer: self.currentServer, base64Creds: self.jamfBase64Creds, theEndpoint: "computerconfigurations", theData: computerConfigurationsArray, index: 0)
                                waitFor.computerConfiguration = true
                                self.backgroundQ.async {
                                    while true {
                                        usleep(10)
                                        if !waitFor.computerConfiguration {
                                            print("[processItems] computerConfigurations complete - call osxconfigurationprofiles")
                                            DispatchQueue.main.async {
                                                self.processItems(type: "osxconfigurationprofiles")
                                            }
                                            break
                                        }
                                    }
                                }
                                
                            } else {
                                // no computer configurations exist
                                print("[processItems] no computerConfigurations - call osxconfigurationprofiles")
                                DispatchQueue.main.async {
                                    self.processItems(type: "osxconfigurationprofiles")
                                }
                            }
                        }   //         Json().getRecord - computerConfigurations - end
                    } else {
                        print("[processItems] skipping computerConfigurations - call osxconfigurationprofiles")
                        DispatchQueue.main.async {
                            self.processItems(type: "osxconfigurationprofiles")
                        }
                    }
                                                    
                case "osxconfigurationprofiles":
                    if self.computerGroupsButtonState == "on" || self.computerProfilesButtonState == "on" {
                        DispatchQueue.main.async {
                            self.process_TextField.stringValue = "Fetching Computer Configuration Profiles..."
                        }
                        Json().getRecord(theServer: self.currentServer, base64Creds: self.jamfBase64Creds, theEndpoint: type) {
                            (result: [String:AnyObject]) in
        //                    print("json returned packages: \(result)")
                            self.masterObjectDict["osxconfigurationprofiles"] = [String:[String:String]]()
                            if let _  = result["os_x_configuration_profiles"] {
                                let osxconfigurationprofilesArray = result["os_x_configuration_profiles"] as! [Dictionary<String, Any>]
                                let osxconfigurationprofilesArrayCount = osxconfigurationprofilesArray.count
                                if osxconfigurationprofilesArrayCount > 0 {
                                    for i in (0..<osxconfigurationprofilesArrayCount) {
                                        
                                        if let id = osxconfigurationprofilesArray[i]["id"], let name = osxconfigurationprofilesArray[i]["name"] {
                                            self.masterObjectDict["osxconfigurationprofiles"]!["\(name)"] = ["id":"\(id)", "used":"false"]
                                        }
                                    }

                                    self.recursiveLookup(theServer: self.currentServer, base64Creds: self.jamfBase64Creds, theEndpoint: "osxconfigurationprofiles", theData: osxconfigurationprofilesArray, index: 0)
                                    waitFor.osxconfigurationprofile = true
                                    self.backgroundQ.async {
                                        while true {
                                            usleep(10)
                                            if !waitFor.osxconfigurationprofile {
                                                print("[processItems] osxconfigurationprofiles complete - call mobiledeviceapplications")
                                                if self.mobileDeviceAppsButtonState == "on" || self.mobileDeviceGrpsButtonState == "on" {
                                                    DispatchQueue.main.async {
                                                        self.processItems(type: "mobiledeviceapplications")
                                                    }
                                                } else {
                                                    DispatchQueue.main.async {
                                                        self.processItems(type: "mobiledeviceconfigurationprofiles")
                                                    }
                                                }   // if self.mobileDeviceAppsButtonState == "on" - end
                                                break
                                            }
                                        }
                                    }
                                } else {
                                    // no computer profiles exist
                                    print("[processItems] computer configuration profiles complete - call mobiledeviceapplications")
                                    if self.mobileDeviceAppsButtonState == "on" || self.mobileDeviceGrpsButtonState == "on" {
                                        DispatchQueue.main.async {
                                            self.processItems(type: "mobiledeviceapplications")
                                        }
                                    } else {
                                        DispatchQueue.main.async {
                                            self.processItems(type: "mobiledeviceconfigurationprofiles")
                                        }
                                    }   // if self.mobileDeviceAppsButtonState == "on" - end
                                }

    //                            print("call policies")
    //                            DispatchQueue.main.async {
    //                                self.processItems(type: "policies")
    //                            }
                            } else {
                                print("[processItems] unable to read computer configuration profiles - call mobiledeviceapplications")
                                waitFor.osxconfigurationprofile = false
                                if self.mobileDeviceAppsButtonState == "on" || self.mobileDeviceGrpsButtonState == "on" {
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
                        print("[processItems] skipping computer configuration profiles - call mobiledeviceapplications")
                        waitFor.osxconfigurationprofile = false
                        if self.mobileDeviceAppsButtonState == "on" || self.mobileDeviceGrpsButtonState == "on" {
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
                    var msgText    = "mobile device profiles"
    //                var nextObject = "policies"
                    var nextObject = "patchsoftwaretitles"
                    if (type == "mobiledeviceapplications" && self.mobileDeviceAppsButtonState == "on") || self.mobileDeviceGrpsButtonState == "on" || (type == "mobiledeviceconfigurationprofiles" && self.configurationProfilesButtonState == "on") {
                        var xmlTag = ""
                        DispatchQueue.main.async {
                            if type == "mobiledeviceapplications" || (type == "mobiledeviceapplications" && self.mobileDeviceGrpsButtonState == "on") {
                                xmlTag     = "mobile_device_applications"
                                nextObject = "mobiledeviceconfigurationprofiles"
                                msgText    = "mobile device apps"
                                self.process_TextField.stringValue = "Fetching Mobile Device Apps..."
                            } else {
                                xmlTag = "configuration_profiles"
                                self.process_TextField.stringValue = "Fetching Mobile Device Configuration Profiles..."
                            }
                        }
                        Json().getRecord(theServer: self.currentServer, base64Creds: self.jamfBase64Creds, theEndpoint: type) {
                            (result: [String:AnyObject]) in
        //                    print("json returned packages: \(result)")
                            self.masterObjectDict[type] = [String:[String:String]]()
                            if let _ = result[xmlTag] {
                                let mobileDeviceObjectArray = result[xmlTag] as! [Dictionary<String, Any>]
                                let mobileDeviceObjectArrayCount = mobileDeviceObjectArray.count
                                if mobileDeviceObjectArrayCount > 0 {
                                    for i in (0..<mobileDeviceObjectArrayCount) {
                                        
                                        if let id = mobileDeviceObjectArray[i]["id"], let name = mobileDeviceObjectArray[i]["name"] {
                                            self.masterObjectDict[type]!["\(name)"] = ["id":"\(id)", "used":"false"]
                                        }
                                    }

                                    print("[processItems] call recursiveLookup for \(type)")
                                    self.recursiveLookup(theServer: self.currentServer, base64Creds: self.jamfBase64Creds, theEndpoint: type, theData: mobileDeviceObjectArray, index: 0)
                                    waitFor.mobiledeviceobject = true
                                    self.backgroundQ.async {
                                        while true {
                                            usleep(10)
                                            if !waitFor.mobiledeviceobject {
                                                print("[processItems] \(msgText) complete - next object: \(nextObject)")
                                                DispatchQueue.main.async {
                                                    self.processItems(type: nextObject)
                                                }
                                                break
                                            }
                                        }
                                    }
                                } else {
                                    // no computer configurations exist
                                    print("[processItems] \(msgText) complete - \(nextObject)")
                                    DispatchQueue.main.async {
                                        self.processItems(type: nextObject)
                                    }
                                }
                            } else {
                                print("[processItems] unable to read \(msgText) - \(nextObject)")
                                waitFor.mobiledeviceobject = false
                                DispatchQueue.main.async {
                                    self.processItems(type: nextObject)
                                }
                            }
                        }
                    } else {
                        // skip \(msgText)
                        print("[processItems] skipping \(msgText) - \(nextObject)")
                        waitFor.mobiledeviceobject = false
                        DispatchQueue.main.async {
                            self.processItems(type: nextObject)
                        }
                    }
                                
                case "patchsoftwaretitles":
                    // look for packages used in patch policies
                    print("[processItems] patchpolicies_packages")
            //        let nextObject = "patchsoftwaretitles"
                    let nextObject = "patchpolicies"
//                    if self.computerGroupsButtonState == "on" || self.packagesButtonState == "on" {
                    if self.packagesButtonState == "on" {
            //           var xmlTag = ""
                        DispatchQueue.main.async {
                               self.process_TextField.stringValue = "Fetching Patch Software Titles..."
                        }

                        self.masterObjectDict[type] = [String:[String:String]]()
                        var patchPoliciesArray = [[String:Any]]()
                        
                        Xml().action(action: "GET", theServer: self.currentServer, base64Creds: self.jamfBase64Creds, theEndpoint: "patchsoftwaretitles") {
                            (result: (Int,String)) in
                            let (statusCode,returnedXml) = result
                            print("[patchsoftwaretitles] patchpolicies GET statusCode: \(statusCode)")
                            print("[patchsoftwaretitles] patchpolicies GET xml: \(returnedXml)")
                            var nameFixedXml = returnedXml.replacingOccurrences(of: "<name>", with: "<Name>")
                            nameFixedXml = nameFixedXml.replacingOccurrences(of: "</name>", with: "</Name>")
                            let xmlData = nameFixedXml.data(using: .utf8)
                            let parsedXmlData = XML.parse(xmlData!)

                            for thePolicy in parsedXmlData.patch_software_titles.patch_software_title {
                                if let id = thePolicy.id.text, let name = thePolicy.Name.text {

                                    print("patchPolicy id: \(thePolicy.id.text!) \t name: \(thePolicy.Name.text!)")
                                    patchPoliciesArray.append(["id": "\(thePolicy.id.text!)", "name": "\(thePolicy.Name.text!)"])
                                    // mark patch policies as unused (reporting only) - start
                                    self.masterObjectDict[type]!["\(name)"] = ["id":"\(id)", "used":"false"]
                                    // mark patch policies as unused (reporting only) - end
                                }
                            }

                           /*
                        }
                        Json().getRecord(theServer: self.currentServer, base64Creds: self.jamfBase64Creds, theEndpoint: type) {
                            (result: [String:AnyObject]) in
                            self.masterObjectDict[type] = [String:[String:String]]()
                            //            print("json returned: \(result)")
                            self.completed = 0
                            let patchPoliciesArray = result["patch_policies"] as! [Dictionary<String, Any>]
                            print("patchPoliciesArray: \(patchPoliciesArray)")
                        
                            // mark patch policies as unused - start
                            for thePolicy in patchPoliciesArray {
                                if let id = thePolicy["id"], let name = thePolicy["name"] {
                                    // mark the policy as unused
                                    self.masterObjectDict[type]!["\(name)"] = ["id":"\(id)", "used":"false"]
                                }
                            }
                            // mark patch policies as unused - end
            */
                           let patchPoliciesArrayCount = patchPoliciesArray.count
                           if patchPoliciesArrayCount > 0 {
                               DispatchQueue.main.async {
                                   self.process_TextField.stringValue = "Scanning Patch Policies for packages..."
                               }

                               self.recursiveLookup(theServer: self.currentServer, base64Creds: self.jamfBase64Creds, theEndpoint: type, theData: patchPoliciesArray, index: 0)
                               waitFor.policy = true
                               self.backgroundQ.async {
                                   while true {
                                       usleep(10)
                                       if !waitFor.policy {
                                           print("[processItems] patch policies complete - call patchsoftwaretitles")
                                           DispatchQueue.main.async {
                                               self.processItems(type: nextObject)
                                           }
                                           break
                                       }
                                   }
                               }
                               
                           } else {
                               // no patch policies exist
                               print("[processItems] no patch policies - call patchsoftwaretitles")
                               DispatchQueue.main.async {
                                   self.processItems(type: nextObject)
                               }
                           }
                       }   //         Json().getRecord - patchpolicies - end
                    } else {
                       print("[processItems] skipping patch policies - call patchsoftwaretitles")
                       DispatchQueue.main.async {
                           self.processItems(type: nextObject)
                       }
                    }
                        
                    case "patchpolicies":
                            // look for groups used in patch policies
                            print("[processItems] patchpolicies")
                    //        let nextObject = "patchsoftwaretitles"
                            let nextObject = "policies"
                            if self.computerGroupsButtonState == "on" {
                    //           var xmlTag = ""
                                DispatchQueue.main.async {
                                       self.process_TextField.stringValue = "Fetching Patch Policies..."
                                }

                                self.masterObjectDict[type] = [String:[String:String]]()
                                var patchPoliciesArray = [[String:Any]]()
                                
                                Xml().action(action: "GET", theServer: self.currentServer, base64Creds: self.jamfBase64Creds, theEndpoint: "patchpolicies") {
                                    (result: (Int,String)) in
                                    let (statusCode,returnedXml) = result
                                    print("[processItems] patchpolicies GET statusCode: \(statusCode)")
                                    print("[processItems] patchpolicies GET xml: \(returnedXml)")
                                    var nameFixedXml = returnedXml.replacingOccurrences(of: "<name>", with: "<Name>")
                                    nameFixedXml = nameFixedXml.replacingOccurrences(of: "</name>", with: "</Name>")
                                    let xmlData = nameFixedXml.data(using: .utf8)
                                    let parsedXmlData = XML.parse(xmlData!)

                                    for thePolicy in parsedXmlData.patch_policies.patch_policy {
                                        if let id = thePolicy.id.text, let name = thePolicy.Name.text {

                                            print("patchPolicy id: \(thePolicy.id.text!) \t name: \(thePolicy.Name.text!)")
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

                                       self.recursiveLookup(theServer: self.currentServer, base64Creds: self.jamfBase64Creds, theEndpoint: type, theData: patchPoliciesArray, index: 0)
                                       waitFor.policy = true
                                       self.backgroundQ.async {
                                           while true {
                                               usleep(10)
                                               if !waitFor.policy {
                                                   print("[processItems] patch policies complete - call patchsoftwaretitles")
                                                   DispatchQueue.main.async {
                                                       self.processItems(type: nextObject)
                                                   }
                                                   break
                                               }
                                           }
                                       }
                                       
                                   } else {
                                       // no patch policies exist
                                       print("[processItems] no patch policies - call patchsoftwaretitles")
                                       DispatchQueue.main.async {
                                           self.processItems(type: nextObject)
                                       }
                                   }
                               }   //         Json().getRecord - patchpolicies - end
                            } else {
                               print("[processItems] skipping patch policies - call patchsoftwaretitles")
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
                            let allPoliciesArray = result["policies"] as! [Dictionary<String, Any>]
                            
                            // mark policies as unused and filter out policies generated with Jamf/Casper Remote - start
                            for thePolicy in allPoliciesArray {
                                if let id = thePolicy["id"], let name = thePolicy["name"] {
                                    let policyName = "\(name)"
                                    if policyName.range(of:"[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9] at", options: .regularExpression) == nil && policyName != "Update Inventory" {
                                        policiesArray.append(thePolicy)
                                        // mark the policy as unused
                                        self.policiesDict["\(name) - (\(id))"] = ["id":"\(id)", "used":"false"]
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
        //                        for i in (0..<policiesArrayCount) {

                                    self.recursiveLookup(theServer: self.currentServer, base64Creds: self.jamfBase64Creds, theEndpoint: "policies", theData: policiesArray, index: 0)
                                    waitFor.policy = true
                                    self.backgroundQ.async {
                                        while true {
                                            usleep(10)
                                            if !waitFor.policy && !waitFor.osxconfigurationprofile {
                                                print("[processItems] policies complete - call unused")
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
                                                if self.computerProfilesButtonState == "on" {
                                                    reportItems.append(["osxconfigurationprofiles":self.masterObjectDict["osxconfigurationprofiles"]!])
                                                }
                                                if self.policiesButtonState == "on" {
                                                    reportItems.append(["policies":self.policiesDict])
                                                }
                                                if self.mobileDeviceGrpsButtonState == "on" {
                                                    reportItems.append(["mobiledevicegroups":self.mobileDeviceGroupsDict])
                                                }
                                                if self.mobileDeviceAppsButtonState == "on" {
                                                    reportItems.append(["mobiledeviceapplications":self.masterObjectDict["mobiledeviceapplications"]!])
                                                }
                                                if self.configurationProfilesButtonState == "on" {
                                                    reportItems.append(["mobiledeviceconfigurationprofiles":self.masterObjectDict["mobiledeviceconfigurationprofiles"]!])
                                                }
                                                DispatchQueue.main.async {
                                                    self.unused(itemDictionary: reportItems)
                                                }
                                                
                                                break
                                            }
                                        }
                                    }
                                    
                            } else {
                                // no policies found
                                print("[processItems] no policies found or policies not searched")
                                waitFor.policy = false
                                self.backgroundQ.async {
                                    while true {
                                        usleep(10)
                                        if !waitFor.policy && !waitFor.osxconfigurationprofile {
                                            print("[processItems] policies complete - call unused")
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
                                            if self.computerProfilesButtonState == "on" {
                                                reportItems.append(["osxconfigurationprofiles":self.masterObjectDict["osxconfigurationprofiles"]!])
                                            }
                                            if self.policiesButtonState == "on" {
                                                reportItems.append(["policies":self.policiesDict])
                                            }
                                            if self.mobileDeviceGrpsButtonState == "on" {
                                                reportItems.append(["mobiledevicegroups":self.mobileDeviceGroupsDict])
                                            }
                                            if self.mobileDeviceAppsButtonState == "on" {
                                            reportItems.append(["mobiledeviceapplications":self.masterObjectDict["mobiledeviceapplications"]!])
                                            }
                                            if self.configurationProfilesButtonState == "on" {
                                            reportItems.append(["mobiledeviceconfigurationprofiles":self.masterObjectDict["mobiledeviceconfigurationprofiles"]!])
                                            }
                                            DispatchQueue.main.async {
                                                self.unused(itemDictionary: reportItems)
                                            }
                                            
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
                                    print("[processItems] policies complete - call unused")
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
                                    if self.computerProfilesButtonState == "on" {
                                        reportItems.append(["osxconfigurationprofiles":self.masterObjectDict["osxconfigurationprofiles"]!])
                                    }
                                    if self.policiesButtonState == "on" {
                                        reportItems.append(["policies":self.policiesDict])
                                    }
                                    if self.mobileDeviceGrpsButtonState == "on" {
                                        reportItems.append(["mobiledevicegroups":self.mobileDeviceGroupsDict])
                                    }
                                    if self.mobileDeviceAppsButtonState == "on" {
                                        reportItems.append(["mobiledeviceapplications":self.masterObjectDict["mobiledeviceapplications"]!])
                                    }
                                    if self.configurationProfilesButtonState == "on" {
                                        reportItems.append(["mobiledeviceconfigurationprofiles":self.masterObjectDict["mobiledeviceconfigurationprofiles"]!])
                                    }
                                    DispatchQueue.main.async {
                                        self.unused(itemDictionary: reportItems)
                                    }
                                    
                                    break
                                }
                            }
                        }   // self.backgroundQ.async - end
                    }
                    // object that have a scope - end
                    
                default:
                    print("[default] unknown item, exiting...")
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
        case "computergroups":
            objectEndpoint = "computergroups/id"
        case "computerconfigurations":
            objectEndpoint = "computerconfigurations/id"
        case "osxconfigurationprofiles":
            objectEndpoint = "osxconfigurationprofiles/id"
        case "policies":
            objectEndpoint = "policies/id"
        case "patchpolicies":
            objectEndpoint = "patchpolicies/id"
        case "patchsoftwaretitles":
            objectEndpoint = "patchsoftwaretitles/id"
        case "mobiledevicegroups":
            objectEndpoint = "mobiledevicegroups/id"
        case "mobiledeviceapplications":
            objectEndpoint = "mobiledeviceapplications/id"
        case "mobiledeviceconfigurationprofiles":
            objectEndpoint = "mobiledeviceconfigurationprofiles/id"
        default:
            print("unknown: [\(theEndpoint)]")
            return
        }
                    
        let theObject = objectArray[index]
        if let id = theObject["id"], let name = theObject["name"] {
            print("lookup id \(id) \t \(index+1) of \(objectArrayCount)")
            updateProcessTextfield(currentCount: "\n(\(index+1)/\(objectArrayCount))")

            switch theEndpoint {
                case "patchpolicies", "patchsoftwaretitles":
                    print("hello \(theEndpoint)")
                    // lookup patch software titles, loop through each by id
                    
                        // lookup complete record, XML format
//                        Xml().action(action: "GET", theServer: self.currentServer, base64Creds: self.jamfBase64Creds, theEndpoint: "patchpolicies/id/\(id)") {
                    // search for used packages using patchsoftwaretitles endpoint
                        Xml().action(action: "GET", theServer: self.currentServer, base64Creds: self.jamfBase64Creds, theEndpoint: "\(objectEndpoint)/\(id)") {
                            (xmlResult: (Int,String)) in
                            let (statusCode, returnedXml) = xmlResult
//                            print("[returnedXml] full XML: \(returnedXml)")
                            print("statusCode: \(statusCode)")
                            let patchPolicyXml = self.nameFixedXml(originalXml: returnedXml)
//                            print("[patchpolicy] returnedXml: \(patchPolicyXml)")

    
                            let xmlData = patchPolicyXml.data(using: .utf8)
                            let parsedXmlData = XML.parse(xmlData!)
                            
                            if "\(theEndpoint)" == "patchsoftwaretitles" {
                                // check of used packages - start
                                let packageVersionArray = parsedXmlData.patch_software_title.versions.version
    //                            print("[patchPolicy] package name: \(packageVersionArray)")
                                
                                
                                for thePackageInfo in packageVersionArray {
                                    if thePackageInfo.package.Name.text != nil {
                                        print("thePackageInfo.package.Name.text: \(thePackageInfo.package.Name.text!)")
                                        self.packagesDict["\(thePackageInfo.package.Name.text!)"]?["used"] = "true"
                                    }

                                }
                                // check of used packages - end
                            } else {
                                // check scoped groups
                                let patchPolicyScopeArray = parsedXmlData.patch_policy.scope.computer_groups.computer_group
                                for scopedGroup in patchPolicyScopeArray {
                                    if scopedGroup.Name.text != nil {
                                        print("theGroup: \(scopedGroup.Name.text!)")
//                                        self.computerGroupsDict["\(scopedGroup.Name.text!)"]?["used"] = "true"
                                        self.computerGroupsDict["\(scopedGroup.Name.text!)"] = ["used":"true"]
                                    }
                                }
                                // check excluded groups
                                let patchPolicyExcludeArray = parsedXmlData.patch_policy.scope.exclusions.computer_groups.computer_group
                                for excludedGroup in patchPolicyExcludeArray {
                                    if excludedGroup.Name.text != nil {
                                        print("theExcludedGroup: \(excludedGroup.Name.text!)")
//                                        self.computerGroupsDict["\(excludedGroup.Name.text!)"]?["used"] = "true"
                                        self.computerGroupsDict["\(excludedGroup.Name.text!)"] = ["used":"true"]
                                    }
                                }
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
                    Json().getRecord(theServer: self.currentServer, base64Creds: self.jamfBase64Creds, theEndpoint: "\(objectEndpoint)/\(id)") {
                        (result: [String:AnyObject]) in
                        switch theEndpoint {
                        case "computergroups", "mobiledevicegroups":
                            // look for nested device groups
                            let computerGroupInfo = (theEndpoint == "computergroups") ? result["computer_group"] as! Dictionary<String, AnyObject>:result["mobile_device_group"] as! Dictionary<String, AnyObject>
                            let criterion = computerGroupInfo["criteria"] as! [Dictionary<String, Any>]
                            for theCriteria in criterion {
                                if let name = theCriteria["name"], let value = theCriteria["value"] {
        //                            if (name as! String) == "Computer Group" || (name as! String) == "Mobile Device Group" {
        //                                self.computerGroupsDict["\(value)"] = ["used":"true"]
        //                            }
                                    switch (name as! String) {
                                    case "Computer Group":
                                        self.computerGroupsDict["\(value)"] = ["used":"true"]
                                    case "Mobile Device Group":
                                        self.mobileDeviceGroupsDict["\(value)"] = ["used":"true"]
                                    default:
                                        break
                                    }
                                }
                            }
                            // look for nested device groups - end
                            
                        case "computerconfigurations":
                            // scan each computer configuration - start
                            self.computerConfigurationDict["\(id)"] = "\(name)"
                                
                                if let _ = result["computer_configuration"] {
                                    let theComputerConfiguration = result["computer_configuration"] as! [String:AnyObject]
        //                            let packageList = theComputerConfiguration["packages"] as! [String:AnyObject]
                                    let computerConfigurationPackageList = theComputerConfiguration["packages"] as! [Dictionary<String, Any>]
                                    for thePackage in computerConfigurationPackageList {
        //                                        print("thePackage: \(thePackage)")
                                        let thePackageName = thePackage["name"]
        //                                        print("packages id for policy id: \(id): \(thePackageID!)")
                                        self.packagesDict["\(thePackageName!)"]?["used"] = "true"
                                    }

                                    let computerConfigurationScriptList = theComputerConfiguration["scripts"] as! [Dictionary<String, Any>]
                                    for theScript in computerConfigurationScriptList {
        //                                        print("thePackage: \(thePackage)")
                                        let theScriptName = theScript["name"]
        //                                        print("packages id for policy id: \(id): \(thePackageID!)")
                                        self.scriptsDict["\(theScriptName!)"]?["used"] = "true"
                                    }
        //                                    print("packages for policy id: \(id): \(packageList)")
                                }
                            // scan each computer configuration - end
                            
                        case "osxconfigurationprofiles":
                            self.masterObjectDict["osxconfigurationprofiles"]!["\(name)"] = ["id":"\(id)", "used":"false"]
                            self.osxconfigurationprofilesDict["\(name)"] = ["id":"\(id)", "used":"false"]
                            // look up each computer profile and check scope/limitations - start
                                                                            
                            let theConfigProfile = result["os_x_configuration_profile"] as! [String:AnyObject]
                            
                            // check for used computergroups - start
                            let profileScope = theConfigProfile["scope"] as! [String:AnyObject]
        //
                            if self.isScoped(scope: profileScope) {
                                self.masterObjectDict["osxconfigurationprofiles"]!["\(name)"]!["used"] = "true"
                            }
                            let computer_groupList = profileScope["computer_groups"] as! [Dictionary<String, Any>]
                            for theComputerGroup in computer_groupList {
        //                                        print("thePackage: \(thePackage)")
                                let theComputerGroupName = theComputerGroup["name"]
        //                                        let theComputerGroupID = theComputerGroup["id"]
        //                                        print("packages id for policy id: \(id): \(thePackageID!)")
                                self.computerGroupsDict["\(theComputerGroupName!)"]?["used"] = "true"
                            }
                            // check exclusions - start
                            let computer_groupExcl = profileScope["exclusions"] as! [String:AnyObject]
                            let computer_groupListExcl = computer_groupExcl["computer_groups"] as! [Dictionary<String, Any>]
                            for theComputerGroupExcl in computer_groupListExcl {
        //                                        print("thePackage: \(thePackage)")
                                let theComputerGroupName = theComputerGroupExcl["name"]
        //                                        print("packages id for policy id: \(id): \(thePackageID!)")
                                self.computerGroupsDict["\(theComputerGroupName!)"]?["used"] = "true"
                            }
                            // check exclusions - end
                            // check of used computergroups - end
                            
                            // look up each computer profile and check scope/limitations - end
                            
                        case "policies":
        //                    self.policiesDict["\(id)"] = "\(name)"
                            
                            let thePolicy = (theEndpoint == "policies") ? result["policy"] as! [String:AnyObject]:result["patch_policy"] as! [String:AnyObject]
                            
                            // check for used computergroups - start
                            let policyScope = thePolicy["scope"] as! [String:AnyObject]
                            print("\(theEndpoint) (\(name)) scope: \(policyScope)")
        //
                            if self.isScoped(scope: policyScope) {
                                if theEndpoint == "policies" {
                                    self.policiesDict["\(name) - (\(id))"]!["used"] = "true"
                                } else {
                                    self.masterObjectDict["patchpolicies"]!["\(name)"]!["used"] = "true"
                                }
                            }
                            
                            if theEndpoint == "policies" {
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
                            }

                            // check for used computergroups - start
        //                    let computerGroupList = thePolicy["scope"] as! [String:AnyObject]
        //                                    print("computerGroupList: \(computerGroupList)")
        //                    let computer_groupList = computerGroupList["computer_groups"] as! [Dictionary<String, Any>]
                            let computer_groupList = policyScope["computer_groups"] as! [Dictionary<String, Any>]
                            for theComputerGroup in computer_groupList {
        //                                        print("thePackage: \(thePackage)")
                                let theComputerGroupName = theComputerGroup["name"]
        //                                        let theComputerGroupID = theComputerGroup["id"]
        //                                        print("packages id for policy id: \(id): \(thePackageID!)")
                                self.computerGroupsDict["\(theComputerGroupName!)"]?["used"] = "true"
                            }
                            // check exclusions - start
        //                    let computer_groupExcl = computerGroupList["exclusions"] as! [String:AnyObject]
                            let computer_groupExcl = policyScope["exclusions"] as! [String:AnyObject]
                            let computer_groupListExcl = computer_groupExcl["computer_groups"] as! [Dictionary<String, Any>]
                            for theComputerGroupExcl in computer_groupListExcl {
        //                                        print("thePackage: \(thePackage)")
                                let theComputerGroupName = theComputerGroupExcl["name"]
        //                                        print("packages id for policy id: \(id): \(thePackageID!)")
                                self.computerGroupsDict["\(theComputerGroupName!)"]?["used"] = "true"
                            }
                            // check exclusions - end
                            // check of used computergroups - end
                            
                        case "mobiledeviceapplications", "mobiledeviceconfigurationprofiles":
                            print("[recursiveLookup] check usage for \(theEndpoint)")
                            
                            let theMobileDeviceObjectXml = (theEndpoint == "mobiledeviceapplications") ? result["mobile_device_application"] as! [String:AnyObject]:result["configuration_profile"] as! [String:AnyObject]
                            
                            // check for used mobiledevicegroups - start
                            let mobileDeviceAppScope = theMobileDeviceObjectXml["scope"] as! [String:AnyObject]
                            print("[recursiveLookup] mobileDeviceAppScope: \(mobileDeviceAppScope)")
        //
                            if self.isScoped(scope: mobileDeviceAppScope) {
        //                        self.mobileDeviceAppsDict["\(name))"]!["used"] = "true"
                                self.masterObjectDict[theEndpoint]!["\(name)"]!["used"] = "true"
                            }

                            // check for used mobiledevicegroups - start
                            let mdaGroupList = theMobileDeviceObjectXml["scope"] as! [String:AnyObject]
        //                                    print("mdaGroupList: \(mdaGroupList)")
                            let mda_groupList = mdaGroupList["mobile_device_groups"] as! [Dictionary<String, Any>]
                            for theMdaGroup in mda_groupList {
        //                                        print("thePackage: \(thePackage)")
                                let theMobileDeviceGroupName = theMdaGroup["name"]
        //                                        let theMdaGroupID = theMdaGroup["id"]
        //                                        print("packages id for policy id: \(id): \(thePackageID!)")
                                self.mobileDeviceGroupsDict["\(theMobileDeviceGroupName!)"]?["used"] = "true"
                            }
                            // check exclusions - start
                            let mobileDevice_groupExcl = mdaGroupList["exclusions"] as! [String:AnyObject]
                            let mobileDevice_groupListExcl = mobileDevice_groupExcl["mobile_device_groups"] as! [Dictionary<String, Any>]
                            for theMdaGroupExcl in mobileDevice_groupListExcl {
        //                                        print("thePackage: \(thePackage)")
                                let theMobileDeviceGroupName = theMdaGroupExcl["name"]
        //                                        print("packages id for policy id: \(id): \(thePackageID!)")
                                self.mobileDeviceGroupsDict["\(theMobileDeviceGroupName!)"]?["used"] = "true"
                            }
                            // check exclusions - end
                            // check of used mobiledevicegroups - end
                            
                        default:
                            print("[switch theEndpoint] unknown: \(theEndpoint)")
                        }
                        
                        if index == objectArrayCount-1 {
                            switch theEndpoint {
                            case "computergroups", "mobiledevicegroups":
                                waitFor.deviceGroup = false
                            case "computerconfigurations":
                                waitFor.computerConfiguration = false
                            case "osxconfigurationprofiles":
                                waitFor.osxconfigurationprofile = false
                            case "policies","patchpolicies","patchsoftwaretitles":
                                waitFor.policy = false
                            case "mobiledeviceapplications", "mobiledeviceconfigurationprofiles":
                                waitFor.mobiledeviceobject = false
                            default:
                                print("[index == objectArrayCount-1] unknown: \(theEndpoint)")
                            }
                        } else {
                            // check the next item
                            self.recursiveLookup(theServer: theServer, base64Creds: base64Creds, theEndpoint: theEndpoint, theData: theData, index: index+1)
                        }
                    }   //Json().getRecord - end
            }
            
        }   // if let id = theObject["id"], let name = theObject["name"] - end
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
            if unusedItems_TableDict?.count == 0  || unusedItems_TableDict?.count == nil {
                unusedItems_TableDict = [["----- header -----":"----- header -----"]]
            } else {
                unusedItems_TableDict!.append(["----- header -----":"----- header -----"])
            }
            let currentDict = itemDictionary[i]
//            print("currentDict: \(currentDict)")
            for (type, theDict) in currentDict {
                print("\ntype: \(type)")
                print("dictionary of objects: \(theDict)")
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
//                print("unusedItems_TableArray.count: \(String(describing: unusedItems_TableArray!.count))")
//                if unusedItems_TableArray?[0] == nil {
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
                object_TableView.reloadData()
                
//                displayUnused(key: type, theList: sortedArray)

                unusedCount = 0
                sortedArray.removeAll()
            }
        }
        view_PopUpButton.isEnabled = true
        working(isWorking: false)

        DispatchQueue.main.async {
            self.process_TextField.isHidden = true
        }
//        print("unusedItems_TableDict: \(unusedItems_TableDict ?? [[:]])")
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
    // used when importing files
    func buildDictionary(type: String, used: String, data: [String:Any]) -> [String:Any] {
        
//        var unusedItemsDictionary = [String:[String:String]]()
        var unusedItemsDictionary = [String:Any]()
        var category            = ""
        
        if let listOfUnused = data[type] {
            for theDict in listOfUnused as! [[String:String]] {
                if type != "unusedComputerGroups" && type != "unusedMobileDeviceGroups" {
                    unusedItemsDictionary[theDict["name"]!] = ["id":theDict["id"]!,"used":"false"]
                } else {
                    unusedItemsDictionary[theDict["name"]!] = ["id":theDict["id"]!,"used":"false","groupType":theDict["groupType"]]
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
        case "unusedComputerProfiles":
            category = "osxconfigurationprofiles"
        case "unusedPolicies":
            category = "policies"
        case "unusedMobileDeviceGroups":
            category = "mobiledevicegroups"
        case "unusedMobileDeviceApps":
            category = "mobiledeviceapplications"
        case "unusedMobileDeviceConfigurationProfiles":
            category = "mobiledeviceconfigurationprofiles"
        default:
            category = type
        }
//        return packagesDict
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
            reportItems.append(["packages":self.packagesDict])
        }
        if sender.title == "Scripts" || (sender.title == "All" && scriptsButtonState == "on") {
            reportItems.append(["scripts":self.scriptsDict])
        }
        if sender.title == "Computer Groups" || (sender.title == "All" && computerGroupsButtonState == "on") {
            reportItems.append(["computergroups":self.computerGroupsDict])
        }
        if sender.title == "Computer Profiles" || (sender.title == "All" && computerProfilesButtonState == "on") {
            reportItems.append(["osxconfigurationprofiles":self.masterObjectDict["osxconfigurationprofiles"]!])
        }
        if sender.title == "Policies" || (sender.title == "All" && policiesButtonState == "on") {
            reportItems.append(["policies":self.policiesDict])
        }
        if sender.title == "Mobile Device Groups" || (sender.title == "All" && mobileDeviceGrpsButtonState == "on") {
            reportItems.append(["mobiledevicegroups":self.mobileDeviceGroupsDict])
        }
        if sender.title == "Mobile Device Apps" || (sender.title == "All" && mobileDeviceAppsButtonState == "on") {
            reportItems.append(["mobiledeviceapplications":self.masterObjectDict["mobiledeviceapplications"]!])
        }
        if sender.title == "Mobile Device Config. Profiles" || (sender.title == "All" && configurationProfilesButtonState == "on") {
            reportItems.append(["mobiledeviceconfigurationprofiles":self.masterObjectDict["mobiledeviceconfigurationprofiles"]!])
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
                    for (key, value) in objectJSON! {
//                        print("\(key)")
                        switch key {
                        case "jamfServer":
                            jamfServer_TextField.stringValue = "\(value)"
                            currentServer = "\(value)"
                        case "username":
                            uname_TextField.stringValue = "\(value)"
                        default:
                            print("buildDictionary: \(buildDictionary(type: key, used: "false", data: objectJSON!))")
                            unused(itemDictionary: [buildDictionary(type: key, used: "false", data: objectJSON!)])
                        }
                    }

                } catch {
                    print("file read error")
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
        
        let timeStamp = Time().getCurrent()
        let exportQ = DispatchQueue(label: "com.jamf.prune.exportQ", qos: DispatchQoS.background)
        working(isWorking: true)
        let header = "\"jamfServer\": \"\(currentServer)\",\n \"username\": \"\(uname_TextField.stringValue)\""
        exportQ.sync {
            if self.packagesButtonState == "on" {
                let packageLogFile = "prunePackages_\(timeStamp).json"
//                let packageLogFile = "prunePackages_\(timeStamp).xml"
                let exportURL = getDownloadDirectory().appendingPathComponent(packageLogFile)

                do {
                    try "{\(header),\n \"unusedPackages\":[\n".write(to: exportURL, atomically: true, encoding: .utf8)
//                    try "<unusedPackages>\n".write(to: exportURL, atomically: true, encoding: .utf8)
                } catch {
                    print("failed to write the following: <unusedPackages>")
                }
                
                if let packageLogFileOp = try? FileHandle(forUpdating: exportURL) {
                    for key in sortedArrayFromDict(theDict: packagesDict) {
//                   for (key, _) in packagesDict {
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
                    try "{\(header),\n \"unusedScripts\":[\n".write(to: exportURL, atomically: true, encoding: .utf8)
//                    try "<unusedScripts>\n".write(to: exportURL, atomically: true, encoding: .utf8)
                } catch {
                    print("failed to write the following: <unusedScripts>")
                }
                
                if let scriptLogFileOp = try? FileHandle(forUpdating: exportURL) {
                    for key in sortedArrayFromDict(theDict: scriptsDict) {
//                    for (key, _) in scriptsDict {
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
                    try "{\(header),\n \"unusedComputerGroups\":[\n".write(to: exportURL, atomically: true, encoding: .utf8)
//                    try "<unusedComputerGroups>\n".write(to: exportURL, atomically: true, encoding: .utf8)
                } catch {
                    print("failed to write the following: <unusedComputerGroups>")
                }
                
                if let computerGroupLogFileOp = try? FileHandle(forUpdating: exportURL) {
                    for key in sortedArrayFromDict(theDict: computerGroupsDict) {
//                    for (key, _) in computerGroupsDict {
                        if computerGroupsDict[key]?["used"]! == "false" {
                            computerGroupLogFileOp.seekToEndOfFile()
                            let text = "\t{\"id\": \"\(String(describing: computerGroupsDict[key]!["id"]!))\", \"name\": \"\(key)\", \"groupType\": \"\(String(describing: computerGroupsDict[key]!["groupType"]!))\"},\n"
//                            let text = "\t<id>\(String(describing: computerGroupsDict[key]!["id"]!))</id><name>\(key)</name>\n"
                            computerGroupLogFileOp.write(text.data(using: String.Encoding.utf8)!)
                        }
                    }   // for (key, _) in scriptsDict - end
                    computerGroupLogFileOp.seekToEndOfFile()
                    computerGroupLogFileOp.write("]}".data(using: String.Encoding.utf8)!)
//                    computerGroupLogFileOp.write("</unusedComputerGroups>".data(using: String.Encoding.utf8)!)
                    computerGroupLogFileOp.closeFile()
                }
            }   // if self.computerGroupsButtonState == "on" - end
                        
            if self.computerProfilesButtonState == "on" {
                let ComputerProfileLogFile = "pruneComputerProfiles_\(timeStamp).json"
//                let ComputerProfileLogFile = "pruneComputerProfiles_\(timeStamp).xml"
                let exportURL = getDownloadDirectory().appendingPathComponent(ComputerProfileLogFile)

                do {
                    try "{\(header),\n \"unusedComputerProfiles\":[\n".write(to: exportURL, atomically: true, encoding: .utf8)
//                    try "<unusedComputerProfiles>\n".write(to: exportURL, atomically: true, encoding: .utf8)
                } catch {
                    print("failed to write the following: <unusedComputerProfiles>")
                }
                
                if let computerProfileLogFileOp = try? FileHandle(forUpdating: exportURL) {
                    for key in sortedArrayFromDict(theDict: masterObjectDict["osxconfigurationprofiles"]!) {
//                   for (key, _) in masterObjectDict["osxconfigurationprofiles"]! {
                        if masterObjectDict["osxconfigurationprofiles"]![key]?["used"]! == "false" {
                            computerProfileLogFileOp.seekToEndOfFile()
                            let text = "\t{\"id\": \"\(String(describing: masterObjectDict["osxconfigurationprofiles"]![key]!["id"]!))\", \"name\": \"\(key)\"},\n"
//                            let text = "\t<id>\(String(describing: computerGroupsDict[key]!["id"]!))</id><name>\(key)</name>\n"
                            computerProfileLogFileOp.write(text.data(using: String.Encoding.utf8)!)
                        }
                    }   // for (key, _) in scriptsDict - end
                    computerProfileLogFileOp.seekToEndOfFile()
                    computerProfileLogFileOp.write("]}".data(using: String.Encoding.utf8)!)
//                    computerGroupLogFileOp.write("</unusedComputerGroups>".data(using: String.Encoding.utf8)!)
                    computerProfileLogFileOp.closeFile()
                }
            }   // if self.computerGroupsButtonState == "on" - end

            if self.policiesButtonState == "on" {
                let policyLogFile = "prunePolicies_\(timeStamp).json"
//                let policyLogFile = "prunePolicies_\(timeStamp).xml"
                let exportURL = getDownloadDirectory().appendingPathComponent(policyLogFile)

                do {
                    try "{\(header),\n \"unusedPolicies\":[\n".write(to: exportURL, atomically: true, encoding: .utf8)
//                    try "<unusedPackages>\n".write(to: exportURL, atomically: true, encoding: .utf8)
                } catch {
                    print("failed to write the following: <unusedPolicies>")
                }
                
                if let policyLogFileOp = try? FileHandle(forUpdating: exportURL) {
                    for key in sortedArrayFromDict(theDict: policiesDict) {
//                   for (key, _) in policiesDict {
                        if policiesDict[key]?["used"]! == "false" {
                            policyLogFileOp.seekToEndOfFile()
                            let text = "\t{\"id\": \"\(String(describing: policiesDict[key]!["id"]!))\", \"name\": \"\(key)\"},\n"
//                            let text = "\t{\"id\": \"\(key)\", \"name\": \"\(String(describing: packagesDict[key]!["name"]!))\"},\n"
//                            let text = "\t{\"id\": \"\(key)\",\n\"name\": \"\(String(describing: packagesDict[key]!["name"]!))\",\n\"used\": \"false\"},\n"
//                            let text = "\t<id>\(key)</id><name>\(String(describing: packagesDict[key]!["name"]!))</name>\n"
                            policyLogFileOp.write(text.data(using: String.Encoding.utf8)!)
                        }
                    }   // for (key, _) in packagesDict - end
                    policyLogFileOp.seekToEndOfFile()
                    policyLogFileOp.write("]}".data(using: String.Encoding.utf8)!)
//                    packageLogFileOp.write("</unusedPackages>".data(using: String.Encoding.utf8)!)
                    policyLogFileOp.closeFile()
                }
            }
                        
            if self.mobileDeviceGrpsButtonState == "on" {
                let mobileDeviceGroupLogFile = "pruneMobileDeviceGroups_\(timeStamp).json"
//                let mobileDeviceGroupLogFile = "pruneComputerGroups_\(timeStamp).xml"
                let exportURL = getDownloadDirectory().appendingPathComponent(mobileDeviceGroupLogFile)

                do {
                    try "{\(header),\n \"unusedMobileDeviceGroups\":[\n".write(to: exportURL, atomically: true, encoding: .utf8)
//                    try "<unusedMobileDeviceGroups>\n".write(to: exportURL, atomically: true, encoding: .utf8)
                } catch {
                    print("failed to write the following: <unusedMobileDeviceGroups>")
                }
                
                if let mobileDeviceGroupLogFileOp = try? FileHandle(forUpdating: exportURL) {
                    for key in sortedArrayFromDict(theDict: mobileDeviceGroupsDict) {
//                   for (key, _) in mobileDeviceGroupsDict {
                        if mobileDeviceGroupsDict[key]?["used"]! == "false" {
                            mobileDeviceGroupLogFileOp.seekToEndOfFile()
                            let text = "\t{\"id\": \"\(String(describing: mobileDeviceGroupsDict[key]!["id"]!))\", \"name\": \"\(key)\", \"groupType\": \"\(String(describing: mobileDeviceGroupsDict[key]!["groupType"]!))\"},\n"
//                            let text = "\t<id>\(String(describing: mobileDeviceGroupLogFileOp[key]!["id"]!))</id><name>\(key)</name>\n"
                            mobileDeviceGroupLogFileOp.write(text.data(using: String.Encoding.utf8)!)
                        }
                    }   // for (key, _) in scriptsDict - end
                    mobileDeviceGroupLogFileOp.seekToEndOfFile()
                    mobileDeviceGroupLogFileOp.write("]}".data(using: String.Encoding.utf8)!)
//                    mobileDeviceGroupLogFileOp.write("</unusedMobileDeviceGroups>".data(using: String.Encoding.utf8)!)
                    mobileDeviceGroupLogFileOp.closeFile()
                }
            }   // if self.mobileDeviceGrpsButtonState == "on" - end
            
            if self.mobileDeviceAppsButtonState == "on" {
                let logFile = "pruneMobileDeviceApps_\(timeStamp).json"
//                let logFile = "pruneComputerProfiles_\(timeStamp).xml"
                let exportURL = getDownloadDirectory().appendingPathComponent(logFile)

                do {
                    try "{\(header),\n \"unusedMobileDeviceApps\":[\n".write(to: exportURL, atomically: true, encoding: .utf8)
//                    try "<unusedMobileDeviceApps>\n".write(to: exportURL, atomically: true, encoding: .utf8)
                } catch {
                    print("failed to write the following: <unusedMobileDeviceApps>")
                }
                
                if let logFileOp = try? FileHandle(forUpdating: exportURL) {
                    for key in sortedArrayFromDict(theDict: masterObjectDict["mobiledeviceapplications"]!) {
//                   for (key, _) in masterObjectDict["mobiledeviceapplications"]! {
                        if masterObjectDict["mobiledeviceapplications"]![key]?["used"]! == "false" {
                            logFileOp.seekToEndOfFile()
                            let text = "\t{\"id\": \"\(String(describing: masterObjectDict["mobiledeviceapplications"]![key]!["id"]!))\", \"name\": \"\(key)\"},\n"
//                            let text = "\t<id>\(String(describing: masterObjectDict["mobiledeviceapplications"]![key]!["id"]!))</id><name>\(key)</name>\n"
                            logFileOp.write(text.data(using: String.Encoding.utf8)!)
                        }
                    }   // for (key, _) in scriptsDict - end
                    logFileOp.seekToEndOfFile()
                    logFileOp.write("]}".data(using: String.Encoding.utf8)!)
//                    logFileOp.write("</unusedMobileDeviceApps>".data(using: String.Encoding.utf8)!)
                    logFileOp.closeFile()
                }
            }   // if self.mobileDeviceAppsButtonState == "on" - end
                        
            if self.configurationProfilesButtonState == "on" {
                let logFile = "pruneMobileDeviceConfigurationProfiles_\(timeStamp).json"
//                let logFile = "pruneMobileDeviceConfigurationProfiles_\(timeStamp).xml"
                let exportURL = getDownloadDirectory().appendingPathComponent(logFile)

                do {
                    try "{\(header),\n \"unusedMobileDeviceConfigurationProfiles\":[\n".write(to: exportURL, atomically: true, encoding: .utf8)
//                    try "<unusedMobileDeviceConfigurationProfiles>\n".write(to: exportURL, atomically: true, encoding: .utf8)
                } catch {
                    print("failed to write the following: <unusedMobileDeviceConfigurationProfiles>")
                }
                
                if let logFileOp = try? FileHandle(forUpdating: exportURL) {
                    for key in sortedArrayFromDict(theDict: masterObjectDict["mobiledeviceconfigurationprofiles"]!) {
//                    for (key, _) in masterObjectDict["mobiledeviceconfigurationprofiles"]! {
                        if masterObjectDict["mobiledeviceconfigurationprofiles"]![key]?["used"]! == "false" {
                            logFileOp.seekToEndOfFile()
                            let text = "\t{\"id\": \"\(String(describing: masterObjectDict["mobiledeviceconfigurationprofiles"]![key]!["id"]!))\", \"name\": \"\(key)\"},\n"
//                            let text = "\t<id>\(String(describing: masterObjectDict["mobiledeviceconfigurationprofiles"]![key]!["id"]!))</id><name>\(key)</name>\n"
                            logFileOp.write(text.data(using: String.Encoding.utf8)!)
                        }
                    }   // for (key, _) in scriptsDict - end
                    logFileOp.seekToEndOfFile()
                    logFileOp.write("]}".data(using: String.Encoding.utf8)!)
//                    logFileOp.write("</unusedMobileDeviceConfigurationProfiles>".data(using: String.Encoding.utf8)!)
                    logFileOp.closeFile()
                }
            }   // if self.configurationProfilesButtonState == "on" - end
            
            working(isWorking: false)
        }   // exportQ.sync - end
    }
    
    // remove objects from the list to be deleted - start
    @IBAction func removeObject_Action(_ sender: Any) {
        DispatchQueue.main.async {
            var withOptionKey = false
            let theRow = self.object_TableView.selectedRow
            print("theRow: \(theRow)")

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
                                            print("[removeObject_Action]      itemDict: \(itemName) and type \(objectType)")
                                            print("[removeObject_Action] withOptionKey: \(withOptionKey)")
                                            
                                            switch objectType {
                                                case "packages":
                                                    if withOptionKey {
                                                        self.packagesDict.removeValue(forKey: itemName)
                                                    } else {
                                                        print("[removeObject_Action] single click \(objectType) - without option key")
                                                        return
                                                    }
                                                
                                                case "scripts":
                                                    if withOptionKey {
                                                        self.scriptsDict.removeValue(forKey: itemName)
                                                    } else {
                                                        print("[removeObject_Action] single click \(objectType) - without option key")
                                                        return
                                                    }
                                                
                                                case "computergroups":
                                                    if withOptionKey {
                                                      self.computerGroupsDict.removeValue(forKey: itemName)
                                                    } else {
                                                      print("[removeObject_Action] single click \(objectType) - without option key")
                                                      return
                                                    }
                                                
                                                case "osxconfigurationprofiles":
                                                    if withOptionKey {
                                                      self.masterObjectDict["osxconfigurationprofiles"]?.removeValue(forKey: itemName)
                                                    } else {
                                                      print("[removeObject_Action] single click \(objectType) - without option key")
                                                      return
                                                    }
                                                
                                                case "policies":
                                                    if withOptionKey {
                                                        self.policiesDict.removeValue(forKey: itemName)
                                                    } else {
                                                        print("[removeObject_Action] single click \(objectType) - without option key")
                                                        return
                                                    }

                                                case "mobiledevicegroups":
                                                    if withOptionKey {
                                                        self.mobileDeviceGroupsDict.removeValue(forKey: itemName)
                                                    } else {
                                                        print("[removeObject_Action] single click \(objectType) - without option key")
                                                        return
                                                    }

                                                case "mobiledeviceapplications":
                                                    if withOptionKey {
                                                        self.masterObjectDict["mobiledeviceapplications"]?.removeValue(forKey: itemName)
                                                    } else {
                                                        print("[removeObject_Action] single click \(objectType) - without option key")
                                                        return
                                                    }
                                                
                                                case "mobiledeviceconfigurationprofiles":
                                                    if withOptionKey {
                                                        self.masterObjectDict[objectType]?.removeValue(forKey: itemName)
                                                    } else {
                                                        print("[removeObject_Action] single click \(objectType) - without option key")
                                                        return
                                                    }

                                                default:
                                                    print("[removeObject_Action] unknown objectType: \(String(describing: self.removeObject_Action))")
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
        
        currentServer       = jamfServer_TextField.stringValue
        jamfCreds           = "\(uname_TextField.stringValue):\(passwd_TextField.stringValue)"
        let jamfUtf8Creds   = jamfCreds.data(using: String.Encoding.utf8)
        jamfBase64Creds     = (jamfUtf8Creds?.base64EncodedString())!
        
        theDeleteQ.maxConcurrentOperationCount = 4
        
        let viewing = view_PopUpButton.title
        print("[remove] viewing: \(viewing)")
        print("[remove_Action] packagesDict: \(packagesDict)")
        
        var masterItemsToDeleteArray = [[String:String]]()
        if (viewing == "All" && packagesButtonState == "on") || viewing == "Packages" {
            for (key, _) in packagesDict {
                if packagesDict[key]?["used"] == "false" {
                    let id = "\(String(describing: packagesDict[key]!["id"]!))"
//                    print("[remove_Action] remove package with id: \(key)")
                    masterItemsToDeleteArray.append(["packages":id])
                }
            }
        }

        if (viewing == "All" && scriptsButtonState == "on") || viewing == "Scripts" {
            for (key, _) in scriptsDict {
                if scriptsDict[key]?["used"] == "false" {
                    let id = "\(String(describing: scriptsDict[key]!["id"]!))"
//                    print("[remove_Action] remove script with id: \(id)")
                    masterItemsToDeleteArray.append(["scripts":id])
                }
            }
        }

        if (viewing == "All" && computerGroupsButtonState == "on") || viewing == "Computer Groups" {
            for (key, _) in computerGroupsDict {
                if computerGroupsDict[key]?["used"] == "false" {
                    let id = "\(String(describing: computerGroupsDict[key]!["id"]!))"
//                    print("[remove_Action] remove computer group with id: \(id)")
                    masterItemsToDeleteArray.append(["computergroups":id])
                }
            }
        }

        if (viewing == "All" && computerProfilesButtonState == "on") || viewing == "Configuration Policies" {
            for (key, _) in masterObjectDict["osxconfigurationprofiles"]! {
                if masterObjectDict["osxconfigurationprofiles"]?[key]?["used"] == "false" {
                    let id = "\(String(describing: masterObjectDict["osxconfigurationprofiles"]![key]!["id"]!))"
//                    print("[remove_Action] remove computer group with id: \(id)")
                    masterItemsToDeleteArray.append(["osxconfigurationprofiles":id])
                }
            }
        }

        if (viewing == "All" && policiesButtonState == "on") || viewing == "Policies" {
            for (key, _) in policiesDict {
                if policiesDict[key]?["used"] == "false" {
                    let id = "\(String(describing: policiesDict[key]!["id"]!))"
//                    print("[remove_Action] remove computer group with id: \(id)")
                    masterItemsToDeleteArray.append(["policies":id])
                }
            }
        }

        if (viewing == "All" && mobileDeviceGrpsButtonState == "on") || viewing == "Mobile Device Groups" {
            for (key, _) in mobileDeviceGroupsDict {
                if mobileDeviceGroupsDict[key]?["used"] == "false" {
                    let id = "\(String(describing: mobileDeviceGroupsDict[key]!["id"]!))"
//                    print("[remove_Action] remove mobile device group with id: \(id)")
                    masterItemsToDeleteArray.append(["mobiledevicegroups":id])
                }
            }
        }

        if (viewing == "All" && mobileDeviceAppsButtonState == "on") || viewing == "Mobile Device Apps" {
            for (key, _) in masterObjectDict["mobiledeviceapplications"]! {
                if masterObjectDict["mobiledeviceapplications"]?[key]?["used"] == "false" {
                    let id = "\(String(describing: masterObjectDict["mobiledeviceapplications"]![key]!["id"]!))"
//                    print("[remove_Action] remove mobiledeviceapplication with id: \(id)")
                    masterItemsToDeleteArray.append(["mobiledeviceapplications":id])
                }
            }
        }

        if (viewing == "All" && configurationProfilesButtonState == "on") || viewing == "Mobile Device Config. Profiles" {
            for (key, _) in masterObjectDict["mobiledeviceconfigurationprofiles"]! {
                if masterObjectDict["mobiledeviceconfigurationprofiles"]?[key]?["used"] == "false" {
                    let id = "\(String(describing: masterObjectDict["mobiledeviceconfigurationprofiles"]![key]!["id"]!))"
//                    print("[remove_Action] remove mobiledeviceconfigurationprofile with id: \(id)")
                    masterItemsToDeleteArray.append(["mobiledeviceconfigurationprofiles":id])
                }
            }
        }
        
        print("masterItemsToDeleteArray: \(masterItemsToDeleteArray)")

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
                                self.working(isWorking: false)
                                Alert().display(header: "Alert", message: "Verify username and password.")
                                return
                            }
                            print("[remove_Action] failed to removed \(category) with id: \(id)")
                        }
                        completed = true
                        
                        print("[remove_Action] removed \(category) with id: \(id)")
//                        print("json returned packages: \(result)")
                        counter += 1
                        if counter == masterItemsToDeleteArray.count {
                            self.working(isWorking: false)
                            Alert().display(header: "Congratulations", message: "Removal process complete.")
//                            self.process_TextField.stringValue = "All removals have been processed."
//                            sleep(3)
                        }
                                        
                    }   // Xml().action - end
                    while !completed {
                        usleep(50000)
                    }
                }
            }
            // loop through master list and delete items - end
        }
    }
    // remove objects from the server - end
    

    @IBAction func updateViewButton_Action(_ sender: NSButton) {
        var withOptionKey = false
        let availableButtons = ["Packages", "Scripts", "Computer Groups", "Computer Profiles", "Policies", "Mobile Device Groups", "Mobile Device Apps", "Mobile Device Config. Profiles"]
        // check for option key - start
        if NSEvent.modifierFlags.contains(.option) {
            withOptionKey = true
        }
        // check for option key - end
        
        let state = (sender.state.rawValue == 1) ? "on":"off"
        if withOptionKey {
            if state == "on" {
                packages_Button.state = NSControl.StateValue(rawValue: 1)
                scripts_Button.state = NSControl.StateValue(rawValue: 1)
                computerGroups_Button.state = NSControl.StateValue(rawValue: 1)
                computerProfiles_Button.state = NSControl.StateValue(rawValue: 1)
                policies_Button.state = NSControl.StateValue(rawValue: 1)
                mobileDeviceGroups_Button.state = NSControl.StateValue(rawValue: 1)
                mobileDeviceApps_Button.state = NSControl.StateValue(rawValue: 1)
                configurationProfiles_Button.state = NSControl.StateValue(rawValue: 1)
                for theButton in availableButtons {
//                    computers_button.state = NSControl.StateValue(rawValue: 0)
                    view_PopUpButton.addItem(withTitle: "\(theButton)")
                }
            } else {
                packages_Button.state = NSControl.StateValue(rawValue: 0)
                scripts_Button.state = NSControl.StateValue(rawValue: 0)
                computerGroups_Button.state = NSControl.StateValue(rawValue: 0)
                computerProfiles_Button.state = NSControl.StateValue(rawValue: 0)
                policies_Button.state = NSControl.StateValue(rawValue: 0)
                mobileDeviceGroups_Button.state = NSControl.StateValue(rawValue: 0)
                mobileDeviceApps_Button.state = NSControl.StateValue(rawValue: 0)
                configurationProfiles_Button.state = NSControl.StateValue(rawValue: 0)
                view_PopUpButton.removeAllItems()
                view_PopUpButton.addItem(withTitle: "All")
            }
            packagesButtonState              = "\(state)"
            scriptsButtonState               = "\(state)"
            computerGroupsButtonState        = "\(state)"
            computerProfilesButtonState      = "\(state)"
            policiesButtonState              = "\(state)"
            mobileDeviceGrpsButtonState      = "\(state)"
            mobileDeviceAppsButtonState      = "\(state)"
            configurationProfilesButtonState = "\(state)"
        } else {
            let title = sender.title
            if state == "on" {
                view_PopUpButton.addItem(withTitle: "\(title)")
            } else {
                view_PopUpButton.removeItem(withTitle: "\(title)")
            }
            switch title {
            case "Packages":
                packagesButtonState = "\(state)"
//
            case "Scripts":
                scriptsButtonState = "\(state)"
//
            case "Computer Groups":
                computerGroupsButtonState = "\(state)"
//
            case "Computer Profiles":
                computerProfilesButtonState = "\(state)"

            case "Policies":
                policiesButtonState = "\(state)"

            case "Mobile Device Groups":
                mobileDeviceGrpsButtonState = "\(state)"

            case "Mobile Device Apps":
                mobileDeviceAppsButtonState = "\(state)"

            case "Mobile Device Config. Profiles":
                configurationProfilesButtonState = "\(state)"

            default:
                if state == "on" {
                    
                }
            }
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
        print("doubleClicked Row: \(String(object_TableView.clickedRow))")

        DispatchQueue.main.async {
            let theRow = self.object_TableView.selectedRow

            if let itemName = self.unusedItems_TableArray?[theRow] {
                
                if let itemDict = self.unusedItems_TableDict?[theRow] {
                    if (self.itemSeperators.firstIndex(of: itemName) ?? -1) == -1 {
                        for (_, objectType) in itemDict as [String:String] {
                            
                            print("[viewSelectObject] open itemDict: \(itemName) of type \(objectType) in browser")
                            
                            switch objectType {
                                case "packages":
                                    if let objectId = self.packagesDict[itemName]?["id"], let objectURL = URL(string: "\(self.currentServer)/packages.html?id=\(objectId)&o=r") {
                                        NSWorkspace.shared.open(objectURL)
                                        return
                                    }
                                
                                case "scripts":
                                    if let objectId = self.scriptsDict[itemName]?["id"], let objectURL = URL(string: "\(self.currentServer)/view/settings/computer/scripts/\(objectId)") {
                                      NSWorkspace.shared.open(objectURL)
                                        return
                                    }
                                
                                case "computergroups":
                                      if let objectId = self.computerGroupsDict[itemName]?["id"], let groupType = self.computerGroupsDict[itemName]?["groupType"], let objectURL = URL(string: "\(self.currentServer)/\(groupType)s.html/?id=\(objectId)&o=r") {
                                        NSWorkspace.shared.open(objectURL)
                                          return
                                      }
                                
                                case "osxconfigurationprofiles":
                                      if let objectId = self.masterObjectDict["osxconfigurationprofiles"]?[itemName]?["id"], let objectURL = URL(string: "\(self.currentServer)/OSXConfigurationProfiles.html?id=\(objectId)&o=r") {
                                          NSWorkspace.shared.open(objectURL)
                                          return
                                      }
                                
                                case "policies":
                                    if let objectId = self.policiesDict[itemName]?["id"], let objectURL = URL(string: "\(self.currentServer)/policies.html?id=\(objectId)&o=r") {
                                        NSWorkspace.shared.open(objectURL)
                                        return
                                    }

                                case "mobiledevicegroups":
                                    if let objectId = self.mobileDeviceGroupsDict[itemName]?["id"], let groupType = self.mobileDeviceGroupsDict[itemName]?["groupType"], let objectURL = URL(string: "\(self.currentServer)/\(groupType)s.html/?id=\(objectId)&o=r") {
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

                                default:
                                    print("[viewSelectObject] unknown objectType: \(String(describing: self.removeObject_Action))")
                                    return
                            }
                        }
                    }
                }   //if let itemDict - end
            }   // if let itemName - end
        }   // dispatchQueue.main.async - end
    }   // func viewSelectObject - end
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        object_TableView.delegate   = self
        object_TableView.dataSource = self
        object_TableView.doubleAction = #selector(viewSelectObject)
        
                
        // configure import button
        import_Button.url          = getDownloadDirectory().appendingPathComponent("/.")
        import_Button.allowedTypes = ["json"]
        
        jamfServer_TextField.stringValue = defaults.object(forKey: "server") as? String ?? ""
        if (jamfServer_TextField.stringValue != "") {
            let regexKey        = try! NSRegularExpression(pattern: "http(.*?)://", options:.caseInsensitive)
            let credKey         = regexKey.stringByReplacingMatches(in: jamfServer_TextField.stringValue, options: [], range: NSRange(0..<jamfServer_TextField.stringValue.utf16.count), withTemplate: "")
            let credentailArray  = Credentials2().retrieve(service: "prune - "+credKey)
            if credentailArray.count == 2 {
                uname_TextField.stringValue  = credentailArray[0]
                passwd_TextField.stringValue = credentailArray[1]
            } else {
                uname_TextField.stringValue  = defaults.object(forKey: "username") as? String ?? ""
                passwd_TextField.stringValue = ""
            }
        } else {
            uname_TextField.stringValue  = defaults.object(forKey: "username") as? String ?? ""
            passwd_TextField.stringValue = ""
        }
        savePassword_Button.state = NSControl.StateValue(rawValue: defaults.object(forKey: "passwordButton") as? Int ?? 0)
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
            print("hidden column 1")
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
    
    
    
}
