//
//  StatusPill.swift
//  RealtimeVoice
//
//  Created by Pranav Rai on 06/10/26.
//

import SwiftUI

struct StatusPill: View {
    let phase: Phase
    
    var body: some View {
        Text(text)
            .font(.subheadline.bold())
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(color.opacity(0.15), in:
                            Capsule())
            .foregroundStyle(color)
    }
    
    private var text: String {
        switch phase {
        case .idle:
            return "Tap start to talk"
        case .connecting:
            return "Connecting..."
        case .listening:
            return "Listening"
        case .userSpeaking:
            return "You're speaking"
        case .assistantSpeaking:
            return "Assistant speaking"
        case .failed(let reason):
            return reason
        }
    }
    
    private var color: Color {
        switch phase {
        case .failed:
            return .red
        case .userSpeaking:
            return .green
        case .assistantSpeaking:
            return .blue
        default:
            return .gray
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        StatusPill(phase: .idle)
        StatusPill(phase: .connecting)
        StatusPill(phase: .listening)
        StatusPill(phase: .userSpeaking)
        StatusPill(phase: .assistantSpeaking)
        StatusPill(phase: .failed("No internet"))
    }
}
