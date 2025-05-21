//
//  Credentials2.swift
//  prune
//
//  Created by Leslie Helou on 9/20/19.
//  Copyright © 2019 jamf. All rights reserved.
//

import Foundation
import Security

let kSecAttrAccountString          = NSString(format: kSecAttrAccount)
let kSecValueDataString            = NSString(format: kSecValueData)
let kSecClassGenericPasswordString = NSString(format: kSecClassGenericPassword)
let keychainQ                      = DispatchQueue(label: "com.jamf.prune", qos: DispatchQoS.background)
let prefix                         = AppInfo.name.lowercased()
let sharedPrefix                   = "JPMA"
let accessGroup                    = "PS2F6S478M.jamfie.SharedJPMA"
var useApiClient                   = 0

// old entry: prune - <server fqdn>

class Credentials {
    
    var userPassDict = [String:String]()
    var keychainItemName = ""
    
    func save(service: String, account: String, credential: String, whichServer: String = "source") {
        if service != "" && account != "" {
            
            let keychainItemName = ( useApiClient == 0 ) ? "JPMA-" + service:"\(prefix)-apiClient-" + service
            
//            print("[Credentials.save] save/update keychain item \(keychainItemName)")

            if let password = credential.data(using: String.Encoding.utf8) {
                keychainQ.async { [self] in
                    var keychainQuery: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                                        kSecAttrService as String: keychainItemName,
                                                        kSecAttrAccessGroup as String: accessGroup,
                                                        kSecUseDataProtectionKeychain as String: true,
                                                        kSecAttrAccount as String: account,
                                                        kSecValueData as String: password]
                    
                    // see if credentials already exist for server
                    let accountCheck = checkExisting(service: keychainItemName, account: account)
                    if accountCheck.count == 0 {
                        // try to add new credentials, if account exists we'll try updating it
                        let addStatus = SecItemAdd(keychainQuery as CFDictionary, nil)
                        if (addStatus != errSecSuccess) {
                            if let addErr = SecCopyErrorMessageString(addStatus, nil) {
                                print("[addStatus] Write failed for service \(service), account \(account): \(addErr)")
                                WriteToLog.shared.message("Write failed for service \(service), account \(account): \(addErr).")
                            }
                        }
                    } else {
                        // credentials already exist, try to update
                        keychainQuery = [kSecClass as String: kSecClassGenericPasswordString,
                                         kSecAttrService as String: keychainItemName,
                                         kSecAttrAccessGroup as String: accessGroup,
                                         kSecUseDataProtectionKeychain as String: true,
                                         kSecMatchLimit as String: kSecMatchLimitOne,
                                         kSecReturnAttributes as String: true]
                        if credential != accountCheck[account] {
                            let updateStatus = SecItemUpdate(keychainQuery as CFDictionary, [kSecValueDataString:password] as [NSString : Any] as CFDictionary)
                            if (updateStatus != errSecSuccess) {
                                if let updateErr = SecCopyErrorMessageString(updateStatus, nil) {
                                    WriteToLog.shared.message("keychain item for service \(service), account \(account), failed to update.")
                                } else {
                                    WriteToLog.shared.message("keychain item for service \(service), account \(account), has been updated.")
                                }
                            }
                        } else {
                            WriteToLog.shared.message("keychain item for service \(service), account \(account), is up-to-date.")
                        }
                    }
                }
            }
        }
    }   // func save - end
    
    private func checkExisting(service: String, account: String) -> [String:String] {
                
        userPassDict.removeAll()
        let keychainQuery: [String: Any] = [kSecClass as String: kSecClassGenericPasswordString,
                                            kSecAttrAccessGroup as String: accessGroup,
                                            kSecAttrService as String: service,
                                            kSecAttrAccount as String: account,
                                            kSecMatchLimit as String: kSecMatchLimitOne,
                                            kSecReturnAttributes as String: true,
                                            kSecReturnData as String: true]
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(keychainQuery as CFDictionary, &item)
        guard status != errSecItemNotFound else {
//            print("[Credentials.oldItemLookup] lookup error occurred: \(status.description)")
            return [:]
        }
        guard status == errSecSuccess else { return [:] }
        
        guard let existingItem = item as? [String : Any],
            let passwordData = existingItem[kSecValueData as String] as? Data,
//            let account = existingItem[kSecAttrAccount as String] as? String,
            let password = String(data: passwordData, encoding: String.Encoding.utf8)
        else {
            return [:]
        }
        userPassDict[account] = password
        return userPassDict
    }
    
    func retrieve(service: String, account: String, whichServer: String = "source") -> [String:String] {
        
//        print("[Credentials.retrieve] start search for: \(service)")

        var keychainResult = [String:String]()
        var theService = service
             
        userPassDict.removeAll()
        
        var keychainItemName = ( useApiClient == 0 ) ? "JPMA-" + service:"\(prefix)-apiClient-" + service
//        print("[credentials] keychainItemName: \(keychainItemName)")
        // look for common keychain item
        keychainResult = itemLookup(service: keychainItemName)
        // look for legacy keychain item
        if keychainResult.count == 0 && useApiClient == 0 {
            keychainItemName = "\(prefix) - \(service)"
            keychainResult   = oldItemLookup(service: keychainItemName)
        }
        
        return keychainResult
    }
    
    private func itemLookup(service: String) -> [String:String] {
        
//        print("[Credentials.itemLookup] start search for: \(service)")
   
        let keychainQuery: [String: Any] = [kSecClass as String: kSecClassGenericPasswordString,
                                            kSecAttrService as String: service,
                                            kSecAttrAccessGroup as String: accessGroup,
                                            kSecUseDataProtectionKeychain as String: true,
                                            kSecMatchLimit as String: kSecMatchLimitAll,
                                            kSecReturnAttributes as String: true,
                                            kSecReturnData as String: true]
        
        var items_ref: CFTypeRef?
        
        let status = SecItemCopyMatching(keychainQuery as CFDictionary, &items_ref)
//        let status = SecItemCopyMatching(keychainQuery as CFDictionary, &item)
        guard status != errSecItemNotFound else {
            print("[Credentials.itemLookup] lookup error occurred for \(service): \(status.description)\n")
            return [:]
            
        }
        guard status == errSecSuccess else { return [:] }
        
        guard let items = items_ref as? [[String: Any]] else {
//            print("[Credentials.itemLookup] unable to read keychain item: \(service)")
            return [:]
        }
        for item in items {
            if let account = item[kSecAttrAccount as String] as? String, let passwordData = item[kSecValueData as String] as? Data {
                let password = String(data: passwordData, encoding: String.Encoding.utf8)
                userPassDict[account] = password ?? ""
            }
        }

//        print("[Credentials.itemLookup] keychain item count: \(userPassDict.count) for \(service)")
        return userPassDict
    }
    
    private func oldItemLookup(service: String) -> [String:String] {
        
    //        print("[Credentials.itemLookup] start search for: \(service)")

        let keychainQuery: [String: Any] = [kSecClass as String: kSecClassGenericPasswordString,
                                            kSecAttrService as String: service,
                                            kSecMatchLimit as String: kSecMatchLimitOne,
                                            kSecReturnAttributes as String: true,
                                            kSecReturnData as String: true]
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(keychainQuery as CFDictionary, &item)
        guard status != errSecItemNotFound else {
//            print("[Credentials.oldItemLookup] lookup error occurred for \(service): \(status.description)")
            return [:]
        }
        guard status == errSecSuccess else { return [:] }
        
        guard let existingItem = item as? [String : Any],
            let passwordData = existingItem[kSecValueData as String] as? Data,
            let account = existingItem[kSecAttrAccount as String] as? String,
            let password = String(data: passwordData, encoding: String.Encoding.utf8)
            else {
            return [:]
        }
        userPassDict[account] = password
        return userPassDict
    }
}
