//
//  JamfPro.swift
//  prune
//
//  Created by Leslie Helou on 12/11/19.
//  Copyright © 2019 Leslie Helou. All rights reserved.
//

import Foundation

class JamfPro: NSObject, URLSessionDelegate {
    
    var renewQ = DispatchQueue(label: "com.jamfpse.token_refreshQ", qos: DispatchQoS.background)   // running background process for refreshing token
    
    func getVersion(jpURL: String, basicCreds: String, completion: @escaping (_ jpversion: String) -> Void) {
        var versionString  = ""
        let semaphore      = DispatchSemaphore(value: 0)
        
        OperationQueue().addOperation {
            let encodedURL     = NSURL(string: "\(jpURL)/JSSCheckConnection")
            let request        = NSMutableURLRequest(url: encodedURL! as URL)
            request.httpMethod = "GET"
            let configuration  = URLSessionConfiguration.default
            let session = Foundation.URLSession(configuration: configuration, delegate: self, delegateQueue: OperationQueue.main)
            let task = session.dataTask(with: request as URLRequest, completionHandler: { [self]
                (data, response, error) -> Void in
//                if let httpResponse = response as? HTTPURLResponse {
                    versionString = String(data: data!, encoding: .utf8) ?? ""
//                    print("httpResponse: \(httpResponse)")
//                    print("raw versionString: \(versionString)")
                    if versionString != "" {
                        let tmpArray = versionString.components(separatedBy: ".")
                        if tmpArray.count > 2 {
                            for i in 0...2 {
                                switch i {
                                case 0:
                                    JamfProServer.majorVersion = Int(tmpArray[i]) ?? 0
                                case 1:
                                    JamfProServer.minorVersion = Int(tmpArray[i]) ?? 0
                                case 2:
                                    let tmp = tmpArray[i].components(separatedBy: "-")
                                    JamfProServer.patchVersion = Int(tmp[0]) ?? 0
                                    if tmp.count > 1 {
                                        JamfProServer.build = tmp[1]
                                    }
                                default:
                                    break
                                }
                            }
                        }
                    }
//                }
                WriteToLog().message(theString: "[JamfPro.getVersion] Jamf Pro Version: \(versionString)")
                if ( JamfProServer.majorVersion > 9 && JamfProServer.minorVersion > 34 ) {
                    getToken(serverUrl: jpURL, whichServer: "source", base64creds: basicCreds) {
                        (returnedToken: String) in
                        JamfProServer.authType  = "Bearer"
                        completion("\(JamfProServer.majorVersion).\(JamfProServer.minorVersion).\(JamfProServer.patchVersion)")
                    }
                } else {
                    JamfProServer.authType  = "Basic"
                    JamfProServer.authCreds = basicCreds
                    completion("\(JamfProServer.majorVersion).\(JamfProServer.minorVersion).\(JamfProServer.patchVersion)")
                }
            })  // let task = session - end
            task.resume()
            semaphore.wait()
        }
    }
    
//    func get(serverUrl: String, whichServer: String, base64creds: String) {
    func getToken(serverUrl: String, whichServer: String, base64creds: String, completion: @escaping (_ returnedToken: String) -> Void) {
        
//        print("\(serverUrl.prefix(4))")
        if serverUrl.prefix(4) != "http" {
            completion("skipped")
            return
        }
        URLCache.shared.removeAllCachedResponses()
                
        var tokenUrlString = "\(serverUrl)/api/v1/auth/token"
        tokenUrlString     = tokenUrlString.replacingOccurrences(of: "//api", with: "/api")
    //        print("\(tokenUrlString)")
        
        let tokenUrl       = URL(string: "\(tokenUrlString)")
        let configuration  = URLSessionConfiguration.ephemeral
        var request        = URLRequest(url: tokenUrl!)
        request.httpMethod = "POST"
        
        WriteToLog().message(theString: "[JamfPro.getToken] Attempting to retrieve token from \(String(describing: tokenUrl!)).")
        
        configuration.httpAdditionalHeaders = ["Authorization" : "Basic \(base64creds)", "Content-Type" : "application/json", "Accept" : "application/json"]
        let session = Foundation.URLSession(configuration: configuration, delegate: self as URLSessionDelegate, delegateQueue: OperationQueue.main)
        let task = session.dataTask(with: request as URLRequest, completionHandler: {
            (data, response, error) -> Void in
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode >= 200 && httpResponse.statusCode <= 299 {
                    let json = try? JSONSerialization.jsonObject(with: data!, options: .allowFragments)
                    if let endpointJSON = json! as? [String: Any], let _ = endpointJSON["token"], let _ = endpointJSON["expires"] {
                        token.sourceServer = endpointJSON["token"] as! String
                        token.sourceExpires  = "\(endpointJSON["expires"] ?? "")"
//                      print("\n[JamfPro] token for \(serverUrl): \(token.sourceServer)")
                        
//                      if LogLevel.debug { WriteToLog().message(stringOfText: "[JamfPro.getToken] Retrieved token: \(token)") }
//                      print("[JamfPro] result of token request: \(endpointJSON)")
                        WriteToLog().message(theString: "[JamfPro.getToken] new token created.")
                        if JamfProServer.authType == "Bearer" {
                            self.refresh(server: serverUrl, whichServer: whichServer, b64Creds: base64creds)
                        }
                        completion("success")
                        return
                    } else {    // if let endpointJSON error
                        WriteToLog().message(theString: "[JamfPro.getToken] JSON error.\n\(String(describing: json))")
                        completion("failed")
                        return
                    }
                } else {    // if httpResponse.statusCode <200 or >299
                    WriteToLog().message(theString: "[JamfPro.getToken] response error: \(httpResponse.statusCode).")
                    completion("failed")
                    return
                }
            } else {
                WriteToLog().message(theString: "[JamfPro.getToken] token response error.  Verify url and port.")
                completion("failed")
                return
            }
        })
        task.resume()
    }
    
    func refresh(server: String, whichServer: String, b64Creds: String) {
        renewQ.async { [self] in
        sleep(1200) // 20 minutes
            sleep(token.refreshInterval)
            getToken(serverUrl: server, whichServer: whichServer, base64creds: b64Creds) {
                (result: String) in
//                print("[JamfPro.refresh] returned: \(result)")
            }
        }
    }
}
