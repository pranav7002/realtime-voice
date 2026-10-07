//
//  Message.swift
//  RealtimeVoice
//
//  Created by Pranav Rai on 06/10/26.
//

import Foundation

struct Message: Identifiable {
    enum Role {
        case user
        case assistant
    }
    
    let id = UUID()
    let role: Role
    var text: String
}
