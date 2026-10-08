import AVFoundation
import Foundation
import WebRTC

enum RealtimeError: LocalizedError {
    case microphoneDenied
    case setupFailed
    case callRejected(Int)

    var errorDescription: String? {
        switch self {
        case .microphoneDenied:
            return "Microphone access is off. Turn it on in Settings."
        case .setupFailed:
            return "Couldn't set up the voice connection."
        case .callRejected(let status):
            return "OpenAI rejected the call (status \(status))."
        }
    }
}

@MainActor
final class OAIRealtimeService: NSObject, RealtimeService {
    private static let callsURL = URL(string: "https://api.openai.com/v1/realtime/calls")!

    private let tokenProvider: any TokenProvider
    private let factory: RTCPeerConnectionFactory

    private var peerConnection: RTCPeerConnection?
    private var dataChannel: RTCDataChannel?
    private var continuation: AsyncStream<RealtimeEvent>.Continuation?

    init(tokenProvider: any TokenProvider) {
        self.tokenProvider = tokenProvider
        RTCInitializeSSL()
        self.factory = RTCPeerConnectionFactory()
        super.init()
    }

    // MARK: - RealtimeService

    func connect() async throws -> AsyncStream<RealtimeEvent> {
        guard await AVAudioApplication.requestRecordPermission() else {
            throw RealtimeError.microphoneDenied
        }

        let key = try await tokenProvider.fetchToken()
        try Task.checkCancellation()

        // 3. The stream the view model will listen to. Events can arrive before
        //    connect() returns; AsyncStream buffers them until someone listens.
        let (stream, continuation) = AsyncStream.makeStream(of: RealtimeEvent.self)
        self.continuation = continuation

        do {
            try configureAudioSession()
            let pc = try makePeerConnection()

            // 4. SDP offer/answer: describe our audio + data channel, send it to OpenAI,
            //    get back OpenAI's description. After this, WebRTC connects by itself.
            let offer = try await pc.offer(for: Self.constraints)
            try await pc.setLocalDescription(offer)

            let answerSDP = try await exchangeSDP(offer.sdp, key: key)
            try Task.checkCancellation()

            let answer = RTCSessionDescription(type: .answer, sdp: answerSDP)
            try await pc.setRemoteDescription(answer)
        } catch {
            disconnect()
            throw error
        }

        return stream
    }

    func interrupt() {
    }

    func disconnect() {
        dataChannel?.close()
        dataChannel = nil

        peerConnection?.close()
        peerConnection = nil

        continuation?.finish()
        continuation = nil

        let session = RTCAudioSession.sharedInstance()
        session.lockForConfiguration()
        try? session.setActive(false)
        session.unlockForConfiguration()
    }

    // MARK: - Setup

    private static let constraints = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)

    private func configureAudioSession() throws {
        let session = RTCAudioSession.sharedInstance()
        session.lockForConfiguration()
        defer { session.unlockForConfiguration() }

        // playAndRecord: mic + speaker at the same time.
        // voiceChat: turns on echo cancellation, so the assistant doesn't hear itself.
        // defaultToSpeaker: loudspeaker instead of the quiet earpiece.
        try session.setCategory(.playAndRecord, mode: .voiceChat, options: [.defaultToSpeaker, .allowBluetoothHFP])
        try session.setActive(true)
    }

    private func makePeerConnection() throws -> RTCPeerConnection {
        let config = RTCConfiguration()
        config.sdpSemantics = .unifiedPlan

        guard let pc = factory.peerConnection(with: config, constraints: Self.constraints, delegate: self) else {
            throw RealtimeError.setupFailed
        }

        // Our microphone, sent to OpenAI. OpenAI's voice comes back on its own track
        // and WebRTC plays it through the speaker automatically.
        let source = factory.audioSource(with: Self.constraints)
        let micTrack = factory.audioTrack(with: source, trackId: "mic")
        pc.add(micTrack, streamIds: ["local"])

        // Side channel for JSON events (transcripts, speech started, ...).
        guard let channel = pc.dataChannel(forLabel: "oai-events", configuration: RTCDataChannelConfiguration()) else {
            throw RealtimeError.setupFailed
        }
        channel.delegate = self

        peerConnection = pc
        dataChannel = channel
        return pc
    }

    private func exchangeSDP(_ offerSDP: String, key: String) async throws -> String {
        var request = URLRequest(url: Self.callsURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("application/sdp", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data(offerSDP.utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        guard (200..<300).contains(status), let answer = String(data: data, encoding: .utf8) else {
            print("OpenAI call error:", String(data: data, encoding: .utf8) ?? "")
            throw RealtimeError.callRejected(status)
        }
        return answer
    }

    // MARK: - Events from WebRTC (always handled on the main thread)

    private func dataChannelStateChanged(_ state: RTCDataChannelState) {
        if state == .open {
            configureSession()
            continuation?.yield(.connected)
        }
    }

    private func connectionStateChanged(_ state: RTCPeerConnectionState) {
        if state == .failed {
            continuation?.yield(.failed("Connection lost."))
            disconnect()
        }
    }

    private func received(_ data: Data) {
        guard let event = try? JSONDecoder().decode(ServerEvent.self, from: data) else { return }

        switch event.type {
        case "input_audio_buffer.speech_started":
            continuation?.yield(.userStartedSpeaking)

        case "input_audio_buffer.speech_stopped":
            continuation?.yield(.userStoppedSpeaking)

        case "conversation.item.input_audio_transcription.completed":
            if let transcript = event.transcript {
                continuation?.yield(.userTranscript(transcript))
            }

        case "response.output_audio_transcript.delta":
            if let delta = event.delta {
                continuation?.yield(.assistantDelta(delta))
            }

        case "output_audio_buffer.started":
            continuation?.yield(.assistantStarted)

        case "output_audio_buffer.stopped":
            continuation?.yield(.assistantDone)

        case "output_audio_buffer.cleared":
            continuation?.yield(.assistantInterrupted)

        case "error":
            print("OpenAI error:", event.error?.message ?? "unknown")

        default:
            break
        }
    }
    
    // MARK: - Sending events to OpenAI

    private func configureSession() {
        send([
            "type": "session.update",
            "session": [
                "type": "realtime",
                "audio": [
                    "input": [
                        "transcription": ["model": "gpt-4o-mini-transcribe"],
                        "noise_reduction": ["type": "near_field"],
                        "turn_detection": ["type": "semantic_vad", "eagerness": "low"],
                    ],
                ],
            ],
        ])
    }

    private func send(_ event: [String: Any]) {
        guard let channel = dataChannel, channel.readyState == .open,
              let data = try? JSONSerialization.data(withJSONObject: event) else {
            return
        }
        channel.sendData(RTCDataBuffer(data: data, isBinary: false))
    }
}

// The few fields we read from OpenAI's events. Missing fields are just nil.
private struct ServerEvent: Decodable {
    struct ErrorInfo: Decodable {
        let message: String
    }

    let type: String
    let delta: String?
    let transcript: String?
    let error: ErrorInfo?
}

// MARK: - WebRTC delegates
// WebRTC calls these on its own threads, so they're nonisolated:
// copy out what we need, then hop to the main thread.

extension OAIRealtimeService: RTCDataChannelDelegate {
    nonisolated func dataChannelDidChangeState(_ dataChannel: RTCDataChannel) {
        let state = dataChannel.readyState
        Task { @MainActor in self.dataChannelStateChanged(state) }
    }

    nonisolated func dataChannel(_ dataChannel: RTCDataChannel, didReceiveMessageWith buffer: RTCDataBuffer) {
        let data = buffer.data
        Task { @MainActor in self.received(data) }
    }
}

extension OAIRealtimeService: RTCPeerConnectionDelegate {
    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCPeerConnectionState) {
        Task { @MainActor in self.connectionStateChanged(newState) }
    }

    // Required by the protocol but not needed for this app.
    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {}
    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {}
    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {}
    nonisolated func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {}
    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState) {}
    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState) {}
    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {}
    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {}
    nonisolated func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {}
}
