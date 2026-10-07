//
//  OpenAIRealtimeService.swift
//  RealtimeVoice
//
//  Created by Pranav Rai on 07/10/26.
//

import Foundation

enum RealtimeError: LocalizedError {
    case notImplemented
    
    var errorDescription: String? {
        switch self {
        case .notImplemented:
            return "Voice connection comes in Step 14"
        }
    }
}

@MainActor
final class OAIRealtimeService: RealtimeService {
    private let tokenProvider: any TokenProvider
    private var continuation: AsyncStream<RealtimeEvent>.Continuation?
    
    init(tokenProvider: any TokenProvider) {
        self.tokenProvider = tokenProvider
    }
    
    func connect() async throws -> AsyncStream<RealtimeEvent> {
        let key = try await tokenProvider.fetchToken()
        print("Got session key: ", key.prefix(12))
        
        // Will impl later
        throw RealtimeError.notImplemented
    }
    
    func interrupt() {
        
    }
    
    func disconnect() {
        // The finish ends the for await, continuation is the push end of the async stream
        continuation?.finish()
        continuation = nil
    }
}
