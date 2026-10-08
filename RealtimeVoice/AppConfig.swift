//
//  AppConfig.swift
//  RealtimeVoice
//
//  Created by Pranav Rai on 07/10/26.
//

import Foundation

enum AppConfig {
    #if targetEnvironment(simulator)
    // The simulator runs on the Mac, so localhost is the Mac.
    static let serverURL = URL(string: "http://localhost:8080")!
    #else
    // A real iPhone needs the Mac's Wi-Fi address. Check with: ipconfig getifaddr en0
    static let serverURL = URL(string: "http://Your-Mac-Name.local:8080")!
    #endif
}
