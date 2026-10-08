//
//  RealtimeService.swift
//  RealtimeVoice
//
//  Created by Pranav Rai on 07/10/26.
//

import Foundation

// AnyObject means only classes can conform to this interface, not structs
@MainActor
protocol RealtimeService: AnyObject {
    func connect() async throws -> AsyncStream<RealtimeEvent>
    
    func disconnect()
}
