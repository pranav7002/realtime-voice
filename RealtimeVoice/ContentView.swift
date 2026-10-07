//
//  ContentView.swift
//  RealtimeVoice
//
//  Created by Pranav Rai on 06/10/26.
//

import SwiftUI

struct ContentView: View {
    let model: CallViewModel
    
    var body: some View {
        VStack(spacing: 24) {
            Text("Voice Assistant")
                .font(.largeTitle.bold())
            
            StatusPill(phase: model.phase)
            
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack {
                        ForEach(model.messages) {
                            message in
                            MessageBubble(message: message)
                                .id(message.id)
                        }
                    }
                }
                .onChange(of: model.messages.last?.text) {
                    if let last = model.messages.last {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
            
            if model.phase.isLive {
                Button("End", systemImage: "phone.down.fill", role: .destructive) {
                    model.stop()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            } else {
                Button("Start", systemImage: "phone.fill") {
                    model.start()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(model.phase == .connecting)
            }
        }
        .padding()
    }
}

#Preview {
    ContentView(
        model: CallViewModel(
            service: OAIRealtimeService(
                tokenProvider: ServerTokenProvider(baseURL: AppConfig.serverURL)
            )
        )
    )
}
