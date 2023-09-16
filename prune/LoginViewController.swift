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
    func sendLoginInfo(loginInfo: (String,String,String,Int))
}

class LoginViewController: NSViewController, NSTextFieldDelegate {
    
    @IBOutlet var server_textfield: NSTextField!
    @IBOutlet var username_textfield: NSTextField!
    @IBOutlet var password_textfield: NSTextField!
    
    @IBOutlet var saveCreds_Button: NSButton!
    
    var delegate: SendingLoginInfoDelegate? = nil
    
    var accountsDict = [String:String]()
    
    @IBAction func saveCreds_Action(_ sender: Any) {
        if saveCreds_Button.state.rawValue == 1 {
            userDefaults.set(1, forKey: "saveCreds")
        } else {
            userDefaults.set(0, forKey: "saveCreds")
        }
    }
    
    func controlTextDidEndEditing(_ obj: Notification) {
        if let textField = obj.object as? NSTextField {
            switch textField.identifier!.rawValue {
            case "server":
                let accountsDict = Credentials().retrieve(service: server_textfield.stringValue.fqdnFromUrl, account: username_textfield.stringValue)
                
                if accountsDict.count == 1 {
                    for (username, password) in accountsDict {
                        username_textfield.stringValue = username
                        password_textfield.stringValue = password
                    }
//                    saveCreds_button.state = NSControl.StateValue(rawValue: 1)
//                    setWindowSize(setting: 0)
                } else {
//                    username_textfield.stringValue = ""
                    password_textfield.stringValue = ""
//                    if login_Button.title == "Login" {
//                        setWindowSize(setting: 1)
//                    } else {
//                        setWindowSize(setting: 2)
//                    }
                }
            case "username":
                if username_textfield.stringValue != "" {
                    let accountDict = Credentials().retrieve(service: server_textfield.stringValue.fqdnFromUrl, account: username_textfield.stringValue)
                    
                    password_textfield.stringValue = ""
                    if accountDict.count != 0 {
                        for (username, password) in accountDict {
                            if username == username_textfield.stringValue {
                                password_textfield.stringValue = password
                                break
                            }
                        }
                    }
                }
            default:
                break
            }
        }
    }

    @IBAction func login_action(_ sender: Any) {
        let dataToBeSent = (server_textfield.stringValue, username_textfield.stringValue, password_textfield.stringValue,saveCreds_Button.state.rawValue)
        delegate?.sendLoginInfo(loginInfo: dataToBeSent)
        dismiss(self)
    }
    
    @IBAction func quit_Action(_ sender: Any) {
        dismiss(self)
        NSApplication.shared.terminate(self)
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        server_textfield.delegate = self
        username_textfield.delegate = self
        
        server_textfield.stringValue = userDefaults.object(forKey: "server") as? String ?? ""
        if (server_textfield.stringValue != "") {
            let accountDict = Credentials().retrieve(service: server_textfield.stringValue.fqdnFromUrl, account: username_textfield.stringValue)
            password_textfield.stringValue = ""
            if accountDict.count > 0 {
                for (username, password) in accountDict {
                    if username == username_textfield.stringValue || accountDict.count == 1 {
                        username_textfield.stringValue = username
                        password_textfield.stringValue = password
                        break
                    }
                }
            } else {
                username_textfield.stringValue = userDefaults.object(forKey: "username") as? String ?? ""
            }
        } else {
            username_textfield.stringValue = userDefaults.object(forKey: "username") as? String ?? ""
        }
        saveCreds_Button.state = NSControl.StateValue(rawValue: userDefaults.object(forKey: "saveCreds") as? Int ?? 0)
        
        // bring app to foreground
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
    
}
