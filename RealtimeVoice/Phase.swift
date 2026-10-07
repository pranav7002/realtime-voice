//
//  Phase.swift
//  RealtimeVoice
//
//  Created by Pranav Rai on 06/10/26.
//

import Foundation

enum Phase: Equatable {
    case idle
    case connecting
    case listening
    case userSpeaking
    case assistantSpeaking
    case failed(String)
}

extension Phase {
    var isLive: Bool {
        switch self {
        case .listening, .userSpeaking, .assistantSpeaking:
            return true
        default:
            return false
        }
    }
}
