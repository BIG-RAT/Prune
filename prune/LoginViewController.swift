//
//  Copyright 2026 Jamf. All rights reserved.
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
    @IBOutlet weak var authMode_SegmentedControl: NSSegmentedControl!
    
    @IBAction func selectServer_Action(_ sender: Any) {
        if selectedServer_ButtonCell.titleOfSelectedItem == addItemTitle {

            displayName_TextField.becomeFirstResponder()
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
            if NSEvent.modifierFlags.contains(.option) {
                let selectedItem = selectServer_Button.titleOfSelectedItem!
                let response = Alert.shared.display(header: "", message: "Are you sure you want to remove \(selectedItem) from the list?", additionalButton: "Cancel")
                if response == "Cancel" {
                    return
                } else {
                    if useApiClient == 0 {
                        availableIntegrationsDict[selectedItem] = nil
                        sortedIntegrationNames.removeAll(where: {$0 == selectedItem})
                        if saveServers { sharedDefaults!.set(availableIntegrationsDict, forKey: "integrationsDict") }
                        setSelectServerButton(listOfNames: sortedIntegrationNames)
                        if sortedIntegrationNames.firstIndex(of: lastIntegrationDN) != nil {
                            selectServer_Button.selectItem(withTitle: lastIntegrationDN)
                        } else {
                            jamfProServer_textfield.stringValue   = ""
                            jamfProUsername_textfield.stringValue = ""
                            jamfProPassword_textfield.stringValue = ""
                        }
                    } else {
                        availableServersDict[selectedItem] = nil
                        sortedDisplayNames.removeAll(where: {$0 == selectedItem})
                        if saveServers { sharedDefaults!.set(availableServersDict, forKey: "serversDict") }
                        setSelectServerButton(listOfNames: sortedDisplayNames)
                        if sortedDisplayNames.firstIndex(of: lastServerDN) != nil {
                            selectServer_Button.selectItem(withTitle: lastServerDN)
                        } else {
                            jamfProServer_textfield.stringValue   = ""
                            jamfProUsername_textfield.stringValue = ""
                            jamfProPassword_textfield.stringValue = ""
                        }
                    }
                }
                return
            }

            selectServer_Button.isHidden = false
            displayName_TextField.isHidden = true
            hideCreds_button.isHidden = false
            quit_Button.title  = "Quit"
            login_Button.title = "Login"

            let selectedTitle = selectServer_Button.titleOfSelectedItem ?? ""
            displayName_TextField.stringValue = selectedTitle
            if useApiClient == 0 {
                displayName_Label.stringValue = "Integration:"
                if let info = availableIntegrationsDict[selectedTitle] {
                    jamfProServer_textfield.stringValue   = info["tenantId"] as? String ?? ""
                    jamfProUsername_textfield.stringValue = info["clientId"] as? String ?? ""
                    let savedRegion = info["region"] as? String ?? "US"
                    if let idx = ["US", "EU", "APAC"].firstIndex(of: savedRegion) {
                        region_PopUp.selectItem(at: idx)
                    }
                    applyRegionSelection()
                }
            } else {
                displayName_Label.stringValue = "Server:"
                jamfProServer_textfield.stringValue = availableServersDict[selectedTitle]?["server"] as? String ?? ""
            }
            credentialsCheck()
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
    
    var availableServersDict        = [String:[String:AnyObject]]()
    var availableIntegrationsDict   = [String:[String:AnyObject]]()
    var sortedIntegrationNames      = [String]()
    var lastIntegrationDN           = ""
    var lastTenantId                = ""
    var lastClientId                = ""

    private var addItemTitle: String { useApiClient == 0 ? "Add Integration..." : "Add Server..." }

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

    // Region row — added programmatically, shown only in Platform API mode
    var region_Label                = NSTextField(labelWithString: "Region:")
    var region_PopUp                = NSPopUpButton()
    var tenantTopConstraint:        NSLayoutConstraint?  // storyboard: tenantField.top = selectPopUp.bottom + 10
    var regionTopConstraint:        NSLayoutConstraint?  // regionPopUp.top = selectPopUp.bottom + 10
    var tenantBelowRegionConstraint: NSLayoutConstraint? // tenantField.top = regionPopUp.bottom + 10
    
    @IBAction func hideCreds_action(_ sender: NSButton) {
        print("[hideCreds_action] button state: \(hideCreds_button.state.rawValue)")
        hideCreds_button.image = (hideCreds_button.state.rawValue == 0) ? NSImage(named: NSImage.rightFacingTriangleTemplateName):NSImage(named: NSImage.touchBarGoDownTemplateName)
        defaults.set("\(hideCreds_button.state.rawValue)", forKey: "hideCreds")
        setWindowSize(setting: hideCreds_button.state.rawValue)
    }
    
    @IBAction func login_action(_ sender: Any) {
        if selectServer_Button.titleOfSelectedItem == nil {
            print("no server selected")
            return
        }
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

        JamfProServer.source   = jamfProServer_textfield.stringValue
        JamfProServer.username = jamfProUsername_textfield.stringValue
        JamfProServer.password = jamfProPassword_textfield.stringValue
        
//        print("[login_action] destination: \(JamfProServer.source)")
//        print("[login_action] username: \(JamfProServer.username)")
//        print("[login_action] userpass: \(JamfProServer.password)")
        
        // check for update/removal
        if jamfProServer_textfield.stringValue == "" {
            let itemToRemove = (theSender == "Login") ? (selectServer_Button.titleOfSelectedItem ?? "") : displayName_TextField.stringValue
            let deleteReply = Alert.shared.display(header: "Attention:", message: "Do you wish to remove \(itemToRemove) from the list?", additionalButton: "Cancel")
            if deleteReply != "Cancel" && itemToRemove != addItemTitle {
                if useApiClient == 0 {
                    availableIntegrationsDict[itemToRemove] = nil
                    sortedIntegrationNames.removeAll(where: {$0 == itemToRemove})
                    if saveServers { sharedDefaults!.set(availableIntegrationsDict, forKey: "integrationsDict") }
                } else {
                    if availableServersDict[itemToRemove] != nil {
                        let idx = selectServer_Menu.indexOfItem(withTitle: itemToRemove)
                        selectServer_Menu.removeItem(at: idx)
                        if defaults.string(forKey: "currentServer") == availableServersDict[itemToRemove]?["server"] as? String {
                            defaults.set("", forKey: "currentServer")
                        }
                        availableServersDict[itemToRemove] = nil
                        lastServer = ""
                        if saveServers { sharedDefaults!.set(availableServersDict, forKey: "serversDict") }
                        selectServer_Button.selectItem(withTitle: "")
                    }
                }
                jamfProServer_textfield.stringValue   = ""
                jamfProUsername_textfield.stringValue = ""
                jamfProPassword_textfield.stringValue = ""
            }
            spinner_PI.stopAnimation(self)
            return
        } else if useApiClient != 0,
                  jamfProServer_textfield.stringValue != availableServersDict[selectServer_Button.titleOfSelectedItem ?? ""]?["server"] as? String,
                  selectServer_Button.titleOfSelectedItem ?? "" != addItemTitle {
            let serverToUpdate = (theSender == "Login") ? (selectServer_Button.titleOfSelectedItem ?? "") : displayName_TextField.stringValue.fqdnFromUrl
            let updateReply = Alert.shared.display(header: "Attention:", message: "Do you wish to update the URL for \(serverToUpdate) to: \(jamfProServer_textfield.stringValue)", additionalButton: "Cancel")
            if updateReply != "Cancel" && serverToUpdate != addItemTitle {
                availableServersDict[serverToUpdate]?["server"] = jamfProServer_textfield.stringValue as AnyObject
                if saveServers { sharedDefaults!.set(availableServersDict, forKey: "serversDict") }
            } else {
                jamfProServer_textfield.stringValue = availableServersDict[selectServer_Button.titleOfSelectedItem ?? ""]?["server"] as? String ?? ""
            }
        }

        if theSender == "Login" {
            JamfProServer.validToken = false
            if useApiClient == 0 { applyRegionSelection() }
            let dataToBeSent = (selectServer_Button.titleOfSelectedItem!, JamfProServer.source, JamfProServer.username, JamfProServer.password, saveCreds_button.state.rawValue)
            spinner_PI.stopAnimation(self)
            delegate?.sendLoginInfo(loginInfo: dataToBeSent)
            dismiss(self)
        } else {
            // "Add" path
            if displayName_TextField.stringValue == "" {
                let fallback = useApiClient == 0 ? JamfProServer.source : jamfProServer_textfield.stringValue.fqdnFromUrl
                let nameReply = Alert.shared.display(header: "Attention:", message: "Display name cannot be blank.\nUse \(fallback)?", additionalButton: "Cancel")
                if nameReply == "Cancel" {
                    spinner_PI.stopAnimation(self)
                    return
                } else {
                    displayName_TextField.stringValue = fallback
                }
            }

            login_Button.isEnabled = false

            if useApiClient != 0 && JamfProServer.source.prefix(4) != "http" {
                jamfProServer_textfield.stringValue = "https://\(JamfProServer.source)"
                JamfProServer.source = jamfProServer_textfield.stringValue
            }

            let jamfUtf8Creds = "\(JamfProServer.username):\(JamfProServer.password)".data(using: .utf8)
            JamfProServer.base64Creds = (jamfUtf8Creds?.base64EncodedString()) ?? ""

            JamfPro.shared.getToken(serverUrl: JamfProServer.source, whichServer: "source", base64creds: JamfProServer.base64Creds) { [self]
                authResult in

                login_Button.isEnabled = true

                let (statusCode, theResult) = authResult
                if theResult == "success" {
                    let displayName = displayName_TextField.stringValue

                    if useApiClient == 0 {
                        // Platform — save to integrationsDict
                        availableIntegrationsDict[displayName] = [
                            "tenantId": JamfProServer.source as AnyObject,
                            "clientId": JamfProServer.username as AnyObject,
                            "region":   (region_PopUp.titleOfSelectedItem ?? "US") as AnyObject,
                            "date":     Date() as AnyObject
                        ]
                        if saveServers { sharedDefaults!.set(availableIntegrationsDict, forKey: "integrationsDict") }
                        defaults.set(JamfProServer.source,   forKey: "lastTenantId")
                        defaults.set(displayName,            forKey: "lastIntegrationDN")
                        defaults.set(JamfProServer.username, forKey: "lastClientId")
                        lastTenantId      = JamfProServer.source
                        lastIntegrationDN = displayName
                        lastClientId      = JamfProServer.username
                            JamfProServer.tenantId = JamfProServer.source

                        setSelectServerButton(listOfNames: sortedIntegrationNames + [displayName])
                        selectServer_Button.selectItem(withTitle: displayName)
                    } else {
                        // Pro / Classic — save to serversDict
                        sortedDisplayNames.append(displayName)
                        while availableServersDict.count >= maxServerList {
                            var lastUsedDate = Date()
                            var serverName   = ""
                            for (dn, serverInfo) in availableServersDict {
                                if let d = serverInfo["date"] as? Date, d < lastUsedDate {
                                    lastUsedDate = d; serverName = dn
                                } else if serverInfo["date"] == nil {
                                    serverName = dn; break
                                }
                            }
                            availableServersDict[serverName] = nil
                        }
                        availableServersDict[displayName] = ["server": JamfProServer.source as AnyObject, "date": Date() as AnyObject]
                        if saveServers { sharedDefaults!.set(availableServersDict, forKey: "serversDict") }
                        defaults.set(JamfProServer.source,   forKey: "currentServer")
                        defaults.set(JamfProServer.username, forKey: "username")

                        setSelectServerButton(listOfNames: sortedDisplayNames)
                        selectServer_Button.selectItem(withTitle: displayName)
                    }

                    displayName_Label.stringValue = useApiClient == 0 ? "Integration:" : "Server:"
                    selectServer_Button.isHidden = false
                    displayName_TextField.isHidden = true
                    quit_Button.title  = "Quit"
                    login_Button.title = "Login"

                    login_action("Login")
                } else {
                    spinner_PI.stopAnimation(self)
                    _ = Alert.shared.display(header: "Attention:", message: "Failed to generate token. HTTP status code: \(statusCode)", additionalButton: "")
                }
            }
        }
    }
    
    @IBAction func quit_Action(_ sender: NSButton) {
        if sender.title == "Quit" {
            dismiss(self)
            NSApplication.shared.terminate(self)
        } else if login_Button.title == "Add" {
            displayName_Label.stringValue = useApiClient == 0 ? "Integration:" : "Server:"
            selectServer_Button.isHidden = false
            displayName_TextField.isHidden = true
            serverURL_Label.isHidden = false
            jamfProServer_textfield.isHidden = false
            jamfProServer_textfield.isEditable = false
            hideCreds_button.isHidden = false

            if useApiClient == 0 {
                if lastTenantId != "" {
                    jamfProServer_textfield.stringValue   = lastTenantId
                    jamfProUsername_textfield.stringValue = lastClientId
                    if sortedIntegrationNames.firstIndex(of: lastIntegrationDN) != nil {
                        selectServer_Button.selectItem(withTitle: lastIntegrationDN)
                    }
                    credentialsCheck()
                } else {
                    login_Button.isEnabled = false
                }
            } else {
                if lastServer != "" {
                    var tmpName = ""
                    for (dName, serverInfo) in availableServersDict {
                        tmpName = dName
                        if (serverInfo["server"] as? String) == lastServer { break }
                    }
                    selectServer_Button.selectItem(withTitle: tmpName)
                    displayName_TextField.stringValue = tmpName
                    jamfProServer_textfield.stringValue = availableServersDict[tmpName]?["server"] as? String ?? ""
                    credentialsCheck()
                } else {
                    login_Button.isEnabled              = false
                    jamfProServer_textfield.isEnabled   = false
                    jamfProUsername_textfield.isEnabled = false
                    jamfProPassword_textfield.isEnabled = false
                }
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
    
    @IBAction func authMode_action(_ sender: NSSegmentedControl) {
        useApiClient = sender.selectedSegment
        defaults.set(useApiClient, forKey: "useApiClient")
        setLabels()
        if useApiClient == 0 {
            setSelectServerButton(listOfNames: sortedIntegrationNames)
            if lastTenantId != "" {
                jamfProServer_textfield.stringValue   = lastTenantId
                jamfProUsername_textfield.stringValue = lastClientId
                credentialsCheck()
            }
        } else {
            setSelectServerButton(listOfNames: sortedDisplayNames)
            if lastServer != "" {
                if sortedDisplayNames.firstIndex(of: lastServerDN) != nil {
                    selectServer_Button.selectItem(withTitle: lastServerDN)
                }
                jamfProServer_textfield.stringValue = lastServer
                credentialsCheck()
            }
        }
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
        switch useApiClient {
        case 0:  // Platform
            displayName_Label.stringValue = "Integration:"
            serverURL_Label.stringValue   = "Tenant ID:"
            username_label.stringValue    = "Client ID:"
            password_label.stringValue    = "Client Secret:"
            jamfProServer_textfield.placeholderString = "copied from accounts.jamf.com"
        case 1:  // Pro
            displayName_Label.stringValue = "Server:"
            serverURL_Label.stringValue   = "Server URL:"
            username_label.stringValue    = "Client ID:"
            password_label.stringValue    = "Client Secret:"
            jamfProServer_textfield.placeholderString = "https://your.jamf.server"
        default: // Classic
            displayName_Label.stringValue = "Server:"
            serverURL_Label.stringValue   = "Server URL:"
            username_label.stringValue    = "Username:"
            password_label.stringValue    = "Password:"
            jamfProServer_textfield.placeholderString = "https://your.jamf.server"
        }
        updateRegionRowVisibility()
    }
    
    func controlTextDidEndEditing(_ obj: Notification) {
        if let textField = obj.object as? NSTextField {
            jamfProPassword_textfield.stringValue = ""
            switch textField.identifier!.rawValue {
            case "server":
                let accountDict = Credentials().retrieve(service: jamfProServer_textfield.stringValue.fqdnFromUrl, account: jamfProUsername_textfield.stringValue)
                
                for (username, password) in accountDict {
                    if username.lowercased() == jamfProUsername_textfield.stringValue.lowercased() {
                        jamfProUsername_textfield.stringValue = username
                        jamfProPassword_textfield.stringValue = password
                        break
                    }
                }
                
            case "username":
                let accountDict = Credentials().retrieve(service: "\(jamfProServer_textfield.stringValue.fqdnFromUrl)", account: jamfProUsername_textfield.stringValue)
                if accountDict.count != 0 {
                    for (username, password) in accountDict {
                        if username.lowercased() == jamfProUsername_textfield.stringValue.lowercased() {
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
//    func controlTextDidChange(_ obj: Notification) {
//        if let textField = obj.object as? NSTextField {
//            jamfProPassword_textfield.stringValue = ""
//            switch textField.identifier!.rawValue {
//            case "server":
//                if !jamfProUsername_textfield.stringValue.isEmpty || !jamfProPassword_textfield.stringValue.isEmpty {
//                    let accountDict = Credentials().retrieve(service: jamfProServer_textfield.stringValue.fqdnFromUrl, account: jamfProUsername_textfield.stringValue)
//                    
//                    if accountDict.count == 1 {
//                        for (username, password) in accountDict {
//                            jamfProUsername_textfield.stringValue = username
//                            jamfProPassword_textfield.stringValue = password
//                        }
////                        setWindowSize(setting: 0)
//                    } else {
//                        jamfProUsername_textfield.stringValue = ""
//                        jamfProPassword_textfield.stringValue = ""
////                        setWindowSize(setting: 1)
//                    }
//                }
//            default:
//                break
//            }
//        }
//    }
    
    func credentialsCheck() {
        let keychainService = jamfProServer_textfield.stringValue.fqdnFromUrl
        let filterAccount = (useApiClient == 0 && !lastClientId.isEmpty)
            ? lastClientId
            : jamfProUsername_textfield.stringValue
        let accountDict = Credentials().retrieve(service: keychainService, account: filterAccount)

        if accountDict.count != 0 {
            for (username, password) in accountDict {
                if username == filterAccount || accountDict.count == 1 {
                    jamfProUsername_textfield.stringValue = username
                    jamfProPassword_textfield.stringValue = password
                }
            }
        } else {
            jamfProPassword_textfield.stringValue = ""
            setWindowSize(setting: 1)
        }
        JamfProServer.source   = jamfProServer_textfield.stringValue
        JamfProServer.username = jamfProUsername_textfield.stringValue
        JamfProServer.password = jamfProPassword_textfield.stringValue
    }
    
    func setSelectServerButton(listOfNames: [String]) {
        let sorted = listOfNames.sorted { $0.localizedCompare($1) == .orderedAscending }
        if useApiClient == 0 {
            sortedIntegrationNames = sorted
        } else {
            sortedDisplayNames = sorted
        }
        selectServer_Button.removeAllItems()
        selectServer_Button.addItems(withTitles: sorted)
        let count = selectServer_Menu.numberOfItems
        selectServer_Menu.insertItem(NSMenuItem.separator(), at: count)
        selectServer_Button.addItem(withTitle: addItemTitle)
    }
    
    func setWindowSize(setting: Int) {
        let regionExtra: CGFloat = (useApiClient == 0) ? 42 : 0
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
        } else {
            preferredContentSize = CGSize(width: 518, height: 252 + regionExtra)
            hideCreds_button.toolTip = "hide username/password fields"
            jamfProServer_textfield.isHidden   = false
            jamfProUsername_textfield.isHidden = false
            jamfProPassword_textfield.isHidden = false
            serverURL_Label.isHidden           = false
            username_label.isHidden            = false
            password_label.isHidden            = false
            saveCreds_button.isHidden          = false
        }
    }
        
    private func setupRegionRow() {
        guard let container = jamfProServer_textfield.superview else { return }

        region_Label.translatesAutoresizingMaskIntoConstraints = false
        region_Label.isEditable = false
        region_Label.isBezeled = false
        region_Label.drawsBackground = false
        region_Label.alignment = .right

        region_PopUp.translatesAutoresizingMaskIntoConstraints = false
        region_PopUp.addItems(withTitles: ["US", "EU", "APAC"])
        region_PopUp.target = self
        region_PopUp.action = #selector(regionChanged(_:))

        container.addSubview(region_Label)
        container.addSubview(region_PopUp)

        // Align label with serverURL_Label (same leading/trailing), vertically centred on popup
        NSLayoutConstraint.activate([
            region_Label.leadingAnchor.constraint(equalTo: serverURL_Label.leadingAnchor),
            region_Label.trailingAnchor.constraint(equalTo: serverURL_Label.trailingAnchor),
            region_Label.centerYAnchor.constraint(equalTo: region_PopUp.centerYAnchor),
            // Popup aligns left with jamfProServer_textfield, fixed width
            region_PopUp.leadingAnchor.constraint(equalTo: jamfProServer_textfield.leadingAnchor),
            region_PopUp.widthAnchor.constraint(equalToConstant: 120),
        ])

        // Vertical: region row sits 10pt below selectServer_Button
        regionTopConstraint = region_PopUp.topAnchor.constraint(
            equalTo: selectServer_Button.bottomAnchor, constant: 10)
        // Tenant field sits 10pt below region popup (active when region row visible)
        tenantBelowRegionConstraint = jamfProServer_textfield.topAnchor.constraint(
            equalTo: region_PopUp.bottomAnchor, constant: 10)

        // Find the storyboard constraint that places tenantField directly below selectServer_Button
        for c in container.constraints where
            c.firstItem === jamfProServer_textfield &&
            c.firstAttribute == .top &&
            c.secondItem === selectServer_Button &&
            c.secondAttribute == .bottom {
            tenantTopConstraint = c
            break
        }

        // Restore saved region from the last used integration, if any
        if lastIntegrationDN != "",
           let info = availableIntegrationsDict[lastIntegrationDN],
           let savedRegion = info["region"] as? String,
           let idx = ["US", "EU", "APAC"].firstIndex(of: savedRegion) {
            region_PopUp.selectItem(at: idx)
        }
        applyRegionSelection()
    }

    @objc private func regionChanged(_ sender: NSPopUpButton) {
        applyRegionSelection()
    }

    private func applyRegionSelection() {
        switch region_PopUp.titleOfSelectedItem ?? "US" {
        case "EU":   JamfProServer.region = "eu"
        case "APAC": JamfProServer.region = "apac"
        default:     JamfProServer.region = "us"
        }
    }

    private func updateRegionRowVisibility() {
        let show = (useApiClient == 0)
        region_Label.isHidden = !show
        region_PopUp.isHidden = !show

        if show {
            tenantTopConstraint?.isActive = false
            regionTopConstraint?.isActive = true
            tenantBelowRegionConstraint?.isActive = true
        } else {
            tenantBelowRegionConstraint?.isActive = false
            regionTopConstraint?.isActive = false
            tenantTopConstraint?.isActive = true
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        hideCreds_button.isHidden = true

        let hideCredsState = defaults.integer(forKey: "hideCreds")
        hideCreds_button.image = (hideCredsState == 0) ? NSImage(named: NSImage.rightFacingTriangleTemplateName) : NSImage(named: NSImage.touchBarGoDownTemplateName)
        hideCreds_button.state = NSControl.StateValue(rawValue: hideCredsState)
        setWindowSize(setting: 1)

        jamfProServer_textfield.delegate   = self
        jamfProUsername_textfield.delegate = self

        // 1. Restore auth mode
        useApiClient = defaults.integer(forKey: "useApiClient")
        authMode_SegmentedControl.selectedSegment = useApiClient
        setLabels()

        // 2. Ensure shared plist keys exist
        if !FileManager.default.fileExists(atPath: sharedSettingsPlistUrl.path) {
            sharedDefaults!.set(Date(), forKey: "created")
            sharedDefaults!.set([String: AnyObject](), forKey: "serversDict")
            sharedDefaults!.set([String: AnyObject](), forKey: "integrationsDict")
        }
        if sharedDefaults!.object(forKey: "integrationsDict") == nil {
            sharedDefaults!.set([String: AnyObject](), forKey: "integrationsDict")
        }

        // 3. Load integrations
        availableIntegrationsDict = sharedDefaults!.object(forKey: "integrationsDict") as? [String: [String: AnyObject]] ?? [:]
        lastTenantId      = defaults.string(forKey: "lastTenantId")      ?? ""
        lastClientId      = defaults.string(forKey: "lastClientId")      ?? ""
        lastIntegrationDN = defaults.string(forKey: "lastIntegrationDN") ?? ""
        for (displayName, _) in availableIntegrationsDict where displayName != "" {
            sortedIntegrationNames.append(displayName)
        }

        // 4. Load servers
        if (sharedDefaults!.object(forKey: "serversDict") as? [String: AnyObject] ?? [:]).count == 0 {
            sharedDefaults!.set(availableServersDict, forKey: "serversDict")
        }
        availableServersDict = sharedDefaults!.object(forKey: "serversDict") as? [String: [String: AnyObject]] ?? [:]
        lastServer = defaults.string(forKey: "currentServer") ?? ""

        while availableServersDict.count >= maxServerList {
            var lastUsedDate = Date()
            var serverName   = ""
            for (displayName, serverInfo) in availableServersDict {
                if let d = serverInfo["date"] as? Date, d < lastUsedDate {
                    lastUsedDate = d; serverName = displayName
                } else if serverInfo["date"] == nil {
                    serverName = displayName; break
                }
            }
            availableServersDict[serverName] = nil
        }
        var foundServer = false
        for (displayName, serverInfo) in availableServersDict {
            if displayName != "" {
                sortedDisplayNames.append(displayName)
                if (serverInfo["server"] as? String) == lastServer && lastServer != "" {
                    foundServer = true
                    lastServerDN = displayName
                }
            } else {
                availableServersDict[displayName] = nil
            }
        }
        if !foundServer && lastServer != "" {
            let dn = lastServer.fqdnFromUrl
            availableServersDict[dn] = ["server": lastServer as AnyObject, "date": Date() as AnyObject]
            lastServerDN = dn
            sortedDisplayNames.append(dn)
        }

        saveCreds_button.state = NSControl.StateValue(defaults.integer(forKey: "saveCreds"))

        // 5. Populate UI based on current mode
        if useApiClient == 0 {
            setSelectServerButton(listOfNames: sortedIntegrationNames)
            if sortedIntegrationNames.isEmpty {
                selectServer_Button.selectItem(withTitle: addItemTitle)
                login_Button.title = "Add"
                selectServer_Action(self)
            } else {
                if lastIntegrationDN != "", sortedIntegrationNames.firstIndex(of: lastIntegrationDN) != nil {
                    selectServer_Button.selectItem(withTitle: lastIntegrationDN)
                }
                if lastTenantId != "" {
                    jamfProServer_textfield.stringValue   = lastTenantId
                    jamfProUsername_textfield.stringValue = lastClientId
                    credentialsCheck()
                }
            }
        } else {
            setSelectServerButton(listOfNames: sortedDisplayNames)
            if sortedDisplayNames.isEmpty {
                selectServer_Button.selectItem(withTitle: addItemTitle)
                login_Button.title = "Add"
                selectServer_Action(self)
            } else {
                if sortedDisplayNames.firstIndex(of: lastServerDN) != nil {
                    selectServer_Button.selectItem(withTitle: lastServerDN)
                }
                jamfProServer_textfield.stringValue = lastServer
                if lastServer != "" {
                    jamfProUsername_textfield.stringValue = defaults.string(forKey: "username") ?? ""
                    credentialsCheck()
                }
            }
        }

        // 6. Region row (Platform API only)
        setupRegionRow()
        updateRegionRowVisibility()

        NSApplication.shared.activate(ignoringOtherApps: true)
    }
    
    
    private func migrateAppGroupSettings() {
        let _sharedContainerUrl     = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.\(appsGroupId)")
        let _sharedSettingsPlistUrl = (_sharedContainerUrl?.appendingPathComponent("Library/Preferences/group.\(appsGroupId).plist"))!
        WriteToLog.shared.message("[migrateAppGroupSettings] _sharedSettingsPlistUrl: \(_sharedSettingsPlistUrl.path(percentEncoded: false))")
//        print("[migrateSettings] sharedSettingsPlistUrl: \(sharedSettingsPlistUrl.path(percentEncoded: false))")
//        print("[migrateSettings] _sharedSettingsPlistUrl: \(_sharedSettingsPlistUrl.path(percentEncoded: false))")
        
        if !FileManager.default.fileExists(atPath: sharedSettingsPlistUrl.path(percentEncoded: false)) {
            WriteToLog.shared.message("creating settings file")
            sharedDefaults!.set(Date(), forKey: "created")
            sharedDefaults!.set([String:AnyObject](), forKey: "serversDict")
        }
        var serversDict = sharedDefaults!.object(forKey: "serversDict") as? [String:AnyObject] ?? [String:AnyObject]()
        
        WriteToLog.shared.message("[migrateAppGroupSettings] app group settings file: \(sharedSettingsPlistUrl.path(percentEncoded: false))")
        let settingsMigrated = sharedDefaults!.object(forKey: "migrated") as? String ?? "false"
        WriteToLog.shared.message("[migrateAppGroupSettings] settingsMigrated: \(settingsMigrated)")
        if settingsMigrated != "true" {
            if FileManager.default.fileExists(atPath: _sharedSettingsPlistUrl.path(percentEncoded: false)) {
                WriteToLog.shared.message("[migrateAppGroupSettings] legacy settings file exists")
                
                if let oldPrefs = UserDefaults(suiteName: "group.\(appsGroupId)") {
                    let _serversDict = oldPrefs.dictionary(forKey: "serversDict") ?? [String:AnyObject]()
                    for (serverName, serverData) in _serversDict {
                        if (serversDict[serverName] == nil) {
                            serversDict[serverName] = serverData as AnyObject
                        }
                    }
                    sharedDefaults!.set(serversDict, forKey: "serversDict")
                    sharedDefaults!.set("true" as AnyObject, forKey: "migrated")
                    WriteToLog.shared.message("[migrateAppGroupSettings] migrated settings")
                } else {
                    WriteToLog.shared.message("[migrateAppGroupSettings] unable to read legacy settings")
                    WriteToLog.shared.message("[migrateAppGroupSettings] failed to migrate settings")
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
