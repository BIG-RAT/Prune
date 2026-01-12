//
//  Copyright 2026 Jamf. All rights reserved.
//

import Cocoa

class XmlParser: NSObject, XMLParserDelegate {
    
    var printerArray: [Printer] = []
    
    enum State { case none, id, name, category, uri, cups_name, location, model, make_default, shared, info, notes, use_generic, ppd, ppd_contents, ppd_path,
                      printer_info, printer_make_and_model, os_req
    }
    var state: State = .none
    var newPrinter: Printer? = nil
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String]) {
//        print("elementName: \(elementName)")
        switch elementName {
        case "printer", "dict" :
            self.newPrinter = Printer()
            self.state = .none
        case "id":
            self.state = .id
        case "name", "printer-info":
            self.state = .name
        case "category":
            self.state = .category
        case "uri":
            self.state = .uri
        case "CUPS_name":
            self.state = .cups_name
        case "location":
            self.state = .location
        case "model", "printer-make-and-model":
            self.state = .model
        case "make_default":
            self.state = .make_default
        case "shared":
            self.state = .shared
        case "info":
            self.state = .info
        case "notes":
            self.state = .notes
        case "use_generic":
            self.state = .use_generic
        case "ppd":
            self.state = .ppd
        case "ppd_contents":
            self.state = .ppd_contents
        case "ppd_path":
            self.state = .ppd_path
        case "os_req":
            self.state = .os_req
        default:
            self.state = .none
        }
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if let newPrinter = self.newPrinter, elementName == "printer" || elementName == "dict" {
            self.printerArray.append(newPrinter)
            self.newPrinter = nil
        }
        self.state = .none
    }
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard let _ = self.newPrinter else { return }
        switch self.state {
        case .id:
            self.newPrinter!.id = string
        case .name:
            self.newPrinter!.name += string
        case .category:
            self.newPrinter!.category = string
            if self.newPrinter!.category == "No category assigned" {
                self.newPrinter!.category = ""
            }
        case .uri:
            self.newPrinter!.uri = string
        case .cups_name:
            self.newPrinter!.cups_name += string
        case .location:
            self.newPrinter!.location += string
        case .model:
            self.newPrinter!.model = string
        case .make_default:
            self.newPrinter!.make_default = string
        case .shared:
            self.newPrinter!.shared = string
        case .info:
            self.newPrinter!.info += string
        case .notes:
            self.newPrinter!.notes += string
        case .use_generic:
            self.newPrinter!.use_generic = string
        case .ppd:
            self.newPrinter!.ppd = string
        case .ppd_contents:
            self.newPrinter!.ppd_contents += string
        case .ppd_path:
            self.newPrinter!.ppd_path = string
        case .os_req:
            self.newPrinter!.os_req = string
        default:
            break
        }
    }
    
    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
    }
}

struct Printer {
    var id           = ""
    var name         = ""
    var category     = ""
    var uri          = ""
    var cups_name    = ""
    var location     = ""
    var model        = ""
    var make_default = ""
    var shared       = ""
    var info         = ""
    var notes        = ""
    var use_generic  = ""
    var ppd          = ""
    var ppd_contents = ""
    var ppd_path     = ""
    var os_req       = ""
}

