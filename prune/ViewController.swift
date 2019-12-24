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
    @IBOutlet weak var computerProfiles: NSButton!
    @IBOutlet weak var policies: NSButton!
    
    @IBOutlet weak var object_TableView: NSTableView!
    
    @IBOutlet weak var spinner_ProgressIndicator: NSProgressIndicator!
    
    
    @IBOutlet weak var import_Button: NSPathControl!
    
//    @IBAction func removeItem_Action(_ sender: Any) {
//    }
    
    @IBAction func updateViewButton_Action(_ sender: NSButton) {
        var withOptionKey = false
        let availableButtons = ["Packages", "Scripts", "Computer Groups", "Computer Profiles", "Policies"]
        // check for option key - start
        if NSEvent.modifierFlags.contains(.option) {
        //                               print("check for option key - success")
            withOptionKey = true
        }
        // check for option key - end
        
        let state = (sender.state.rawValue == 1) ? "on":"off"
        if withOptionKey {
            if state == "on" {
                packages_Button.state = NSControl.StateValue(rawValue: 1)
                scripts_Button.state = NSControl.StateValue(rawValue: 1)
                computerGroups_Button.state = NSControl.StateValue(rawValue: 1)
                computerProfiles.state = NSControl.StateValue(rawValue: 1)
                policies.state = NSControl.StateValue(rawValue: 1)
                for theButton in availableButtons {
//                    computers_button.state = NSControl.StateValue(rawValue: 0)
                    view_PopUpButton.addItem(withTitle: "\(theButton)")
                }
            } else {
                packages_Button.state = NSControl.StateValue(rawValue: 0)
                scripts_Button.state = NSControl.StateValue(rawValue: 0)
                computerGroups_Button.state = NSControl.StateValue(rawValue: 0)
                computerProfiles.state = NSControl.StateValue(rawValue: 0)
                policies.state = NSControl.StateValue(rawValue: 0)
                view_PopUpButton.removeAllItems()
            }
            packagesButtonState         = "\(state)"
            scriptsButtonState          = "\(state)"
            computerGroupsButtonState   = "\(state)"
            computerProfilesButtonState = "\(state)"
            policiesButtonState         = "\(state)"
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
//                if state == "on" {
//                    policiesButtonState = "on"
//                } else {
//                    policiesButtonState = "off"
//                }
            default:
                if state == "on" {
                    
                }
            }
        }
    }
    
    @IBOutlet weak var process_TextField: NSTextField!
    
    let defaults = UserDefaults.standard
    
    var currentServer   = ""
    var jamfCreds       = ""
    var jamfBase64Creds = ""
    var completed       = 0
    // define master dictionary of items
    // ex. masterObjectDict["packages"] = [[package1Name:["id":id1,"name":name1]],[package2Name:["id":id2,"name":name2]]]
    var masterObjectDict          = [String:[String:[String:String]]]()
    var packagesDict              = Dictionary<String,Dictionary<String,String>>()    // id, name, used
    var scriptsDict               = Dictionary<String,Dictionary<String,String>>()    // id, name, used
    var policiesDict              = [String:[String:String]]()    //:Dictionary<String,String> = [:]
//    var policiesDict              = [String:String]()    //:Dictionary<String,String> = [:]
    var computerConfigurationDict = [String:String]()
    var computerGroupsDict        = Dictionary<String,Dictionary<String,String>>()
    var osxconfigurationprofilesDict = [String:[String:String]]()
    var allUnused                 = [[String:[String:String]]]() //Dictionary<String,Dictionary<String,String>>()    // currently unused var
    var unusedItems_TableArray: [String]?
    var unusedItems_TableDict: [[String:String]]?
    
    var itemSeperators              = [String]()
    
    var packagesButtonState         = "off"
    var scriptsButtonState          = "off"
    var computerGroupsButtonState   = "off"
    var computerProfilesButtonState = "off"
    var policiesButtonState         = "off"
    
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
                    self.defaults.set(self.currentServer, forKey: "server")
                    self.defaults.set("\(self.uname_TextField.stringValue)", forKey: "username")
                    self.process_TextField.isHidden = false
                    self.process_TextField.stringValue = "Starting lookups..."
                }
                print("[go_action caller] start lookups...")
                self.processItems(type: "computerGroups")
//                self.processItems(type: "packages")
            } else {
                DispatchQueue.main.async {
                    self.working(isWorking: false)
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
        default:
            print("unknown")
        }
                    
        let theObject = objectArray[index]
        if let id = theObject["id"], let name = theObject["name"] {
            print("lookup id \(id) \t \(index+1) of \(objectArrayCount)")
            Json().getRecord(theServer: self.currentServer, base64Creds: self.jamfBase64Creds, theEndpoint: "\(objectEndpoint)/\(id)") {
                            (result: [String:AnyObject]) in
                switch theEndpoint {
                case "computergroups":
                    // look for nested computer groups
                    let computerGroupInfo = result["computer_group"] as! Dictionary<String, AnyObject>
                    let criterion = computerGroupInfo["criteria"] as! [Dictionary<String, Any>]
                    for theCriteria in criterion {
                        if let name = theCriteria["name"], let value = theCriteria["value"] {
                            if (name as! String) == "Computer Group" {
                                self.computerGroupsDict["\(value)"] = ["used":"true"]
                            }
                        }
                    }
                    // look for nested computer groups - end
                    
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
                    
                    let thePolicy = result["policy"] as! [String:AnyObject]
                    
                    // check for used computergroups - start
                    let policyScope = thePolicy["scope"] as! [String:AnyObject]
//
                    if self.isScoped(scope: policyScope) {
                        self.policiesDict["\(name) - (\(id))"]!["used"] = "true"
                    }
                    
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
                    
                    
                default:
                    print("unknown")
                }
                
                if index == objectArrayCount-1 {
                    switch theEndpoint {
                    case "computergroups":
                        waitFor.computerGroup = false
                    case "computerconfigurations":
                        waitFor.computerConfiguration = false
                    case "osxconfigurationprofiles":
                        waitFor.osxconfigurationprofile = false
                    case "policies":
                        waitFor.policy = false
                    default:
                        print("unknown")
                    }
                    
                } else {
                    self.recursiveLookup(theServer: theServer, base64Creds: base64Creds, theEndpoint: theEndpoint, theData: theData, index: index+1)
                }
            }   //Json().getRecord - end
        }   // if let id = theObject["id"], let name = theObject["name"] - end
    }
    
    func processItems(type: String) {
        
//        let semaphore = DispatchSemaphore(value: 0)
        theGetQ.maxConcurrentOperationCount = 3

        theGetQ.addOperation {
            switch type {
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
                                    var groupType = "smartComputerGroup"
                                    // loop through all computer groups and mark as unused
                                    // skip All managed clients / servers
                                    for i in (0..<computerGroupsArrayCount) {
                                        if let id = computerGroupsArray[i]["id"], let name = computerGroupsArray[i]["name"], let isSmart = computerGroupsArray[i]["is_smart"] {
                                            // skip by id rather than name?
                                            if !(isSmart as! Bool) {
                                                groupType = "staticComputerGroup"
                                            }
                                            if "\(name)" != "All Managed Clients" && "\(name)" != "All Managed Servers" {
                                                self.computerGroupsDict["\(name)"] = ["id":"\(id)", "used":"false", "groupType":"\(groupType)"]
                                            }
                                        }
                                    }   // for i in (0..<computerGroupsArrayCount) - end
                                    // look for nested computer groups
                                    DispatchQueue.main.async {
                                        self.process_TextField.stringValue = "Scanning for nested computer groups..."
                                    }
                                    self.recursiveLookup(theServer: self.currentServer, base64Creds: self.jamfBase64Creds, theEndpoint: "computergroups", theData: computerGroupsArray, index: 0)
                                    waitFor.computerGroup = true
                                    self.backgroundQ.async {
                                        while true {
                                            usleep(10)
                                            if !waitFor.computerGroup {
                                                print("call packages")
                                                DispatchQueue.main.async {
                                                    self.processItems(type: "packages")
                                                }
                                                break
                                            }
                                        }
                                    }

                                }

                            }
                        } else {
                            print("call packages")
                            DispatchQueue.main.async {
                                self.processItems(type: "packages")
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
                           
            // object that have a scope - start
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
                        self.recursiveLookup(theServer: self.currentServer, base64Creds: self.jamfBase64Creds, theEndpoint: "computerconfigurations", theData: computerConfigurationsArray, index: 0)
                        waitFor.computerConfiguration = true
                        self.backgroundQ.async {
                            while true {
                                usleep(10)
                                if !waitFor.computerConfiguration {
                                    print("call osxconfigurationprofiles")
                                    DispatchQueue.main.async {
                                        self.processItems(type: "osxconfigurationprofiles")
                                    }
                                    break
                                }
                            }
                        }
                        
                    } else {
                        // no computer configurations exist
                        print("call osxconfigurationprofiles")
                        DispatchQueue.main.async {
                            self.processItems(type: "osxconfigurationprofiles")
                        }
                    }
                }   //         Json().getRecord - computerConfigurations - end
                                                
            case "osxconfigurationprofiles":
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
                                            print("call policies")
                                            DispatchQueue.main.async {
                                                self.processItems(type: "policies")
                                            }
                                            break
                                        }
                                    }
                                }
                            }

                            print("call policies")
                            DispatchQueue.main.async {
                                self.processItems(type: "policies")
                            }
                        } else {
                            print("call policies")
                            DispatchQueue.main.async {
                                self.processItems(type: "policies")
                            }
                        }
                    }
                
            case "policies":
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
                                        print("call unused")
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
                                        DispatchQueue.main.async {
                                            self.unused(itemDictionary: reportItems)
                                        }
                                        
                                        break
                                    }
                                }
                            }
                            
                    }
                }   //         Json().getRecord - policies - end
                // object that have a scope - end
                
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
            if unusedItems_TableDict?.count == 0  || unusedItems_TableDict?.count == nil {
                unusedItems_TableDict = [["----- header -----":"----- header -----"]]
            } else {
                unusedItems_TableDict!.append(["----- header -----":"----- header -----"])
            }
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
        case "unusedComputerProfiles":
            category = "osxconfigurationprofiles"
        case "unusedPolicies":
            category = "policies"
        default:
            category = type
        }
//        return packagesDict
        return ["\(category)":unusedItemsDictionary]
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
        working(isWorking: true)
        
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
            }   // if self.computerGroupsButtonState == "on" - end
                        
                        if self.computerProfilesButtonState == "on" {
                            let ComputerProfileLogFile = "pruneComputerProfiles_\(timeStamp).json"
            //                let ComputerProfileLogFile = "pruneComputerProfiles_\(timeStamp).xml"
                            let exportURL = getDownloadDirectory().appendingPathComponent(ComputerProfileLogFile)

                            do {
                                try "{\"unusedComputerProfiles\":[\n".write(to: exportURL, atomically: true, encoding: .utf8)
            //                    try "<unusedComputerProfiles>\n".write(to: exportURL, atomically: true, encoding: .utf8)
                            } catch {
                                print("failed to write the following: <unusedComputerProfiles>")
                            }
                            
                            if let computerProfileLogFileOp = try? FileHandle(forUpdating: exportURL) {
                                for (key, _) in masterObjectDict["osxconfigurationprofiles"]! {
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
                                try "{\"unusedPolicies\":[\n".write(to: exportURL, atomically: true, encoding: .utf8)
            //                    try "<unusedPackages>\n".write(to: exportURL, atomically: true, encoding: .utf8)
                            } catch {
                                print("failed to write the following: <unusedPolicies>")
                            }
                            
                            if let policyLogFileOp = try? FileHandle(forUpdating: exportURL) {
                                for (key, _) in policiesDict {
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
            working(isWorking: false)
        }
    }
    
    // remove objects from the list to be deleted - start
        @IBAction func removeObject_Action(_ sender: Any) {
            var withOptionKey = false
            let theRow = object_TableView.selectedRow

            if let itemName = unusedItems_TableArray?[theRow] {
//                print("[removeObject_Action] itemName: \(itemName)")
//                print("[removeObject_Action] unusedItems_TableDict: \(String(describing: unusedItems_TableDict))")
                if let itemDict = unusedItems_TableDict?[theRow] {
                    if (itemSeperators.firstIndex(of: itemName) ?? -1) == -1 {
                        for (_, objectType) in itemDict as [String:String] {
                            if NSEvent.modifierFlags.contains(.option) {
//                               print("check for option key - success")
                                withOptionKey = true
                           }
                          print("[removeObject_Action] itemDict: \(itemName) and type \(objectType)")
                          switch objectType {
                          case "packages":
                            if withOptionKey {
                                if let objectId = packagesDict[itemName]?["id"], let objectURL = URL(string: "\(currentServer)/packages.html?id=\(objectId)&o=r") {
//                                    NSWorkspace.shared.openURL(NSURL(string: "\(currentServer)/policies.html?id=306&o=r"))
                                    NSWorkspace.shared.open(objectURL)
                                    return
                                }
                            } else {
                               packagesDict.removeValue(forKey: itemName)
                            }
    //                          print("before - packages dictionary: \(packagesDict)")
//                              packagesDict.removeValue(forKey: itemName)
    //                          print("after - packages dictionary: \(packagesDict)")
                          case "scripts":
                            if withOptionKey {
                                if let objectId = scriptsDict[itemName]?["id"], let objectURL = URL(string: "\(currentServer)/view/settings/computer/scripts/\(objectId)") {
                                //                                    NSWorkspace.shared.openURL(NSURL(string: "\(currentServer)/policies.html?id=306&o=r"))
                                  NSWorkspace.shared.open(objectURL)
                                    return
                                }
                            } else {
                                scriptsDict.removeValue(forKey: itemName)
                            }
    //                          print("before - scripts dictionary: \(scriptsDict)")
//                              scriptsDict.removeValue(forKey: itemName)
    //                          print("after - scripts dictionary: \(scriptsDict)")
                          case "computergroups":
                              if withOptionKey {
                                  if let objectId = computerGroupsDict[itemName]?["id"], let groupType = computerGroupsDict[itemName]?["groupType"], let objectURL = URL(string: "\(currentServer)/\(groupType)s.html/?id=\(objectId)&o=r") {
                                  //                                    NSWorkspace.shared.openURL(NSURL(string: "\(currentServer)/policies.html?id=306&o=r"))
                                    NSWorkspace.shared.open(objectURL)
                                      return
                                  }
                              } else {
                                  computerGroupsDict.removeValue(forKey: itemName)
                              }
    //                          print("before - computerGroups dictionary: \(computerGroupsDict)")
//                              computerGroupsDict.removeValue(forKey: itemName)
    //                          print("after - computerGroups dictionary: \(computerGroupsDict)")
                          case "osxconfigurationprofiles":
                              if withOptionKey {
                                  if let objectId = masterObjectDict["osxconfigurationprofiles"]?[itemName]?["id"], let objectURL = URL(string: "\(currentServer)/OSXConfigurationProfiles.html?id=\(objectId)&o=r") {
  //                                    NSWorkspace.shared.openURL(NSURL(string: "\(currentServer)/policies.html?id=306&o=r"))
                                      NSWorkspace.shared.open(objectURL)
                                      return
                                  }
                              } else {
                                 masterObjectDict["osxconfigurationprofiles"]?.removeValue(forKey: itemName)
                              }
    //                          print("before - computerGroups dictionary: \(computerGroupsDict)")
//                            masterObjectDict["osxconfigurationprofiles"]?.removeValue(forKey: itemName)
    //                          print("after - computerGroups dictionary: \(computerGroupsDict)")
                          case "policies":
                            if withOptionKey {
                                if let objectId = policiesDict[itemName]?["id"], let objectURL = URL(string: "\(currentServer)/policies.html?id=\(objectId)&o=r") {
//                                    NSWorkspace.shared.openURL(NSURL(string: "\(currentServer)/policies.html?id=306&o=r"))
                                    NSWorkspace.shared.open(objectURL)
                                    return
                                }
                            } else {
                               policiesDict.removeValue(forKey: itemName)
                            }
                          default:
                              print("unknown")
                            return
                          }
                          unusedItems_TableDict?.remove(at: theRow)
                          unusedItems_TableArray?.remove(at: theRow)
                        }
    //                    unusedItems_TableArray?.remove(at: theRow)
                        object_TableView.reloadData()
                    }
                }
            }
        }
        // remove objects from the list to be deleted - end
        
    // remove objects from the server - start
    @IBAction func remove_Action(_ sender: Any) {
        
        working(isWorking: true)
        
        currentServer       = jamfServer_TextField.stringValue
        jamfCreds           = "\(uname_TextField.stringValue):\(passwd_TextField.stringValue)"
        let jamfUtf8Creds   = jamfCreds.data(using: String.Encoding.utf8)
        jamfBase64Creds     = (jamfUtf8Creds?.base64EncodedString())!
        
        theDeleteQ.maxConcurrentOperationCount = 3
        
        let viewing = view_PopUpButton.title
        print("[remove] viewing: \(viewing)")
        print("[remove_Action] packagesDict: \(packagesDict)")
        
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
                        usleep(500000)
                    }
                }
            }
            // loop through master list and delete items - end
        }
    }
    // remove objects from the server - end
    
    
    func getDownloadDirectory() -> URL {
        let downloadsDirectory = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0]
        return downloadsDirectory
    }
    
    func isScoped(scope: [String:AnyObject]) -> Bool {
//        print("[isScoped] scope: \(scope)")
        // Note checking limitations or exclusions
        let objects = ["all_computers","all_jss_users","buildings","departments","computers","computer_groups","jss_users","jss_user_groups"]
        for theObject in objects {
            switch theObject {
            case "all_computers", "all_jss_users":
                if let test = scope[theObject] {
                    if (test as! Bool) {
                        return true
                    }
                } else {
                    return false
                }
            default:
//                print("[isScoped] scope[theObject]: \(String(describing: scope[theObject]))")
                if let test = scope[theObject] {
//                    print("[isScoped]-passed test - \(theObject): \(test)")
                    if (test.count > 0) {
                        return true
                    }
                } else {
                    return false
                }
            }
        }
        
        return false
    }
    
    func working(isWorking: Bool) {
        if isWorking {
            DispatchQueue.main.async {
                self.spinner_ProgressIndicator.startAnimation(self)
            }
        } else {
            DispatchQueue.main.async {
                self.spinner_ProgressIndicator.stopAnimation(self)
            }
        }
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
        jamfServer_TextField.stringValue = defaults.object(forKey: "server") as? String ?? ""
        uname_TextField.stringValue      = defaults.object(forKey: "username") as? String ?? ""
        passwd_TextField.stringValue     = ""
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
    
//    override func mouseDown(with event: NSEvent) {
//
//        let test = keyDown(with: j)
//    }
//    override func keyDown(with event: NSEvent) {
//        print("[extension ViewController] modifer = " + "\(event.modifierFlags.intersection(.deviceIndependentFlagsMask))")
//        print("[extension ViewController] key = " + (event.charactersIgnoringModifiers ?? ""))
//        print("\n[extension ViewController] character = " + (event.characters ?? ""))
//        switch event.modifierFlags.intersection(.deviceIndependentFlagsMask) {
//
//        case [.command] where event.characters == "l",
//             [.command, .shift] where event.characters == "l":
//            print("[extension ViewController] command-l or command-shift-l")
//        default:
//            break
//        }
//    }


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
            print("no such column")
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
