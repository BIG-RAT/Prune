//
//  LoginViewController.swift
//  Prune
//
//  Created by Leslie Helou on 1/17/22.
//  Copyright © 2022 Leslie Helou. All rights reserved.
//

import Foundation

class LoginViewController: NSViewController {
        
    @IBOutlet var server_textfield: NSTextField!
    @IBOutlet var username_textfield: NSTextField!
    @IBOutlet var password_textfield: NSTextField!
    
//    @IBAction func login_action(_ sender: Any) {
//    }
    
    override func prepare(for segue: NSStoryboardSegue, sender: Any?) {

        self.view.window?.close()
        
        let viewController: ViewController = segue.destinationController as! ViewController
        
        viewController.currentServer = server_textfield.stringValue
        viewController.username = username_textfield.stringValue
        viewController.password = password_textfield.stringValue
        
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }


}


