//
//  Copyright 2026 Jamf. All rights reserved.
//

import Foundation

class JamfPro: NSObject, URLSessionDelegate {
    
    static let shared = JamfPro()
    private override init() { }
    
    var theUapiQ = OperationQueue() // create operation queue for API calls
    var clientType = "username / password"
        
    func jpapiAction(serverUrl: String, endpoint: String, apiData: [String:Any], id: String = "", token: String = "", method: String, completion: @escaping (_ returnedJSON: [String: Any]) -> Void) {
        getToken(serverUrl: JamfProServer.source, whichServer: "source", base64creds: JamfProServer.base64Creds) { [self]
            (result: (Int,String)) in
            let (statusCode, theResult) = result
            
//            print("[jpapiAction]             method: \(method)")
//            print("[jpapiAction]           endpoint: \(endpoint)")
//            print("[jpapiAction] token check result: \(statusCode)")
            
            if theResult == "success" {
                
                if method.lowercased() == "skip" {
                    completion(["JPAPI_result":"failed", "JPAPI_response":000])
                    return
                }
                
                URLCache.shared.removeAllCachedResponses()
                var path = ""
                
                switch endpoint {
                case "app-installers/deployments", "buildings", "csa/token", "icon", "jamf-pro-version", "auth/invalidate-token":
                    path = "v1/\(endpoint)"
                default:
                    path = "v2/\(endpoint)"
                }
                
                var urlString = "\(serverUrl)/api/\(path)"
                urlString     = urlString.replacingOccurrences(of: "//api", with: "/api")
                if id != "" && id != "0" {
                    urlString = urlString + "/\(id)"
                }
//                print("[Jpapi] urlString: \(urlString)")
                
                let url            = URL(string: "\(urlString)")
                let configuration  = URLSessionConfiguration.ephemeral
                var request        = URLRequest(url: url!)
                request.httpMethod = method.uppercased()
                
                if apiData.count > 0 {
                    do {
                        request.httpBody = try JSONSerialization.data(withJSONObject: apiData, options: .prettyPrinted)
                    } catch let error {
                        print(error.localizedDescription)
                    }
                }
                
//                print("[jpapiAction] Attempting \(method) on \(urlString).")
                
                configuration.httpAdditionalHeaders = ["Authorization" : "Bearer \(JamfProServer.accessToken)", "Content-Type" : "application/json", "Accept" : "application/json", "User-Agent" : AppInfo.userAgentHeader]
                let session = Foundation.URLSession(configuration: configuration, delegate: self as URLSessionDelegate, delegateQueue: OperationQueue.main)
                let task = session.dataTask(with: request as URLRequest, completionHandler: {
                    (data, response, error) -> Void in
                    session.finishTasksAndInvalidate()
                    if let httpResponse = response as? HTTPURLResponse {
//                        print("[jpapiAction] \(endpoint) - status code \(httpResponse.statusCode).")
                        if httpResponse.statusCode >= 200 && httpResponse.statusCode <= 299 {
                            let json = try? JSONSerialization.jsonObject(with: data!, options: .allowFragments)
//                            print("[Jpapi] json: \(String(describing: json))")
                            if let endpointJSON = json as? [String:Any] {
                                completion(endpointJSON)
                                return
                            } else {    // if let endpointJSON error
                                if endpoint == "auth/invalidate-token" {
                                    if httpResponse.statusCode == 204 {
                                        completion(["JPAPI_result":"token terminated", "JPAPI_response":httpResponse.statusCode])
                                    } else {
                                        completion(["JPAPI_result":"token termination failed", "JPAPI_response":httpResponse.statusCode])
                                    }
                                } else {
                                    completion(["JPAPI_result":"failed converting \(String(describing: json)) to JSON", "JPAPI_response":httpResponse.statusCode])
                                }
                                return
                            }
                        } else {    // if httpResponse.statusCode <200 or >299
                            if endpoint == "auth/invalidate-token" {
                                completion(["JPAPI_result":"token termination failed - status code: \(httpResponse.statusCode)", "JPAPI_response":httpResponse.statusCode])
                            } else {
                                completion(["JPAPI_result":"failed", "JPAPI_method":request.httpMethod ?? method, "JPAPI_response":httpResponse.statusCode, "JPAPI_server":urlString, "JPAPI_token":token])
                            }
                            return
                        }
                    } else {
                        completion([:])
                        return
                    }
                })
                task.resume()
            } else {
                completion(["JPAPI_result":"failed to generate or terminate token", "JPAPI_method": method, "JPAPI_response": statusCode])
            }
        }
    }
    
    func apiGetAll(serverUrl: String, endpoint: String, completion: @escaping (_ returnedJSON: (String,[[String: Any]])) -> Void) {
        getToken(serverUrl: JamfProServer.source, whichServer: "source", base64creds: JamfProServer.base64Creds) { [self]
            (result: (Int,String)) in
            let (statusCode, theResult) = result
//            print("[jpapiAction] token check")
            if theResult == "success" {
                
                URLCache.shared.removeAllCachedResponses()
                var path = ""
                
                switch endpoint {
                case  "buildings":
                    path = "v1/\(endpoint)"
                default:
                    path = "v2/\(endpoint)"
                }
                
                var urlString = "\(serverUrl)/api/\(path)"
                urlString     = urlString.replacingOccurrences(of: "//api", with: "/api")
                
//                print("[Jpapi.apiGetAll] urlString: \(urlString)")
                
                let url            = URL(string: "\(urlString)")
                let configuration  = URLSessionConfiguration.ephemeral
                var request        = URLRequest(url: url!)
                
                request.httpMethod = "GET"
                
                //        print("[apiGetAll] Attempting \(method) on \(urlString).")
                
                configuration.httpAdditionalHeaders = ["Authorization" : "Bearer \(JamfProServer.accessToken)", "Content-Type" : "application/json", "Accept" : "application/json", "User-Agent" : AppInfo.userAgentHeader]
                let session = Foundation.URLSession(configuration: configuration, delegate: self as URLSessionDelegate, delegateQueue: OperationQueue.main)
                let task = session.dataTask(with: request as URLRequest, completionHandler: {
                    (data, response, error) -> Void in
                    session.finishTasksAndInvalidate()
                    if let httpResponse = response as? HTTPURLResponse {
                        if httpResponse.statusCode >= 200 && httpResponse.statusCode <= 299 {
                            let json = try? JSONSerialization.jsonObject(with: data!, options: .allowFragments)
                            if let endpointJSON = json as? [[String:Any]] {
                                if endpoint == "app-instalers" {
                                    completion(("success", endpointJSON))
                                } else {
                                    completion(("success", endpointJSON))
                                }
                                return
                            } else {
                                completion(("failed",[["JPAPI_response":httpResponse.statusCode]]))
                                return
                            }
                        } else {    // if httpResponse.statusCode <200 or >299
                            completion(("failed",[["JPAPI_response":httpResponse.statusCode, "JPAPI_server":urlString]]))
                            return
                        }
                    } else {
                        completion(("failed",[[:]]))
                        return
                    }
                })
                task.resume()
            } else {
                completion(("failed",[["JPAPI_response": statusCode]]))
            }
        }
    }
    
    var components = DateComponents()
    
    func getToken(serverUrl: String, whichServer: String = "source", base64creds: String, completion: @escaping (_ authResult: (Int,String)) -> Void) {

        URLCache.shared.removeAllCachedResponses()

        var tokenUrlString = "\(serverUrl)/api/v1/auth/token"

        var apiClient = ( defaults.integer(forKey: "\(whichServer)UseApiClient") == 1 ) ? true:false
        
        //        WriteToLog.shared.message("[getToken] token for \(whichServer) server: \(serverUrl)")
//        print("[getToken] JamfProServer.username[\(whichServer)]: \(String(describing: JamfProServer.username))")
//        print("[getToken] JamfProServer.password[\(whichServer)]: \(String(describing: JamfProServer.password.prefix(1)))********")
//        print("[getToken]   JamfProServer.server[\(whichServer)]: \(String(describing: JamfProServer.source))")
//        print("[getToken]                         use api client: \(apiClient)")

        if apiClient {
            tokenUrlString = "\(serverUrl)/api/oauth/token"
        }

        tokenUrlString     = tokenUrlString.replacingOccurrences(of: "//api", with: "/api")
        //        print("[getToken] tokenUrlString: \(tokenUrlString)")

        let tokenUrl       = URL(string: "\(tokenUrlString)")
        guard let _ = URL(string: "\(tokenUrlString)") else {
            print("problem constructing the URL from \(tokenUrlString)")
            WriteToLog.shared.message("[getToken] problem constructing the URL from \(tokenUrlString)")
            completion((500, "failed"))
            return
        }
        //        print("[getToken] tokenUrl: \(tokenUrl!)")
        let configuration  = URLSessionConfiguration.ephemeral
        var request        = URLRequest(url: tokenUrl!)
        request.httpMethod = "POST"

        let (_, _, _, tokenAgeInSeconds) = timeDiff(startTime: JamfProServer.tokenCreated)

//        print("[getToken] JamfProServer.validToken[\(whichServer)]: \(String(describing: JamfProServer.validToken))")
//        print("[getToken] \(whichServer) tokenAgeInSeconds: \(tokenAgeInSeconds)")
//        print("[getToken] \(whichServer)    token lifetime: \((JamfProServer.authExpires))")
//        print("[getToken] JamfProServer.currentCred[\(whichServer)]: \(String(describing: JamfProServer.currentCred))")

//        if !( JamfProServer.validToken && tokenAgeInSeconds < JamfProServer.authExpires ) || (JamfProServer.currentCred != base64creds) {
        if !( JamfProServer.validToken && tokenAgeInSeconds < JamfProServer.authExpires ) {
            WriteToLog.shared.message("[getToken] \(whichServer) tokenAgeInSeconds: \(tokenAgeInSeconds)")
            WriteToLog.shared.message("[getToken] Attempting to retrieve token from \(String(describing: tokenUrl))")
            
            if apiClient {
                clientType   = "API client / secret"
                let clientId = JamfProServer.username
                let secret   = JamfProServer.password
                let clientString = "grant_type=client_credentials&client_id=\(String(describing: clientId))&client_secret=\(String(describing: secret))"
        //                print("[getToken] \(whichServer) clientString: \(clientString)")

                let requestData  = clientString.data(using: .utf8)
                request.httpBody = requestData
                configuration.httpAdditionalHeaders = ["Content-Type" : "application/x-www-form-urlencoded", "Accept" : "application/json", "User-Agent" : AppInfo.userAgentHeader]
                JamfProServer.currentCred = clientString
            } else {
                clientType = "username / password"
                configuration.httpAdditionalHeaders = ["Authorization" : "Basic \(base64creds)", "Content-Type" : "application/json", "Accept" : "application/json", "User-Agent" : AppInfo.userAgentHeader]
                JamfProServer.currentCred = base64creds
            }
            WriteToLog.shared.message("[getToken] generate token using \(clientType)")
            
//            print("[getToken] \(whichServer) tokenUrlString: \(tokenUrlString)")
//            print("[getToken]    \(whichServer) base64creds: \(base64creds)")
            
            let session = Foundation.URLSession(configuration: configuration, delegate: self as URLSessionDelegate, delegateQueue: OperationQueue.main)
            let task = session.dataTask(with: request as URLRequest, completionHandler: { [self]
                (data, response, error) -> Void in
                session.finishTasksAndInvalidate()
                if let httpResponse = response as? HTTPURLResponse {
                    if httpSuccess.contains(httpResponse.statusCode) {
                        if let json = try? JSONSerialization.jsonObject(with: data!, options: .allowFragments) {
                            if let endpointJSON = json as? [String: Any] {
                                JamfProServer.accessToken   = apiClient ? (endpointJSON["access_token"] as? String ?? "")!:(endpointJSON["token"] as? String ?? "")!
//                                print("[getToken] \(whichServer) token request: \(String(describing: endpointJSON))")
                                JamfProServer.base64Creds = base64creds
                                if apiClient {
                                    JamfProServer.authExpires = (endpointJSON["expires_in"] as? Double ?? 60)!
//                                    print("[getToken] \(#line) \(whichServer) token expires in: \(String(describing: JamfProServer.authExpires))")
                                } else {
                                    JamfProServer.authExpires = (endpointJSON["expires"] as? Double ?? 20)!*60
                                }
                                JamfProServer.authExpires *= 0.75
//                                print("[getToken] \(#line) \(whichServer) token expires in: \(String(describing: JamfProServer.authExpires))")
                                JamfProServer.tokenCreated = Date()
                                JamfProServer.validToken   = true
                                JamfProServer.authType     = "Bearer"
                                
                                //                      print("[JamfPro] result of token request: \(endpointJSON)")
                                WriteToLog.shared.message("[getToken] new token created for \(serverUrl)")
                                
                                if JamfProServer.version == "" {
                                    // get Jamf Pro version - start
//                                    jpapiAction(serverUrl: serverUrl, endpoint: "jamf-pro-version", apiData: [:], id: "", token: JamfProServer.accessToken, method: "GET") {
                                    getVersion(serverUrl: serverUrl, endpoint: "jamf-pro-version", apiData: [:], id: "", token: JamfProServer.accessToken, method: "GET") {
                                        (result: [String:Any]) in
                                        let versionString = result["version"] as! String
                                        
                                        if versionString != "" {
                                            WriteToLog.shared.message("[JamfPro.getVersion] Jamf Pro Version: \(versionString)")
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
                                                if ( JamfProServer.majorVersion > 10 || (JamfProServer.majorVersion > 9 && JamfProServer.minorVersion > 34) ) {
                                                    JamfProServer.authType = "Bearer"
                                                    WriteToLog.shared.message("[JamfPro.getVersion] \(serverUrl) set to use OAuth")
                                                    
                                                } else {
                                                    JamfProServer.authType    = "Basic"
                                                    JamfProServer.accessToken = base64creds
                                                    WriteToLog.shared.message("[JamfPro.getVersion] \(serverUrl) set to use Basic")
                                                }
                                                completion((200, "success"))
                                                return
                                            }
                                        }
                                    }
                                    // get Jamf Pro version - end
                                } else {
                                    completion((200, "success"))
                                    return
                                }
                            } else {    // if let endpointJSON error
                                WriteToLog.shared.message("[getToken] JSON error.\n\(String(describing: json))")
                                JamfProServer.validToken  = false
                                completion((httpResponse.statusCode, "failed"))
                                return
                            }
                        } else {
                            // server down?
                            _ = Alert.shared.warning(header: "", message: "Failed to get an expected response from \(String(describing: serverUrl)).")
                            WriteToLog.shared.message("[TokenDelegate.getToken] Failed to get an expected response from \(String(describing: serverUrl)).  Status Code: \(httpResponse.statusCode)")
                            JamfProServer.validToken = false
                            completion((httpResponse.statusCode, "failed"))
                            return
                        }
                    } else {    // if httpResponse.statusCode <200 or >299
                        if JamfProServer.source.range(of: "/?failover=", options: [.regularExpression, .caseInsensitive]) != nil {
                            _ = Alert.shared.warning(header: "Authentication Failed", message: "Ensure you are not using the failover URL.")
                        } else {
                            _ = Alert.shared.display(header: "\(serverUrl)", message: "Failed to authenticate to \(serverUrl). \nStatus Code: \(httpResponse.statusCode)")
                            WriteToLog.shared.message("[getToken] Failed to authenticate to \(serverUrl).  Response error: \(httpResponse.statusCode)")
                        }
                        JamfProServer.validToken  = false
                        completion((httpResponse.statusCode, "failed"))
                        return
                    }
                } else {
                    _ = Alert.shared.display(header: "\(serverUrl)", message: "Failed to connect. \nUnknown error, verify url and port.")
                    WriteToLog.shared.message("[getToken] token response error from \(serverUrl).  Verify url and port")
                    JamfProServer.validToken  = false
                    completion((0, "failed"))
                    return
                }
            })
            task.resume()
        } else {
//            WriteToLog.shared.message("[getToken] Use existing token from \(String(describing: tokenUrl))")
            completion((200, "success"))
            return
        }
    }
    
    func getVersion(serverUrl: String, endpoint: String, apiData: [String:Any], id: String, token: String, method: String, completion: @escaping (_ returnedJSON: [String: Any]) -> Void) {
        
        if method.lowercased() == "skip" {
//            if LogLevel.debug { writeToLog.message(stringOfText: "[getVersion] skipping \(endpoint) endpoint with id \(id).") }
            let JPAPI_result = (endpoint == "auth/invalidate-token") ? "no valid token":"failed"
            completion(["JPAPI_result":JPAPI_result, "JPAPI_response":000])
            return
        }
        
        URLCache.shared.removeAllCachedResponses()
        var path = ""

        switch endpoint {
        case  "buildings", "csa/token", "icon", "jamf-pro-version", "auth/invalidate-token":
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
        let configuration  = URLSessionConfiguration.default
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
        
        WriteToLog.shared.message("[getVersion] Attempting \(method) on \(urlString).")
//        print("[getVersion] Attempting \(method) on \(urlString).")
        
        configuration.httpAdditionalHeaders = ["Authorization" : "Bearer \(token)", "Content-Type" : "application/json", "Accept" : "application/json", "User-Agent" : AppInfo.userAgentHeader]
        
        let session = Foundation.URLSession(configuration: configuration, delegate: self as URLSessionDelegate, delegateQueue: OperationQueue.main)
        let task = session.dataTask(with: request as URLRequest, completionHandler: {
            (data, response, error) -> Void in
            session.finishTasksAndInvalidate()
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode >= 200 && httpResponse.statusCode <= 299 {

                    let json = try? JSONSerialization.jsonObject(with: data!, options: .allowFragments)
                    if let endpointJSON = json as? [String:Any] {
                        completion(endpointJSON)
                        return
                    } else {    // if let endpointJSON error
                        if httpResponse.statusCode == 204 && endpoint == "auth/invalidate-token" {
                            completion(["JPAPI_result":"token terminated", "JPAPI_response":httpResponse.statusCode])
                        } else {
                            completion(["JPAPI_result":"failed", "JPAPI_response":httpResponse.statusCode])
                        }
                        return
                    }
                } else {    // if httpResponse.statusCode <200 or >299
                    WriteToLog.shared.message("[TokenDelegate.getVersion] Response error: \(httpResponse.statusCode).")
                    completion(["JPAPI_result":"failed", "JPAPI_method":request.httpMethod ?? method, "JPAPI_response":httpResponse.statusCode, "JPAPI_server":urlString, "JPAPI_token":token])
                    return
                }
            } else {
                WriteToLog.shared.message("[TokenDelegate.getVersion] GET response error.  Verify url and port.")
                completion([:])
                return
            }
        })
        task.resume()
    }
}
