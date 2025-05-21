//
//  Json.swift
//  prune
//
//  Created by Leslie Helou on 12/11/19.
//  Copyright © 2019 Leslie Helou. All rights reserved.
//

import Cocoa

class Json: NSObject, URLSessionDelegate {
    
    static let shared = Json()
    private override init() { }
    
    let getRecordQ = OperationQueue() // DispatchQueue(label: "com.jamf.getRecordQ", qos: DispatchQoS.background)
    
    func getRecord(theServer: String, base64Creds: String, theEndpoint: String, completion: @escaping (_ result: [String:AnyObject]) -> Void) {

        if LoginWindow.show {
            getRecordQ.cancelAllOperations()
            NotificationCenter.default.post(name: .logoutNotification, object: self)
            return
        }
        
        JamfPro.shared.getToken(serverUrl: JamfProServer.source, whichServer: "source", base64creds: JamfProServer.base64Creds) { [self]
            (result: (Int,String)) in
            let (statusCode, theResult) = result
//            print("[getRecord] token check")
            if theResult == "success" {
                
            
                URLCache.shared.removeAllCachedResponses()
                var existingDestUrl = ""
                var authType        = "Bearer"
                
                switch theEndpoint {
                case "computer-prestages":
                    if runningNewer("11.16.0") {
                        existingDestUrl = "\(theServer)/api/v3/\(theEndpoint)"
                        existingDestUrl = existingDestUrl.replacingOccurrences(of: "//api/v3", with: "/api/v3")
                    } else {
                        existingDestUrl = "\(theServer)/api/v2/\(theEndpoint)"
                        existingDestUrl = existingDestUrl.replacingOccurrences(of: "//api/v2", with: "/api/v2")
                    }
                    print("existingDestUrl: \(existingDestUrl)")
                case "jcds2Packages":
                    existingDestUrl = "\(theServer)/api/v1/jcds/files"
                    existingDestUrl = existingDestUrl.replacingOccurrences(of: "//api/v1", with: "/api/v1")
                default:
                    existingDestUrl = "\(theServer)/JSSResource/\(theEndpoint)"
                    existingDestUrl = existingDestUrl.replacingOccurrences(of: "//JSSResource", with: "/JSSResource")
                    if JamfProServer.authType == "Basic" {
                        authType = "Basic"
                    }
                }
                
                WriteToLog.shared.message("[Json.getRecord] get existing endpoints URL: \(existingDestUrl)")
                let destEncodedURL = URL(string: existingDestUrl)
                let jsonRequest    = NSMutableURLRequest(url: destEncodedURL! as URL)
                
                let semaphore = DispatchSemaphore(value: 0)
                getRecordQ.maxConcurrentOperationCount = 4
                getRecordQ.addOperation {
                    
                    jsonRequest.httpMethod = "GET"
                    let destConf = URLSessionConfiguration.default
                    
                    destConf.httpAdditionalHeaders = ["Authorization" : "\(JamfProServer.authType) \(JamfProServer.accessToken)", "Content-Type" : "application/json", "Accept" : "application/json", "User-Agent" : AppInfo.userAgentHeader]
                    
                    let destSession = Foundation.URLSession(configuration: destConf, delegate: self, delegateQueue: OperationQueue.main)
                    let task = destSession.dataTask(with: jsonRequest as URLRequest, completionHandler: {
                        (data, response, error) -> Void in
                        destSession.finishTasksAndInvalidate()
                        if let httpResponse = response as? HTTPURLResponse {
//                            print("[Json.getRecord] httpResponse for \(theEndpoint): \(String(describing: httpResponse))")
                            if httpResponse.statusCode >= 200 && httpResponse.statusCode <= 299 {
                                    do {
                                        let json = try? JSONSerialization.jsonObject(with: data!, options: .allowFragments)
//                                        print("[getRecord] json: \(String(describing: json))")
                                        if let endpointJSON = json as? [String:AnyObject] {
                                            //                                WriteToLog.shared.message("[Json.getRecord] returned JSON: \(endpointJSON)")
                                            completion(endpointJSON)
                                        } else {
                                            WriteToLog.shared.message("[Json.getRecord] error parsing JSON for \(existingDestUrl)")
                                            if let _ = String(data: data!, encoding: .utf8) {
                                                let responseData = String(data: data!, encoding: .utf8)!
                                                WriteToLog.shared.message("[Json.getRecord] full response from GET:\n\(responseData)")
                                                //                        print("create data response: \(responseData)")
                                            } else {
                                                WriteToLog.shared.message("[Json.getRecord] No data was returned from post/put")
                                            }
                                            WriteToLog.shared.message("[Json.getRecord] Nothing returned for server: \(theServer) endpoint: \(theEndpoint)")
                                            if let theId = Int(destEncodedURL?.lastPathComponent ?? "") {
                                                failedLookupDict(theEndpoint: theEndpoint, theId: "\(theId)")
                                            }
                                            completion([:])
                                        }
                                    }
//                                }
                            } else {
                                WriteToLog.shared.message("[Json.getRecord] error during GET, HTTP Status Code: \(httpResponse.statusCode)\n")
                                if "\(httpResponse.statusCode)" == "401" {
                                    _ = Alert.shared.display(header: "Alert", message: "Verify username and password")
                                } else {
                                    _ = Alert.shared.display(header: "Alert", message: "Error during GET, HTTP Status Code: \(httpResponse.statusCode)")
                                }
                                WriteToLog.shared.message("[Json.getRecord] Nothing returned for server: \(theServer) endpoint: \(theEndpoint)")
                                if let theId = Int(destEncodedURL?.lastPathComponent ?? "") {
                                    failedLookupDict(theEndpoint: theEndpoint, theId: "\(theId)")
                                }
                                completion(["Alert" : "Error" as AnyObject])
                            }
                        } else {
                            WriteToLog.shared.message("[Json.getRecord] no response for \(existingDestUrl)")
                            WriteToLog.shared.message("[Json.getRecord] Nothing returned for server: \(theServer) endpoint: \(theEndpoint)")
                            if let theId = Int(destEncodedURL?.lastPathComponent ?? "") {
                                failedLookupDict(theEndpoint: theEndpoint, theId: "\(theId)")
                            }
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
        }
    }
    
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping(  URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        completionHandler(.useCredential, URLCredential(trust: challenge.protectionSpace.serverTrust!))
    }
    
}

