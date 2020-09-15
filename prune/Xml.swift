//
//  Xml.swift
//  Prune
//
//  Created by Leslie Helou on 12/15/19.
//  Copyright © 2019 Leslie Helou. All rights reserved.
//

import Cocoa

class Xml: NSURL, URLSessionDelegate {
    func action(action: String, theServer: String, base64Creds: String, theEndpoint: String, completion: @escaping (_ result: (Int,String)) -> Void) {

        let getRecordQ = OperationQueue()   //DispatchQueue(label: "com.jamf.getRecordQ", qos: DispatchQoS.background)
    
        URLCache.shared.removeAllCachedResponses()
        var existingDestUrl = ""
        
        existingDestUrl = "\(theServer)/JSSResource/\(theEndpoint)"
        existingDestUrl = existingDestUrl.replacingOccurrences(of: "//JSSResource", with: "/JSSResource")
        
//        if LogLevel.debug { WriteToLog().message(stringOfText: "[Json.getRecord] Looking up: \(existingDestUrl)\n") }
        print("[Xml.action] existing endpoints URL: \(existingDestUrl)")
        let destEncodedURL = NSURL(string: existingDestUrl)
        let xmlRequest     = NSMutableURLRequest(url: destEncodedURL! as URL)
        
        let semaphore = DispatchSemaphore(value: 1)
        getRecordQ.maxConcurrentOperationCount = 4
        getRecordQ.addOperation {
            
            xmlRequest.httpMethod = "\(action.uppercased())"
            let destConf = URLSessionConfiguration.default
            destConf.httpAdditionalHeaders = ["Authorization" : "Basic \(base64Creds)", "Content-Type" : "text/xml", "Accept" : "text/xml"]
            let destSession = Foundation.URLSession(configuration: destConf, delegate: self, delegateQueue: OperationQueue.main)
            let task = destSession.dataTask(with: xmlRequest as URLRequest, completionHandler: {
                (data, response, error) -> Void in
                if let httpResponse = response as? HTTPURLResponse {
//                    print("[Xml.action] httpResponse: \(String(describing: httpResponse))")
                    if httpResponse.statusCode >= 200 && httpResponse.statusCode <= 299 {
                        do {
                            let returnedXML = String(data: data!, encoding: String.Encoding(rawValue: String.Encoding.utf8.rawValue))!

                            completion((httpResponse.statusCode,returnedXML))
                        }
                    } else {
//                        WriteToLog().message(stringOfText: "[Xml.action] error HTTP Status Code: \(httpResponse.statusCode)\n")
                        print("[Xml.action] error HTTP Status Code: \(httpResponse.statusCode)\n")
                        if action != "DELETE" {
                            completion((httpResponse.statusCode,""))
                        } else {
                            completion((httpResponse.statusCode,""))
                        }
                    }
                } else {
//                    WriteToLog().message(stringOfText: "[Xml.action] error parsing JSON for \(existingDestUrl)\n")
                    completion((0,""))
                }   // if let httpResponse - end
                semaphore.signal()
                if error != nil {
                }
            })  // let task = destSession - end
            //print("GET")
            task.resume()
        }   // getRecordQ - end
    }
    
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping(  URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        completionHandler(.useCredential, URLCredential(trust: challenge.protectionSpace.serverTrust!))
    }
    
}
