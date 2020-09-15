//
//  Json.swift
//  prune
//
//  Created by Leslie Helou on 12/11/19.
//  Copyright © 2019 Leslie Helou. All rights reserved.
//

import Cocoa

class Json: NSURL, URLSessionDelegate {
    
    let defaults = UserDefaults.standard
    
    func getRecord(theServer: String, base64Creds: String, theEndpoint: String, completion: @escaping (_ result: [String:AnyObject]) -> Void) {

        let getRecordQ = OperationQueue() // DispatchQueue(label: "com.jamf.getRecordQ", qos: DispatchQoS.background)
    
        URLCache.shared.removeAllCachedResponses()
        var existingDestUrl = ""
        
        existingDestUrl = "\(theServer)/JSSResource/\(theEndpoint)"
        existingDestUrl = existingDestUrl.replacingOccurrences(of: "//JSSResource", with: "/JSSResource")
        
//        if LogLevel.debug { WriteToLog().message(stringOfText: "[Json.getRecord] Looking up: \(existingDestUrl)\n") }
        print("[Json.getRecord] existing endpoints URL: \(existingDestUrl)")
        let destEncodedURL = NSURL(string: existingDestUrl)
        let jsonRequest    = NSMutableURLRequest(url: destEncodedURL! as URL)
        
        let semaphore = DispatchSemaphore(value: 0)
        getRecordQ.maxConcurrentOperationCount = 4
        getRecordQ.addOperation {
            
            jsonRequest.httpMethod = "GET"
            let destConf = URLSessionConfiguration.default
            destConf.httpAdditionalHeaders = ["Authorization" : "Basic \(base64Creds)", "Content-Type" : "application/json", "Accept" : "application/json"]
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
                        print("[Json.getRecord] error HTTP Status Code: \(httpResponse.statusCode)\n")
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
    
    func getToken(serverUrl: String, base64creds: String, completion: @escaping (_ returnedToken: String) -> Void) {
        
        URLCache.shared.removeAllCachedResponses()
        
        var token          = ""
        
        var tokenUrlString = "\(serverUrl)/uapi/auth/tokens"
        tokenUrlString     = tokenUrlString.replacingOccurrences(of: "//uapi", with: "/uapi")
//        print("\(tokenUrlString)")
        
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
                        completion(token)
                        return
                    } else {    // if let endpointJSON error
                        print("JSON error")
                        completion("")
                        return
                    }
                } else {    // if httpResponse.statusCode <200 or >299
                    print("response error: \(httpResponse.statusCode)")

                    if "\(httpResponse.statusCode)" == "401" {
                        Alert().display(header: "Alert", message: "Failed to authenticate.  Verify username and password.")
                    }
                    completion("")
                    return
                }
            } else {
                print("token response error.  Verify url and port.")
                Alert().display(header: "Alert", message: "No response from the server.  Verify URL and port.")
                completion("")
                return
            }
        })
        task.resume()
        
    }   // func token - end
    
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping(  URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        completionHandler(.useCredential, URLCredential(trust: challenge.protectionSpace.serverTrust!))
    }
    
}

