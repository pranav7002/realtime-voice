//
//  TokenProvider.swift
//  RealtimeVoice
//
//  Created by Pranav Rai on 07/10/26.
//

import Foundation

protocol TokenProvider {
    func fetchToken() async throws -> String
}

enum TokenError: LocalizedError {
    case badStatus(Int)
    
    var errorDescription: String? {
        switch self {
        case .badStatus(let code):
            return "Token server returned status \(code)"
        }
    }
}

// Asking Go sever for an ephemeral key
struct ServerTokenProvider: TokenProvider {
    let baseURL: URL
    
    func fetchToken() async throws -> String {
        var req = URLRequest(url: baseURL.appending(path: "api/session"))
        req.httpMethod = "POST"
        req.timeoutInterval = 10
        
        let (data, res) = try await URLSession.shared.data(for: req)
        
        let status = (res as? HTTPURLResponse)?.statusCode ?? -1
        
        guard status == 200 else {
            throw TokenError.badStatus(status)
        }
        
        let decoded = try JSONDecoder().decode(SessionResponse.self, from: data)
        
        return decoded.data.value
    }
}

// Maps to the Go servers JSON
private struct SessionResponse: Decodable {
    struct Session: Decodable {
        let value: String
        let expiresAt: Int
    }
    
    let data: Session
}


