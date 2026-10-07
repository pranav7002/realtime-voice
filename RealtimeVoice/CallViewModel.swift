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
    
    private var service: any RealtimeService
    private var callTask: Task<Void, Never>?
    private var assistantMessageID: UUID?
    
    init(service: any RealtimeService) {
        self.service = service
    }
    
    func start() {
        guard phase == .idle || isFailed else {
            return
        }
        
        messages = []
        assistantMessageID = nil
        phase = .connecting
        
        callTask = Task {
            await runCall()
        }
    }
    
    func stop() {
        callTask?.cancel()
        callTask = nil
        service.disconnect()
        phase = .idle
    }
    
    func interrupt() {
        service.interrupt()
    }
    
    private var isFailed: Bool {
        if case .failed = phase { return true }
        return false
    }
    
    private func runCall() async {
        do {
            let events = try await service.connect()
            
            for await event in events {
                guard !Task.isCancelled else { break }
                handle(event)
            }
            
            // When the connnection closed but the UI does not know
            // Handles the race bw stop() and the call itself
            if !Task.isCancelled && phase.isLive {
                phase = .idle
            }
            
        } catch {
            
            // When cancelling while connecting, a cancelled error is thrown, stop handels this so we return wo doing anything
            guard !Task.isCancelled else { return }
            phase = .failed(error.localizedDescription)
        }
    }
    
    private func handle(_ event: RealtimeEvent) {
        switch event {
        case .connected:
            phase = .listening
            
        case .userStartedSpeaking:
            phase = .userSpeaking
            
        case .userStoppedSpeaking:
            phase = .listening
            
        case .userTranscript(let text):
            addUserMessage(text)
            
        case .assistantStarted:
            phase = .assistantSpeaking
            
        case .assistantDelta(let text):
            appendAssistantText(text)
            
        case .assistantDone:
            assistantMessageID = nil
            phase = .idle
            
        case .assistantInterrupted:
            appendAssistantText("...")
            assistantMessageID = nil
            phase = .listening
            
        case .failed(let error):
            phase = .failed(error)
        }
    }
    
    private func addUserMessage(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let message = Message(role: .user, text: trimmed)

        // The user's transcript often arrives after the assistant has started replying.
        // Put it above the reply so the chat reads in the right order.
        if let id = assistantMessageID, let index = messages.firstIndex(where: { $0.id == id }) {
            messages.insert(message, at: index)
        } else {
            messages.append(message)
        }
    }

    private func appendAssistantText(_ text: String) {
        if let id = assistantMessageID,
           let index = messages.firstIndex(where: { $0.id == id }) {
            messages[index].text += text
        } else {
            // First words of a new reply: create its bubble.
            let message = Message(role: .assistant, text: text)
            messages.append(message)
            assistantMessageID = message.id
        }
    }
}
