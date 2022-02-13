//
//  Json.swift
//  prune
//
//  Created by Leslie Helou on 12/11/19.
//  Copyright © 2019 Leslie Helou. All rights reserved.
//

import Cocoa

class Json: NSObject, URLSessionDelegate {
    
    let defaults = UserDefaults.standard
    
    func getRecord(theServer: String, base64Creds: String, theEndpoint: String, completion: @escaping (_ result: [String:AnyObject]) -> Void) {

        
        let getRecordQ = OperationQueue() // DispatchQueue(label: "com.jamf.getRecordQ", qos: DispatchQoS.background)
    
        URLCache.shared.removeAllCachedResponses()
        var existingDestUrl = ""
        var authType        = "Bearer"
        
        switch theEndpoint {
        case "computer-prestages":
            existingDestUrl = "\(theServer)/api/v2/\(theEndpoint)"
            existingDestUrl = existingDestUrl.replacingOccurrences(of: "//api/v2", with: "/api/v2")
//            authType = "Bearer"
        default:
            existingDestUrl = "\(theServer)/JSSResource/\(theEndpoint)"
            existingDestUrl = existingDestUrl.replacingOccurrences(of: "//JSSResource", with: "/JSSResource")
            if JamfProServer.authType == "Basic" {
                authType = "Basic"
            }
        }
        
//        if LogLevel.debug { WriteToLog().message(stringOfText: "[Json.getRecord] Looking up: \(existingDestUrl)\n") }
        WriteToLog().message(theString: "[Json.getRecord] get existing endpoints URL: \(existingDestUrl)")
        let destEncodedURL = URL(string: existingDestUrl)
        let jsonRequest    = NSMutableURLRequest(url: destEncodedURL! as URL)
        
        let semaphore = DispatchSemaphore(value: 0)
        getRecordQ.maxConcurrentOperationCount = 4
        getRecordQ.addOperation {
            
            jsonRequest.httpMethod = "GET"
            let destConf = URLSessionConfiguration.default
            switch authType {
            case "Basic":
                destConf.httpAdditionalHeaders = ["Authorization" : "\(authType) \(base64Creds)", "Content-Type" : "application/json", "Accept" : "application/json", "User-Agent" : appInfo.userAgentHeader]
            default:
                destConf.httpAdditionalHeaders = ["Authorization" : "\(authType) \(token.sourceServer)", "Content-Type" : "application/json", "Accept" : "application/json", "User-Agent" : appInfo.userAgentHeader]
            }
            
            let destSession = Foundation.URLSession(configuration: destConf, delegate: self, delegateQueue: OperationQueue.main)
            let task = destSession.dataTask(with: jsonRequest as URLRequest, completionHandler: {
                (data, response, error) -> Void in
                if let httpResponse = response as? HTTPURLResponse {
//                    print("[Json.getRecord] httpResponse: \(String(describing: httpResponse))")
                    if httpResponse.statusCode >= 200 && httpResponse.statusCode <= 299 {
                        do {
                            let json = try? JSONSerialization.jsonObject(with: data!, options: .allowFragments)
                            if let endpointJSON = json as? [String:AnyObject] {
//                                if LogLevel.debug { WriteToLog().message(stringOfText: "[Json.getRecord] \(endpointJSON)\n") }
                                completion(endpointJSON)
                            } else {
//                                WriteToLog().message(stringOfText: "[Json.getRecord] error parsing JSON for \(existingDestUrl)\n")
                                completion([:])
                            }
                        }
                    } else {
                        WriteToLog().message(theString: "[Json.getRecord] error during GET, HTTP Status Code: \(httpResponse.statusCode)\n")
                        if "\(httpResponse.statusCode)" == "401" {
                            Alert().display(header: "Alert", message: "Verify username and password.")
                        }
//                        WriteToLog().message(stringOfText: "[Json.getRecord] error HTTP Status Code: \(httpResponse.statusCode)\n")
                        completion([:])
                    }
                } else {
//                    WriteToLog().message(stringOfText: "[Json.getRecord] error parsing JSON for \(existingDestUrl)\n")
                    completion([:])
                }   // if let httpResponse - end
                semaphore.signal()
                if error != nil {
                }
            })  // let task = destSession - end
            //print("GET")
            task.resume()
        }   // getRecordQ - end
    }
    
    /*
    func getToken(serverUrl: String, base64creds: String, completion: @escaping (_ returnedToken: String) -> Void) {
        
        URLCache.shared.removeAllCachedResponses()
        
        var token          = ""
        
        var tokenUrlString = "\(serverUrl)/api/v1/auth/token"
        tokenUrlString     = tokenUrlString.replacingOccurrences(of: "//api", with: "/api")
//        print("tokenUrlString: \(tokenUrlString)")
        
        let tokenUrl       = URL(string: "\(tokenUrlString)")
        let configuration  = URLSessionConfiguration.default
        var request        = URLRequest(url: tokenUrl!)
        request.httpMethod = "POST"
        
        configuration.httpAdditionalHeaders = ["Authorization" : "Basic \(base64creds)", "Content-Type" : "application/json", "Accept" : "application/json"]
        let session = Foundation.URLSession(configuration: configuration, delegate: self as URLSessionDelegate, delegateQueue: OperationQueue.main)
        let task = session.dataTask(with: request as URLRequest, completionHandler: {
            (data, response, error) -> Void in
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode >= 200 && httpResponse.statusCode <= 299 {
                    let json = try? JSONSerialization.jsonObject(with: data!, options: .allowFragments)
                    if let endpointJSON = json! as? Dictionary<String, Any>, let _ = endpointJSON["token"] {
                        token = endpointJSON["token"] as! String
                        WriteToLog().message(theString: "[getToken] retrieved token from \(serverUrl)")
                        completion(token)
                        return
                    } else {    // if let endpointJSON error
                        print("JSON error")
                        WriteToLog().message(theString: "[getToken] error with returned JSON: \(String(describing: json))")
                        completion("")
                        return
                    }
                } else {    // if httpResponse.statusCode <200 or >299
                    print("response error: \(httpResponse.statusCode)")
                    WriteToLog().message(theString: "[getToken] failed to retrieved token from \(serverUrl): Status code: \(httpResponse.statusCode)")

                    if "\(httpResponse.statusCode)" == "401" {
                        Alert().display(header: "Alert", message: "Failed to authenticate.  Verify username and password.")
                    }
                    completion("")
                    return
                }
            } else {
                print("token response error.  Verify url and port.")
                WriteToLog().message(theString: "[getToken] No response from the server.  Verify URL and port")
                Alert().display(header: "Alert", message: "No response from the server.  Verify URL and port.")
                completion("")
                return
            }
        })
        task.resume()
        
    }   // func token - end
    */
    
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping(  URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        completionHandler(.useCredential, URLCredential(trust: challenge.protectionSpace.serverTrust!))
    }
    
}

