# RealtimeVoice conventions

The rules this app is built on. The `planner` agent plans within them and the `reviewer` agent checks against them, citing rule IDs. Each rule names the code that already follows it, so new code can copy the pattern.

## Architecture

- **A1. Layers point one way.** Views → `CallViewModel` → protocols (`RealtimeService`, `TokenProvider`) ← implementations. Views never touch a service. The view model never imports or mentions WebRTC.
- **A2. Concrete types are only created in the composition root** (`RealtimeVoiceApp`). Everything else receives dependencies through `init` as `any Protocol`.
- **A3. Vendor vocabulary stays at the edge.** OpenAI event strings, SDP and WebRTC types live only in `OpenAIRealtimeService.swift`. They're translated into `RealtimeEvent` in `received(_:)`.
- **A4. New behaviour from the service means a new `RealtimeEvent` case.** `CallViewModel.handle(_:)` stays exhaustive, with no `default`, so the compiler finds every place to update.
- **A5. UI state lives in `CallViewModel` as `private(set)`.** Screen status is a case of the `Phase` enum, never a new Boolean flag. Derived values are computed properties (`Phase.isLive`).
- **A6. Guard transitions against late events.** Only leave a phase if you're still in it (`if phase == .assistantSpeaking { phase = .listening }`).
- **A7. Refer to messages by their stable `UUID` id, never by array index** (see `assistantMessageID`).
- **A8. No fakes, mocks or stubs in the app target.** Protocols are the seams. Test doubles live only in a test target.
- **A9. Keep the protocol surface minimal.** Don't add protocol methods or abstractions until a feature needs them (YAGNI).

## Concurrency

- **C1. State-owning types are `@MainActor`** (the project's default isolation is MainActor anyway; keep the explicit annotation on classes and protocols).
- **C2. Callbacks from other threads** (WebRTC delegates) are `nonisolated`, copy out a `Sendable` value, then hop with `Task { @MainActor in … }`. Never touch state inside the callback itself.
- **C3. Types that cross isolation are `Sendable`** (`RealtimeEvent`).
- **C4. Long-running work runs in a stored `Task`** that `stop()` cancels. After every slow `await` in setup, call `try Task.checkCancellation()`. A cancellation must never show an error to the user.
- **C5. Resources are released in one idempotent `disconnect()`.** Setup failures roll back with `catch { disconnect(); throw error }`.
- **C6. No retain cycles that outlive a call.** A task capturing `self` is fine only if the task always ends. Stored closures and observers use `[weak self]`.

## Errors

- **E1. Setup errors are thrown** as an enum conforming to `LocalizedError`, with a user-facing `errorDescription` (`RealtimeError`, `TokenError`). **Mid-call errors are events** (`RealtimeEvent.failed`).
- **E2. No `try!`.** Force unwrap only compile-time constants (`URL(string: "https://…")!`). `try?` only where the failure is genuinely ignorable (teardown, skipping a malformed message).
- **E3. Check HTTP status codes explicitly** and turn them into typed errors (`TokenError.badStatus`, `RealtimeError.callRejected`).

## Security

- **S1. The OpenAI `sk-` key never appears in the app, in logs, or in git.** The app only ever holds ephemeral `ek_` keys from the Go server.
- **S2. Never commit `AppConfig.swift` with a real machine hostname.** The committed version uses a placeholder.
- **S3. Don't log tokens or keys**, even partially, beyond a prefix.

## Code style

- One main type per file, and the file is named after it.
- Protocols are named for what they do (`RealtimeService`, `TokenProvider`). Implementations are prefixed with their source (`OAIRealtimeService`, `ServerTokenProvider`).
- Protocol conformances go in extensions. Large files are split with `// MARK: -`.
- JSON decoding uses small `private` `Decodable` structs whose property names match the JSON keys exactly. Optional fields are optional properties.
- Comments are short and explain why, not what. Match the density of the surrounding code.
- `final class` for classes not designed for inheritance. `let` unless the value really changes.

## UI design language

The app uses plain SwiftUI with system components, system colours and SF Symbols. There are no custom fonts and no hard-coded hex colours, so dark mode works automatically.

| Element | Pattern | Source |
|---|---|---|
| Screen layout | `VStack(spacing: 24)` with `.padding()`; title is `.font(.largeTitle.bold())` | `ContentView` |
| Status | `StatusPill`: `Text` in `.subheadline.bold()`, `.padding(.horizontal, 14)`, `.padding(.vertical, 6)`, background `color.opacity(0.15)` in a `Capsule()`, foreground `color` | `StatusPill` |
| Status colours | grey = idle or neutral, green = user speaking, blue = assistant speaking, red = failure. A new `Phase` needs both a label and a colour in `StatusPill`. | `StatusPill` |
| Chat bubbles | `.padding(12)`, `RoundedRectangle(cornerRadius: 16)`. User: right-aligned, `Color.blue` with white text. Assistant: left-aligned, `Color(.secondarySystemBackground)` with `.primary` text. `Spacer(minLength: 40)` on the opposite side. | `MessageBubble` |
| Buttons | `Button("Title", systemImage: "sf.symbol", role:)` with `.buttonStyle(.borderedProminent)` and `.controlSize(.large)`. Ending or destructive actions use `role: .destructive`. Disable a button while its action is in progress. | `ContentView` |
| Lists | `ScrollView` + `LazyVStack` + `ForEach` over `Identifiable` models, with `.id(…)` for `ScrollViewReader` auto-scroll | `ContentView` |
| Copy | Short and plain: "Listening", "You're speaking". Errors say what to do: "Microphone access is off. Turn it on in Settings." | `StatusPill`, `RealtimeError` |
| Previews | Every view has a `#Preview` with static data and no network (`StatusPill` shows every phase). | `StatusPill`, `MessageBubble` |
