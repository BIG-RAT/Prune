//
//  LoginViewController.swift
//  prune
//
//  Created by Leslie Helou on 01/17/22.
//  Copyright © 2022 Leslie Helou. All rights reserved.
//

import Cocoa
import Foundation

protocol SendingLoginInfoDelegate {
    func sendLoginInfo(loginInfo: (String,String,String,String,Int))
}

class LoginViewController: NSViewController, NSTextFieldDelegate {
    
    var delegate: SendingLoginInfoDelegate? = nil
    
    @IBOutlet weak var spinner_PI: NSProgressIndicator!
    
//    @IBOutlet weak var header_TextField: NSTextField!
    @IBOutlet weak var displayName_Label: NSTextField!
    @IBOutlet weak var displayName_TextField: NSTextField!
    @IBOutlet weak var selectServer_Button: NSPopUpButton!
    
    @IBOutlet weak var selectedServer_ButtonCell: NSPopUpButtonCell!
    @IBOutlet weak var useApiClient_button: NSButton!
    
    @IBAction func selectServer_Action(_ sender: Any) {
        if selectedServer_ButtonCell.titleOfSelectedItem == "Add Server..." {
            
            displayName_TextField.becomeFirstResponder()
        
//            header_TextField.isHidden = false
//            header_TextField.wantsLayer = true
//            header_TextField.stringValue = "Enter the information for the Jamf Pro server you'd like to manage."
//            header_TextField.frame.size.height = 41.0
            
            displayName_TextField.insertText("hello")
            displayName_Label.stringValue = "Display Name:"
            displayName_TextField.stringValue = ""
            selectServer_Button.isHidden = true
            displayName_TextField.isHidden = false
            serverURL_Label.isHidden = false
            jamfProServer_textfield.isHidden = false
            jamfProServer_textfield.isEditable = true
            jamfProServer_textfield.stringValue = ""
            jamfProUsername_textfield.stringValue = ""
            jamfProPassword_textfield.stringValue = ""
            saveCreds_button.state = NSControl.StateValue(rawValue: 0)
            defaults.set(0, forKey: "saveCreds")
            hideCreds_button.isHidden = true
            quit_Button.title  = "Cancel"
            login_Button.title = "Add"
            
            setWindowSize(setting: 2)
        } else {
//            header_TextField.isHidden = true
//            header_TextField.wantsLayer = true
//            header_TextField.stringValue = ""
//            header_TextField.frame.size.height = 0.0
            if NSEvent.modifierFlags.contains(.option) {
                    let selectedServer =  selectServer_Button.titleOfSelectedItem!
                    let response = Alert().display(header: "", message: "Are you sure you want to remove \(selectedServer) from the list?", secondButton: "Cancel")
                    if response == "Cancel" {
                        return
                    } else {
                        for (displayName, _) in availableServersDict {
                            if displayName == selectedServer {
                                availableServersDict[displayName] = nil
                                selectServer_Button.removeItem(withTitle: selectedServer)
                                sortedDisplayNames.removeAll(where: {$0 == displayName})
                            }
                        }
                        if saveServers {
                            sharedDefaults!.set(availableServersDict, forKey: "serversDict")
                        }
                        if sortedDisplayNames.firstIndex(of: lastServerDN) != nil {
                            selectServer_Button.selectItem(withTitle: lastServerDN)
                        } else {
                            selectServer_Button.selectItem(withTitle: "")
                            jamfProServer_textfield.stringValue   = ""
                            jamfProUsername_textfield.stringValue = ""
                            jamfProPassword_textfield.stringValue = ""
                            selectServer_Button.selectItem(withTitle: "")
                        }
                    }
                
                return
            }
            displayName_Label.stringValue = "Server:"
            selectServer_Button.isHidden = false
            displayName_TextField.isHidden = true
            
            let fullDisplay = hideCreds_button.state.rawValue == 1 ? false:true
            serverURL_Label.isHidden = fullDisplay
            jamfProServer_textfield.isHidden = fullDisplay
            jamfProServer_textfield.isEditable = fullDisplay
            hideCreds_button.isHidden = false
            useApiClient_button.isHidden = fullDisplay
            displayName_TextField.stringValue = selectedServer_ButtonCell.title
            jamfProServer_textfield.stringValue = (availableServersDict[selectedServer_ButtonCell.title]?["server"])! as! String
            credentialsCheck()
            quit_Button.title  = "Quit"
            login_Button.title = "Login"
            
        }
    }
    @IBOutlet weak var selectServer_Menu: NSMenu!
    
    @IBOutlet weak var hideCreds_button: NSButton!
    
    @IBOutlet weak var serverURL_Label: NSTextField!
    @IBOutlet weak var username_label: NSTextField!
    @IBOutlet weak var password_label: NSTextField!
    
    @IBOutlet weak var jamfProServer_textfield: NSTextField!
    @IBOutlet weak var jamfProUsername_textfield: NSTextField!
    @IBOutlet weak var jamfProPassword_textfield: NSSecureTextField!
    
    
    
    @IBOutlet weak var login_Button: NSButton!
    @IBOutlet weak var quit_Button: NSButton!
    //    @IBOutlet weak var upload_progressIndicator: NSProgressIndicator!
//    @IBOutlet weak var continueButton: NSButton!
    
    var availableServersDict   = [String:[String:AnyObject]]()
    
//    var sourcePlistsURL        = URL(string: "/")
//    var xmlFileNames           = [String]()
        
    var accountDict            = [String:String]()
    var currentServer          = ""
    var categoryName           = ""
    var uploadCount            = 0
    var totalObjects           = 0
    var uploadsComplete        = false
    var sortedDisplayNames     = [String]()
    var lastServer             = ""
    var lastServerDN           = ""

    @IBOutlet weak var saveCreds_button: NSButton!
    
    @IBAction func hideCreds_action(_ sender: NSButton) {
        print("[hideCreds_action] button state: \(hideCreds_button.state.rawValue)")
        hideCreds_button.image = (hideCreds_button.state.rawValue == 0) ? NSImage(named: NSImage.rightFacingTriangleTemplateName):NSImage(named: NSImage.touchBarGoDownTemplateName)
        defaults.set("\(hideCreds_button.state.rawValue)", forKey: "hideCreds")
        setWindowSize(setting: hideCreds_button.state.rawValue)
    }
    
    @IBAction func login_action(_ sender: Any) {
        spinner_PI.isHidden = false
        spinner_PI.startAnimation(self)
        didRun = true
        
        var theSender = ""
//        var theButton: NSButton?
        if (sender as? NSButton) != nil {
            theSender = (sender as? NSButton)!.title
        } else {
            theSender = sender as! String
        }

        //        if theSender == "Add" {
            JamfProServer.source   = jamfProServer_textfield.stringValue
            JamfProServer.username = jamfProUsername_textfield.stringValue
            JamfProServer.password = jamfProPassword_textfield.stringValue
//        }
//        print("[login_action] destination: \(JamfProServer.source)")
//        print("[login_action] username: \(JamfProServer.username)")
//        print("[login_action] userpass: \(JamfProServer.password)")
        
        // check for update/removal of server display name
        if jamfProServer_textfield.stringValue == "" {
            let serverToRemove = (theSender == "Login") ? "\(selectServer_Button.titleOfSelectedItem ?? "")":displayName_TextField.stringValue
            let deleteReply = Alert().display(header: "Attention:", message: "Do you wish to remove \(serverToRemove) from the list?", secondButton: "Cancel")
            if deleteReply != "Cancel" && serverToRemove != "Add Server..." {
                if availableServersDict[serverToRemove] != nil {
                    let serverIndex = selectServer_Menu.indexOfItem(withTitle: serverToRemove)
                    selectServer_Menu.removeItem(at: serverIndex)
                    if defaults.string(forKey: "currentServer") == availableServersDict[serverToRemove]!["server"] as? String {
                        defaults.set("", forKey: "currentServer")
                    }
                    availableServersDict[serverToRemove] = nil
                    lastServer = ""
                    jamfProServer_textfield.stringValue   = ""
                    jamfProUsername_textfield.stringValue = ""
                    jamfProPassword_textfield.stringValue = ""
                    if saveServers {
                        sharedDefaults!.set(availableServersDict, forKey: "serversDict")
                    }
                    selectServer_Button.selectItem(withTitle: "")
                }
                
                spinner_PI.stopAnimation(self)
                return
            } else {
                spinner_PI.stopAnimation(self)
                return
            }
        } else if jamfProServer_textfield.stringValue != availableServersDict[selectServer_Button.titleOfSelectedItem!]?["server"] as? String && selectServer_Button.titleOfSelectedItem ?? "" != "Add Server..." {
            let serverToUpdate = (theSender == "Login") ? "\(selectServer_Button.titleOfSelectedItem ?? "")":displayName_TextField.stringValue.fqdnFromUrl
            let updateReply = Alert().display(header: "Attention:", message: "Do you wish to update the URL for \(serverToUpdate) to: \(jamfProServer_textfield.stringValue)", secondButton: "Cancel")
            if updateReply != "Cancel" && serverToUpdate != "Add Server..." {
                // update server URL
                availableServersDict[serverToUpdate]?["server"] = jamfProServer_textfield.stringValue as AnyObject
                if saveServers {
                    sharedDefaults!.set(availableServersDict, forKey: "serversDict")
                }
            } else {
                jamfProServer_textfield.stringValue = availableServersDict[selectServer_Button.titleOfSelectedItem!]?["server"] as! String
            }
        }
        
        if theSender == "Login" {
            JamfProServer.validToken = false
            let dataToBeSent = (selectServer_Button.titleOfSelectedItem!, JamfProServer.source, JamfProServer.username, JamfProServer.password, saveCreds_button.state.rawValue)
            spinner_PI.stopAnimation(self)
            delegate?.sendLoginInfo(loginInfo: dataToBeSent)
            dismiss(self)
        } else {
            if displayName_TextField.stringValue == "" {
                let nameReply = Alert().display(header: "Attention:", message: "Display name cannot be blank.\nUse \(jamfProServer_textfield.stringValue.fqdnFromUrl)?", secondButton: "Cancel")
                if nameReply == "Cancel" {
                    spinner_PI.stopAnimation(self)
                    return
                } else {
                    displayName_TextField.stringValue = jamfProServer_textfield.stringValue.fqdnFromUrl
                }
            }   // no display name - end
            
            login_Button.isEnabled = false
            
            if JamfProServer.source.prefix(4) != "http" {
                jamfProServer_textfield.stringValue = "https://\(JamfProServer.source)"
                JamfProServer.source = jamfProServer_textfield.stringValue
            }
            
            let jamfUtf8Creds = "\(JamfProServer.username):\(JamfProServer.password)".data(using: String.Encoding.utf8)
            JamfProServer.base64Creds = (jamfUtf8Creds?.base64EncodedString())!

            JamfPro().getToken(serverUrl: JamfProServer.source, whichServer: "source", base64creds: JamfProServer.base64Creds) { [self]
                authResult in
                
                login_Button.isEnabled = true
                
                let (statusCode,theResult) = authResult
                if theResult == "success" {
                    // invalidate token - todo
//
//                    header_TextField.isHidden          = true
//                    header_TextField.wantsLayer        = true
//                    header_TextField.stringValue       = ""
//                    header_TextField.frame.size.height = 0.0
                    
                    sortedDisplayNames.append(displayName_TextField.stringValue)
                    while availableServersDict.count >= maxServerList {
                        // find last used server
                        var lastUsedDate = Date()
                        var serverName   = ""
                        for (displayName, serverInfo) in availableServersDict {
                            if let _ = serverInfo["date"] {
                                if (serverInfo["date"] as! Date) < lastUsedDate {
                                    lastUsedDate = serverInfo["date"] as! Date
                                    serverName = displayName
                                }
                            } else {
                                serverName = displayName
                                break
                            }
                        }
                        availableServersDict[serverName] = nil
                    }
                    
                    availableServersDict[displayName_TextField.stringValue] = ["server":JamfProServer.source as AnyObject,"date":Date() as AnyObject]
                    if saveServers {
                        sharedDefaults!.set(availableServersDict, forKey: "serversDict")
                    }
                    print("[login_action] availableServers: \(availableServersDict)")
                    
                    defaults.set(JamfProServer.source, forKey: "currentServer")
                    defaults.set(JamfProServer.username, forKey: "username")
                    
                    setSelectServerButton(listOfServers: sortedDisplayNames)
                    selectServer_Button.selectItem(withTitle: displayName_TextField.stringValue)
                    displayName_Label.stringValue = "Server:"
                    selectServer_Button.isHidden = false
                    displayName_TextField.isHidden = true
                    quit_Button.title  = "Quit"
                    login_Button.title = "Login"
                    
                    login_action("Login")
                } else {
                    spinner_PI.stopAnimation(self)
                    _ = Alert().display(header: "Attention:", message: "Failed to generate token. HTTP status code: \(statusCode)", secondButton: "")
                }
            }
        }
    }
    
    @IBAction func quit_Action(_ sender: NSButton) {
        if sender.title == "Quit" {
            dismiss(self)
            NSApplication.shared.terminate(self)
        } else if login_Button.title == "Add" {
//            header_TextField.isHidden = true
//            header_TextField.wantsLayer = true
//            header_TextField.stringValue = ""
//            header_TextField.frame.size.height = 0.0
            displayName_Label.stringValue = "Server:"
            selectServer_Button.isHidden = false
            displayName_TextField.isHidden = true
            serverURL_Label.isHidden = false
            jamfProServer_textfield.isHidden = false
            jamfProServer_textfield.isEditable = false
            hideCreds_button.isHidden = false
            if lastServer != "" {
                var tmpName = ""
                for (dName, serverInfo) in availableServersDict {
                    tmpName = dName
                    if (serverInfo["server"] as! String) == lastServer { break }
                }
                selectServer_Button.selectItem(withTitle: tmpName)
                displayName_TextField.stringValue = tmpName
                jamfProServer_textfield.stringValue = (availableServersDict[tmpName]?["server"])! as! String
                credentialsCheck()
            } else {
                login_Button.isEnabled              = false
                jamfProServer_textfield.isEnabled   = false
                jamfProUsername_textfield.isEnabled = false
                jamfProPassword_textfield.isEnabled = false
            }
            quit_Button.title  = "Quit"
            login_Button.title = "Login"
        } else {
            dismiss(self)
        }
    }
    
    @IBAction func saveCredentials_Action(_ sender: Any) {
        if saveCreds_button.state.rawValue == 1 {
            defaults.set(1, forKey: "saveCreds")
        } else {
            defaults.set(0, forKey: "saveCreds")
        }
    }
    
    @IBAction func useApiClient_action(_ sender: NSButton) {
        setLabels()
        defaults.set(useApiClient_button.state.rawValue, forKey: "sourceUseApiClient")
        fetchPassword()
    }
    
    func fetchPassword() {
        let accountDict = Credentials().retrieve(service: jamfProServer_textfield.stringValue.fqdnFromUrl, account: jamfProUsername_textfield.stringValue)
        
        if accountDict.count == 1 {
            for (username, password) in accountDict {
                jamfProUsername_textfield.stringValue = username
                jamfProPassword_textfield.stringValue = password
            }
        } else {
            jamfProPassword_textfield.stringValue = ""
        }
    }

    func setLabels() {
        useApiClient = useApiClient_button.state.rawValue
        if useApiClient == 0 {
            username_label.stringValue = "Username:"
            password_label.stringValue = "Password:"
        } else {
            username_label.stringValue = "Client ID:"
            password_label.stringValue = "Client Secret:"
        }
    }
    
    func controlTextDidEndEditing(_ obj: Notification) {
        if let textField = obj.object as? NSTextField {
            jamfProPassword_textfield.stringValue = ""
            switch textField.identifier!.rawValue {
            case "server":
                let accountDict = Credentials().retrieve(service: jamfProServer_textfield.stringValue.fqdnFromUrl, account: jamfProUsername_textfield.stringValue)
                
                if accountDict.count == 1 {
                    for (username, password) in accountDict {
                        jamfProUsername_textfield.stringValue = username
                        jamfProPassword_textfield.stringValue = password
                    }
                } //else {
//                    if login_Button.title == "Login" {
//                        setWindowSize(setting: 1)
//                    } else {
//                        setWindowSize(setting: 2)
//                    }
//                }
            case "username":
                let accountDict = Credentials().retrieve(service: "\(jamfProServer_textfield.stringValue.fqdnFromUrl)", account: jamfProUsername_textfield.stringValue)
                if accountDict.count != 0 {
                    for (username, password) in accountDict {
                        if username == jamfProUsername_textfield.stringValue {
                            jamfProUsername_textfield.stringValue = username
                            jamfProPassword_textfield.stringValue = password
                        }
                    }
                } //else {
//                    jamfProUsername_textfield.stringValue = ""
//                }
            default:
                break
            }
        }
    }
    func controlTextDidChange(_ obj: Notification) {
        if let textField = obj.object as? NSTextField {
            jamfProPassword_textfield.stringValue = ""
            switch textField.identifier!.rawValue {
            case "server":
                if jamfProUsername_textfield.stringValue != "" || jamfProPassword_textfield.stringValue != "" {
                    let accountDict = Credentials().retrieve(service: jamfProServer_textfield.stringValue.fqdnFromUrl, account: jamfProUsername_textfield.stringValue)
                    
                    if accountDict.count == 1 {
                        for (username, password) in accountDict {
                            jamfProUsername_textfield.stringValue = username
                            jamfProPassword_textfield.stringValue = password
                        }
//                        setWindowSize(setting: 0)
                    } else {
                        jamfProUsername_textfield.stringValue = ""
                        jamfProPassword_textfield.stringValue = ""
//                        setWindowSize(setting: 1)
                    }
                }
            default:
                break
            }
        }
    }
    
    func credentialsCheck() {
        let accountDict = Credentials().retrieve(service: jamfProServer_textfield.stringValue.fqdnFromUrl, account: jamfProUsername_textfield.stringValue)
        
        if accountDict.count != 0 {
            for (username, password) in accountDict {
//                print("[credentialsCheck] username: \(username)")
                if username == jamfProUsername_textfield.stringValue || accountDict.count == 1 {
                    jamfProUsername_textfield.stringValue = username
                    jamfProPassword_textfield.stringValue = password
                }
//                let windowState = (defaults.integer(forKey: "hideCreds") == 1) ? 1:0
//                hideCreds_button.isHidden = false
//                saveCreds_button.state = NSControl.StateValue(rawValue: 1)
//                defaults.set(1, forKey: "saveCreds")
//                setWindowSize(setting: windowState)
            }
        } else {
//            if useApiClient == 0 {
//                jamfProUsername_textfield.stringValue = defaults.string(forKey: "username") ?? ""
//            } else {
//                jamfProUsername_textfield.stringValue = ""
//            }
            jamfProPassword_textfield.stringValue = ""
            setWindowSize(setting: 1)
        }
        JamfProServer.source   = jamfProServer_textfield.stringValue
        JamfProServer.username = jamfProUsername_textfield.stringValue
        JamfProServer.password = jamfProPassword_textfield.stringValue
    }
    
    func setSelectServerButton(listOfServers: [String]) {
        // case insensitive sort
        sortedDisplayNames = listOfServers.sorted{ $0.localizedCompare($1) == .orderedAscending }
        selectServer_Button.removeAllItems()
        selectServer_Button.addItems(withTitles: sortedDisplayNames)
        let serverCount = selectServer_Menu.numberOfItems
        selectServer_Menu.insertItem(NSMenuItem.separator(), at: serverCount)
        selectServer_Button.addItem(withTitle: "Add Server...")
    }
    
    func setWindowSize(setting: Int) {
//        print("[setWindowSize] setting: \(setting)")
        if setting == 0 {
            preferredContentSize = CGSize(width: 518, height: 85)
            hideCreds_button.toolTip = "show username/password fields"
            jamfProServer_textfield.isHidden   = true
            jamfProUsername_textfield.isHidden = true
            jamfProPassword_textfield.isHidden = true
            serverURL_Label.isHidden           = true
            username_label.isHidden            = true
            password_label.isHidden            = true
            saveCreds_button.isHidden          = true
            useApiClient_button.isHidden       = true
        } else if setting == 1 {
            preferredContentSize = CGSize(width: 518, height: 208)
            hideCreds_button.toolTip = "hide username/password fields"
            jamfProServer_textfield.isHidden   = false
            jamfProUsername_textfield.isHidden = false
            jamfProPassword_textfield.isHidden = false
            serverURL_Label.isHidden           = false
            username_label.isHidden            = false
            password_label.isHidden            = false
            saveCreds_button.isHidden          = false
            useApiClient_button.isHidden       = false
        } else if setting == 2 {
            preferredContentSize = CGSize(width: 518, height: 208)
            hideCreds_button.toolTip = "hide username/password fields"
            jamfProServer_textfield.isHidden   = false
            jamfProUsername_textfield.isHidden = false
            jamfProPassword_textfield.isHidden = false
            serverURL_Label.isHidden           = false
            username_label.isHidden            = false
            password_label.isHidden            = false
            saveCreds_button.isHidden          = false
            useApiClient_button.isHidden       = false
        }
    }
        
    override func viewDidLoad() {
        super.viewDidLoad()
        
        migrateAppGroupSettings()
        
        // to clear saved list of servers
//        defaults.set([:] as [String:[String:AnyObject]], forKey: "serversDict")
//        sharedDefaults!.set([:] as [String:[String:AnyObject]], forKey: "serversDict")
        // clear lastServer
//        defaults.set("", forKey: "currentServer")
        
//        header_TextField.stringValue = ""
//        header_TextField.wantsLayer = true
//        let textFrame = NSTextField(frame: NSRect(x: 0, y: 0, width: 268, height: 1))
//        header_TextField.frame = textFrame.frame
        
        let hideCredsState = defaults.integer(forKey: "hideCreds")
        hideCreds_button.image = (hideCredsState == 0) ? NSImage(named: NSImage.rightFacingTriangleTemplateName):NSImage(named: NSImage.touchBarGoDownTemplateName)
        hideCreds_button.state = NSControl.StateValue(rawValue: hideCredsState)
        setWindowSize(setting: hideCreds_button.state.rawValue)

        jamfProServer_textfield.delegate   = self
        jamfProUsername_textfield.delegate = self
//        jamfProPassword_textfield.delegate = self
        
        lastServer = defaults.string(forKey: "currentServer") ?? ""
//        print("[viewDidLoad] lastServer: \(lastServer)")
        var foundServer = false
        
        useApiClient = defaults.integer(forKey: "sourceUseApiClient")
        useApiClient_button.state = NSControl.StateValue(rawValue: useApiClient)
        setLabels()
                
        // check shared settings
//        print("[viewDidLoad] sharedSettingsPlistUrl: \(sharedSettingsPlistUrl.path)")
        if !FileManager.default.fileExists(atPath: sharedSettingsPlistUrl.path) {
            sharedDefaults!.set(Date(), forKey: "created")
            sharedDefaults!.set([String:AnyObject](), forKey: "serversDict")
        }
        if (sharedDefaults!.object(forKey: "serversDict") as? [String:AnyObject] ?? [:]).count == 0 {
            sharedDefaults!.set(availableServersDict, forKey: "serversDict")
        }
        
        // read list of saved servers
        availableServersDict = sharedDefaults!.object(forKey: "serversDict") as? [String:[String:AnyObject]] ?? [:]
        
        
        // trim list of servers to maxServerList
        while availableServersDict.count >= maxServerList {
            // find last used server
            var lastUsedDate = Date()
            var serverName   = ""
            for (displayName, serverInfo) in availableServersDict {
                if let _ = serverInfo["date"] {
                    if (serverInfo["date"] as! Date) < lastUsedDate {
                        lastUsedDate = serverInfo["date"] as! Date
                        serverName = displayName
                    }
                } else {
                    serverName = displayName
                    break
                }
            }
            print("removing \(serverName) from the list")
            availableServersDict[serverName] = nil
        }
//        print("lastServer: \(lastServer)")
        if availableServersDict.count > 0 {
            for (displayName, serverInfo) in availableServersDict {
                if displayName != "" {
                    sortedDisplayNames.append(displayName)
//                    if serverURL["server"] as! String == lastServer && lastServer != "" {
                    if (serverInfo["server"] as! String) == lastServer && lastServer != "" {
                        foundServer = true
                        lastServerDN = displayName
                        //                    break
                    }
                } else {
                    availableServersDict[displayName] = nil
                }
            }
            if foundServer {
                selectServer_Button.selectItem(withTitle: lastServer.fqdnFromUrl)
            }
        } else if lastServer != "" {
            availableServersDict[lastServer.fqdnFromUrl] = ["server":lastServer as AnyObject, "date":Date() as AnyObject]
//            displayName_TextField.stringValue = lastServer.fqdnFromUrl
            
            lastServerDN = lastServer.fqdnFromUrl
            sortedDisplayNames.append(lastServerDN)
        }
        
        setSelectServerButton(listOfServers: sortedDisplayNames)
        
        if sortedDisplayNames.firstIndex(of: lastServerDN) != nil {
            selectServer_Button.selectItem(withTitle: lastServerDN)
        } else {
            selectServer_Button.selectItem(withTitle: "")
        }
        
        jamfProServer_textfield.stringValue = lastServer
        if lastServer != "" {
            jamfProUsername_textfield.stringValue = defaults.string(forKey: "username") ?? ""
        }
        saveCreds_button.state = NSControl.StateValue(defaults.integer(forKey: "saveCreds"))
        
//        print("[LoginVC.viewDidLoad] availableServersDict: \(availableServersDict)")
        if availableServersDict.count != 0 {
            if jamfProServer_textfield.stringValue != "" {
                credentialsCheck()
            }
        } else {
            jamfProServer_textfield.stringValue = ""
            setSelectServerButton(listOfServers: [])
            selectServer_Button.selectItem(withTitle: "Add Server...")
            login_Button.title = "Add"
            selectServer_Action(self)
            setWindowSize(setting: 2)
        }
        // bring app to foreground
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
    
    
    private func migrateAppGroupSettings() {
        let _sharedContainerUrl     = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.\(appsGroupId)")
        let _sharedSettingsPlistUrl = (_sharedContainerUrl?.appendingPathComponent("Library/Preferences/group.\(appsGroupId).plist"))!
        WriteToLog.shared.message(theString: "[migrateAppGroupSettings] _sharedSettingsPlistUrl: \(_sharedSettingsPlistUrl.path(percentEncoded: false))")
//        print("[migrateSettings] sharedSettingsPlistUrl: \(sharedSettingsPlistUrl.path(percentEncoded: false))")
//        print("[migrateSettings] _sharedSettingsPlistUrl: \(_sharedSettingsPlistUrl.path(percentEncoded: false))")
        
        if !FileManager.default.fileExists(atPath: sharedSettingsPlistUrl.path(percentEncoded: false)) {
            WriteToLog.shared.message(theString: "creating settings file")
            sharedDefaults!.set(Date(), forKey: "created")
            sharedDefaults!.set([String:AnyObject](), forKey: "serversDict")
        }
        var serversDict = sharedDefaults!.object(forKey: "serversDict") as? [String:AnyObject] ?? [String:AnyObject]()
        
        WriteToLog.shared.message(theString: "[migrateAppGroupSettings] app group settings file: \(sharedSettingsPlistUrl.path(percentEncoded: false))")
        let settingsMigrated = sharedDefaults!.object(forKey: "migrated") as? String ?? "false"
        WriteToLog.shared.message(theString: "[migrateAppGroupSettings] settingsMigrated: \(settingsMigrated)")
        if settingsMigrated != "true" {
            if FileManager.default.fileExists(atPath: _sharedSettingsPlistUrl.path(percentEncoded: false)) {
                WriteToLog.shared.message(theString: "[migrateAppGroupSettings] legacy settings file exists")
                
                if let oldPrefs = UserDefaults(suiteName: "group.\(appsGroupId)") {
                    let _serversDict = oldPrefs.dictionary(forKey: "serversDict") ?? [String:AnyObject]()
                    for (serverName, serverData) in _serversDict {
                        if (serversDict[serverName] == nil) {
                            serversDict[serverName] = serverData as AnyObject
                        }
                    }
                    sharedDefaults!.set(serversDict, forKey: "serversDict")
                    sharedDefaults!.set("true" as AnyObject, forKey: "migrated")
                    WriteToLog.shared.message(theString: "[migrateAppGroupSettings] migrated settings")
                } else {
                    WriteToLog.shared.message(theString: "[migrateAppGroupSettings] unable to read legacy settings")
                    WriteToLog.shared.message(theString: "[migrateAppGroupSettings] failed to migrate settings")
                }
            } else {
                do {
                    sharedDefaults!.set("true" as AnyObject, forKey: "migrated")
                    try FileManager.default.copyItem(atPath: sharedSettingsPlistUrl.path(percentEncoded: false), toPath: _sharedSettingsPlistUrl.path(percentEncoded: false))
                } catch {
                    
                }
            }
        }
    }
}
