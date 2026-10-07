//
//  MessageBubble.swift
//  RealtimeVoice
//
//  Created by Pranav Rai on 06/10/26.
//

import Foundation
import SwiftUI

struct MessageBubble: View {
    let message: Message
    
    private var isUser: Bool {
        message.role == .user
    }
    
    var body: some View {
        HStack {
            if isUser {
                Spacer(minLength: 40)
            }
            
            Text(message.text)
                .padding(12)
                .background(
                    isUser ? Color.blue : Color(.secondarySystemBackground),
                    in:
                        RoundedRectangle(cornerRadius: 16)
                )
                .foregroundStyle(isUser ? Color.white : Color.primary)
            
            if !isUser {
                Spacer(minLength: 40)
            }
        }
    }
}


#Preview {
    VStack {
        MessageBubble(message: Message(role: .user, text: "What's the weather like?"))
        MessageBubble(message: Message(role: .assistant, text: "It looks sunny today with a light breeze."))
    }
    .padding()
}
