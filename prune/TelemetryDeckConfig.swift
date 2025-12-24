//
//  Copyright © 2025 Jamf. All rights reserved.
//

import TelemetryDeck

struct TelemetryDeckConfig {
    static let appId = "***REMOVED***"
    @MainActor static var parameters: [String: String] = [:]
    @MainActor static var OptOut: Bool = false
}

extension AppDelegate {
    @MainActor func configureTelemetryDeck() {
        if !TelemetryDeckConfig.OptOut {
            let config = TelemetryDeck.Config(appID: TelemetryDeckConfig.appId)
            TelemetryDeck.initialize(config: config)
        }
    }
}

class TelemetryDeckSend {
    static let shared = TelemetryDeckSend()
    
    private init() {}
    
    func send(_ event: String, parameters: [String: String] = [:]) {
        TelemetryDeck.signal(event, parameters: parameters)
    }
}
