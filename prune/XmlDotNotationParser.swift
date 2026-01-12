//
//  Copyright 2026 Jamf. All rights reserved.
//

import Foundation

@dynamicMemberLookup
class XMLElement {
    var elementName: String
    var attributes: [String: String] = [:]
    var text: String = ""
    var children: [XMLElement] = []
    
    init(elementName: String) {
        self.elementName = elementName
    }
    
    // Enable dot notation access: element.childName
    subscript(dynamicMember member: String) -> XMLElement? {
        return children.first { $0.elementName == member }
    }
    
    // Subscript access: element["childName"]
    subscript(name: String) -> XMLElement? {
        return children.first { $0.elementName == name }
    }
    
    // Get all children with a specific name
    func all(_ name: String) -> [XMLElement] {
        return children.filter { $0.elementName == name }
    }
    
    // Text value accessors
    var value: String {
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    var intValue: Int? {
        return Int(value)
    }
    
    var boolValue: Bool? {
        let lowercased = value.lowercased()
        if lowercased == "true" { return true }
        if lowercased == "false" { return false }
        return nil
    }
    
    var doubleValue: Double? {
        return Double(value)
    }
    
    // Array-like access to all children
    var elements: [XMLElement] {
        return children
    }
    
    // Special accessor for <name> elements to avoid conflicts with built-in String.name
    // Use: element.name (gets <name> child element)
    // vs: element.elementName (gets this element's tag name)
    var name: XMLElement? {
        return children.first { $0.elementName == "name" }
    }
    
    // Debugging helper
    func printStructure(indent: String = "") {
        let val = value.isEmpty ? "" : ": '\(value)'"
        print("\(indent)<\(elementName)>\(val)")
        for child in children {
            child.printStructure(indent: indent + "  ")
        }
    }
}

// MARK: - XML Parser

class XMLDotNotationParser: NSObject, XMLParserDelegate {
    private var root: XMLElement?
    private var stack: [XMLElement] = []
    private var currentText: String = ""
    
    func parse(data: Data) -> XMLElement? {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        return root
    }
    
    func parse(string: String) -> XMLElement? {
        guard let data = string.data(using: .utf8) else { return nil }
        return parse(data: data)
    }
    
    func parse(url: URL) -> XMLElement? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return parse(data: data)
    }
    
    // MARK: - XMLParserDelegate
    
    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?,
                attributes attributeDict: [String : String] = [:]) {
        let element = XMLElement(elementName: elementName)
        element.attributes = attributeDict
        
        if let parent = stack.last {
            parent.children.append(element)
        } else {
            root = element
        }
        
        stack.append(element)
        currentText = ""
    }
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?) {
        if let current = stack.popLast() {
            current.text = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        currentText = ""
    }
}

// MARK: - Convenience Extensions

extension XMLElement {
    /// Iterate over all children with a specific name
    func forEach(named elementName: String, block: (XMLElement) -> Void) {
        all(elementName).forEach(block)
    }
    
    /// Check if element exists
    func has(_ name: String) -> Bool {
        return children.contains { $0.elementName == name }
    }
    
    /// Get attribute value
    func attribute(_ name: String) -> String? {
        return attributes[name]
    }
}
