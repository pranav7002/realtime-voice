//
//  RealtimeEvent.swift
//  RealtimeVoice
//
//  Created by Pranav Rai on 07/10/26.
//

import Foundation

// Sendbale allows inter thread transfer
enum RealtimeEvent: Equatable, Sendable {
    case connected
    case userStartedSpeaking
    case userStoppedSpeaking
    case userTranscript(String)
    case assistantStarted
    case assistantDelta(String)
    case assistantDone
    case assistantInterrupted
    case failed(String)
}

