# RealtimeVoice

A speech-to-speech iOS app. Tap Start, talk, and an AI assistant answers out loud, with both sides shown as live chat bubbles. It uses OpenAI `gpt-realtime-1.5` over WebRTC. A separate Go token server (`~/Documents/voice-server`, github.com/pranav7002/voice-server) keeps the real API key off the phone and hands the app short-lived `ek_` keys.

**Rules and UI design language:** read `docs/CONVENTIONS.md` before planning or reviewing any change.

## File map

| Layer | Files | Job |
|---|---|---|
| Composition root | `RealtimeVoiceApp.swift`, `AppConfig.swift` | The only place concrete types are created and wired. Server URL per build (simulator: localhost, device: Mac's `.local` name). |
| Views | `ContentView.swift`, `StatusPill.swift`, `MessageBubble.swift` | Draw state, forward taps. No logic, no services. |
| View model and UI state | `CallViewModel.swift`, `Phase.swift`, `Message.swift` | Owns `phase` + `messages`, runs the call, turns events into state in `handle(_:)`. |
| Service contracts | `RealtimeService.swift`, `RealtimeEvent.swift`, `TokenProvider.swift` | Protocols plus the app's own event enum. `TokenProvider.swift` also holds `ServerTokenProvider`. |
| Service implementation | `OpenAIRealtimeService.swift` | `OAIRealtimeService`: WebRTC peer connection, SDP exchange, `oai-events` data channel, OpenAI JSON → `RealtimeEvent`. The only file that knows OpenAI or WebRTC exist. |

All Swift files are in `RealtimeVoice/`. Dependency: `stasel/WebRTC` 154.0.0 (Swift Package).

## How a call flows

`start()` → `service.connect()`, which does mic permission → token from the Go server → audio session → peer connection (mic track + data channel) → SDP offer POSTed to OpenAI → answer. It returns an `AsyncStream<RealtimeEvent>`. `runCall()` loops `for await` over the stream and calls `handle(_:)`, which updates `phase` and `messages`, and SwiftUI redraws. Audio itself never touches Swift code: WebRTC captures and plays it.

## Commands

```bash
# Build (the agent should run this after every change)
xcodebuild -project RealtimeVoice.xcodeproj -scheme RealtimeVoice -destination 'platform=iOS Simulator,name=iPhone 17' -quiet build

# Token server (needed to actually make a call); needs OPENAI_API_KEY in its .env
cd ~/Documents/voice-server && make run
```

There is no test target yet. If a change needs tests, add a `RealtimeVoiceTests` target using Swift Testing, with test doubles living only there.

## Using the agents

When the developer asks for the `explorer`, `planner` or `reviewer` agent:

- Pass the agent the developer's problem plus an explicit task line: "Task: investigate and return a briefing only, do not edit files" (explorer), "Task: return a plan only, do not edit files" (planner), or "Task: review the current diff and report only, do not edit files" (reviewer).
- Show the developer the agent's full output exactly as written, including its diagrams and tables, not a summary.
- When calling the reviewer, include the developer's requirements for the change (from the conversation), so it can check that the change does what was asked, not just that it follows the rules.
- When calling the planner, include the developer's requirements and any decisions they've already made.
- **Then stop and wait.** Don't implement, fix, or start the next step until the developer explicitly says so ("build step 1", "fix the blockers"). A request like "use the explorer agent: add a mute button" means *investigate* adding a mute button, not build it.

## How to work in this repo

1. Explore first, then plan, then build in small steps. Agents: `explorer` → `planner` → build → `reviewer`. Only build when the developer asks.
2. Build after every step and fix errors before moving on.
3. Keep changes small and in the existing patterns. No new dependencies without asking.
4. Never stage `RealtimeVoice/AppConfig.swift`: it has a local machine hostname.
5. Never put an OpenAI `sk-` key in the app, in logs, or in git.

## Known issues (not yet fixed)

- `RealtimeVoiceApp` creates a second `CallViewModel` inline in `body` instead of passing the `@State model`. Fix: `ContentView(model: model)`.
- OpenAI `error` events are only printed. Peer connection `.disconnected` / `.closed` aren't handled, and there's no reconnect.
- No background audio mode and no handling of audio interruptions.
