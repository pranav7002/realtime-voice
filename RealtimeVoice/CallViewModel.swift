//
//  CallViewModel.swift
//  RealtimeVoice
//
//  Created by Pranav Rai on 06/10/26.
//

import Foundation
import Observation

@MainActor
@Observable
final class CallViewModel {
    private(set) var phase: Phase = .idle
    private(set) var messages: [Message] = []
    
    private var callTask: Task<Void, Never>?
    
    func start() {
        guard phase == .idle || isFailed else {
            return
        }
        
        messages = []
        
        callTask = Task {
            await runFakeCall()
        }
    }
    
    func stop() {
        callTask?.cancel()
        callTask = nil
        phase = .idle
    }
    
    private var isFailed: Bool {
        if case .failed = phase { return true }
        return false
    }
    
    private func runFakeCall() async {
        phase = .connecting
        do {
            try await Task.sleep(for: .seconds(1))
            
            phase = .listening
            try await Task.sleep(for: .seconds(2))
            
            phase = .userSpeaking
            try await Task.sleep(for: .seconds(2))
            messages.append(Message(role: .user, text: "What's the weather like today?"))
            
            phase = .assistantSpeaking
            messages.append(Message(role: .assistant, text: ""))
            let reply = "It looks sunny today with a light breeze and a high of twenty four degrees."
            
            for word in reply.split(separator: " ") {
                try await Task.sleep(for: .milliseconds(150))
                let lastIndex = messages.count - 1
                messages[lastIndex].text += " \(word)"
            }
            
            phase = .listening
            
        } catch {
            // Cancelled by stop(), stop() already resets phase, nothing to do here
        }
    }
}
