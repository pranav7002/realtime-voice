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
    // A real iPhone needs the Mac's local network name. Find it with: scutil --get LocalHostName
    static let serverURL = URL(string: "http://Your-Mac-Name.local:8080")!
    #endif
}
