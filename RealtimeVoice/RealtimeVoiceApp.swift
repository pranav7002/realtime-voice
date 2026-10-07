//
//  RealtimeVoiceApp.swift
//  RealtimeVoice
//
//  Created by Pranav Rai on 06/10/26.
//

import SwiftUI

@main
struct RealtimeVoiceApp: App {
    @State private var model = CallViewModel(
        service: OAIRealtimeService(
            tokenProvider: ServerTokenProvider(baseURL: AppConfig.serverURL)
        )
    )
    
    var body: some Scene {
        WindowGroup {
            ContentView(
                model: CallViewModel(
                    service: OAIRealtimeService(
                        tokenProvider: ServerTokenProvider(baseURL: AppConfig.serverURL)
                    )
                )
            )
        }
    }
}
