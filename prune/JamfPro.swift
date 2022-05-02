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

    var theUapiQ = OperationQueue() // create operation queue for API calls
    
    func jpapiAction(serverUrl: String, endpoint: String, apiData: [String:Any], id: String, token: String, method: String, completion: @escaping (_ returnedJSON: [String: Any]) -> Void) {
        
        if method.lowercased() == "skip" {
            completion(["JPAPI_result":"failed", "JPAPI_response":000])
            return
        }
        
        URLCache.shared.removeAllCachedResponses()
        var path = ""

        switch endpoint {
        case  "buildings", "csa/token", "icon", "jamf-pro-version":
            path = "v1/\(endpoint)"
        default:
            path = "v2/\(endpoint)"
        }

        var urlString = "\(serverUrl)/api/\(path)"
        urlString     = urlString.replacingOccurrences(of: "//api", with: "/api")
        if id != "" && id != "0" {
            urlString = urlString + "/\(id)"
        }
//        print("[Jpapi] urlString: \(urlString)")
        
        let url            = URL(string: "\(urlString)")
        let configuration  = URLSessionConfiguration.ephemeral
        var request        = URLRequest(url: url!)
        switch method.lowercased() {
        case "get":
            request.httpMethod = "GET"
        case "create", "post":
            request.httpMethod = "POST"
        default:
            request.httpMethod = "PUT"
        }
        
        if apiData.count > 0 {
            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: apiData, options: .prettyPrinted)
            } catch let error {
                print(error.localizedDescription)
            }
        }
        
//        print("[Jpapi.action] Attempting \(method) on \(urlString).")
        
        configuration.httpAdditionalHeaders = ["Authorization" : "Bearer \(token)", "Content-Type" : "application/json", "Accept" : "application/json"]
        let session = Foundation.URLSession(configuration: configuration, delegate: self as URLSessionDelegate, delegateQueue: OperationQueue.main)
        let task = session.dataTask(with: request as URLRequest, completionHandler: {
            (data, response, error) -> Void in
            session.finishTasksAndInvalidate()
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode >= 200 && httpResponse.statusCode <= 299 {
                    let json = try? JSONSerialization.jsonObject(with: data!, options: .allowFragments)
                    if let endpointJSON = json! as? [String:Any] {
                        completion(endpointJSON)
                        return
                    } else {    // if let endpointJSON error
                        completion(["JPAPI_result":"failed", "JPAPI_response":httpResponse.statusCode])
                        return
                    }
                } else {    // if httpResponse.statusCode <200 or >299
                    completion(["JPAPI_result":"failed", "JPAPI_method":request.httpMethod ?? method, "JPAPI_response":httpResponse.statusCode, "JPAPI_server":urlString, "JPAPI_token":token])
                    return
                }
            } else {
                completion([:])
                return
            }
        })
        task.resume()
        
    }
    
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
            session.finishTasksAndInvalidate()
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode >= 200 && httpResponse.statusCode <= 299 {
                    let json = try? JSONSerialization.jsonObject(with: data!, options: .allowFragments)
                    if let endpointJSON = json! as? [String: Any], let _ = endpointJSON["token"], let _ = endpointJSON["expires"] {
                        JamfProServer.validToken  = true
                        JamfProServer.base64Creds = base64creds
                        JamfProServer.authCreds   = endpointJSON["token"] as! String
                        token.sourceExpires       = "\(endpointJSON["expires"] ?? "")"
//                      print("\n[JamfPro] token for \(serverUrl): \(token.sourceServer)")
                        
//                      if LogLevel.debug { WriteToLog().message(stringOfText: "[JamfPro.getToken] Retrieved token: \(token)") }
//                      print("[JamfPro] result of token request: \(endpointJSON)")
                        
                        if JamfProServer.version == "" {
                            // get Jamf Pro version - start
                            self.jpapiAction(serverUrl: serverUrl, endpoint: "jamf-pro-version", apiData: [:], id: "", token: JamfProServer.authCreds, method: "GET") {
                                (result: [String:Any]) in
                                let versionString = result["version"] as! String
            
                                if versionString != "" {
                                    WriteToLog().message(theString: "[JamfPro.getVersion] Jamf Pro Version: \(versionString)")
                                    JamfProServer.version = versionString
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
                                        if ( JamfProServer.majorVersion > 9 && JamfProServer.minorVersion > 34 ) {
                                            JamfProServer.authType = "Bearer"
                                            WriteToLog().message(theString: "[JamfPro.getVersion] \(serverUrl) set to use OAuth")
                                            
                                        } else {
                                            JamfProServer.authType  = "Basic"
                                            JamfProServer.authCreds = base64creds
                                            WriteToLog().message(theString: "[JamfPro.getVersion] \(serverUrl) set to use Basic")
                                        }
                                        if JamfProServer.authType == "Bearer" {
                                            self.refresh(server: serverUrl, whichServer: whichServer, b64Creds: base64creds)
                                        }
                                        completion("success")
                                        return
                                    }
                                }
                            }
                            // get Jamf Pro version - end
                        } else {
                            if JamfProServer.authType == "Bearer" {
                                WriteToLog().message(theString: "[JamfPro.getVersion] call token refresh process for \(serverUrl)")
                                self.refresh(server: serverUrl, whichServer: whichServer, b64Creds: JamfProServer.base64Creds)
                            }
                            completion("success")
                            return
                        }
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
//        sleep(1200) // 20 minutes
            sleep(token.refreshInterval)
            JamfProServer.validToken = false
            getToken(serverUrl: server, whichServer: whichServer, base64creds: b64Creds) {
                (result: String) in
//                print("[JamfPro.refresh] returned: \(result)")
            }
        }
    }
}
