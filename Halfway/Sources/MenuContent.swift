import SwiftUI

/// The menu bar panel: what's playing, its scrobble status, and the way to Settings.
struct MenuContent: View {
  let model: AppModel
  @Environment(\.openSettings) private var openSettings

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      NowPlayingView(model: model)
      if model.isConfigured, !model.isSignedIn {
        signIn
      }
      if let message = model.message {
        Text(message)
          .font(.callout)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
      Divider()
      HStack {
        Button("Settings…") {
          openSettings()
          NSApp.activate()
        }
        .keyboardShortcut(",")
        Spacer()
        Button("Quit Halfway") { NSApplication.shared.terminate(nil) }
          .keyboardShortcut("q")
      }
      .buttonStyle(.borderless)
    }
    .padding(14)
    .frame(width: 280)
  }

  @ViewBuilder
  private var signIn: some View {
    if model.account == .waitingForApproval {
      HStack(spacing: 8) {
        ProgressView()
          .controlSize(.small)
        Text("Approve Halfway in your browser")
          .font(.callout)
        Spacer()
        Button("Cancel") { model.cancelSignIn() }
          .buttonStyle(.borderless)
      }
    } else {
      Button("Sign In with Last.fm") { model.signIn() }
        .buttonStyle(.glassProminent)
        .controlSize(.large)
        .frame(maxWidth: .infinity)
    }
  }
}

private struct NowPlayingView: View {
  let model: AppModel

  var body: some View {
    if let play = model.play {
      VStack(alignment: .leading, spacing: 6) {
        Text(play.track.title)
          .font(.headline)
          .lineLimit(1)
        Text(play.track.artist)
          .foregroundStyle(.secondary)
          .lineLimit(1)
        TimelineView(.periodic(from: .now, by: 1)) { context in
          let status = Self.status(for: play, model: model, at: context.date)
          VStack(alignment: .leading, spacing: 4) {
            if let progress = status.progress {
              ProgressView(value: progress)
                .progressViewStyle(.linear)
            }
            Text(status.text)
              .font(.caption)
              .foregroundStyle(.secondary)
              .monospacedDigit()
          }
        }
      }
    } else {
      VStack(alignment: .leading, spacing: 4) {
        Text("Nothing playing")
          .font(.headline)
        Text("Play something in Music to start scrobbling.")
          .font(.callout)
          .foregroundStyle(.secondary)
      }
    }
  }

  private static func status(
    for play: PlaybackTracker.Play,
    model: AppModel,
    at now: Date
  ) -> (progress: Double?, text: String) {
    if play.scrobbled { return (1, "Scrobbled") }
    guard let threshold = PlaybackTracker.threshold(for: play.track) else {
      return (nil, "Too short to scrobble")
    }
    guard case .signedIn = model.account else { return (nil, "Sign in to scrobble") }
    guard model.isScrobblingEnabled else { return (nil, "Scrobbling is off") }
    let listened = play.listened(at: now)
    let remaining = Duration.seconds(max(0, threshold - listened).rounded(.up))
      .formatted(.time(pattern: .minuteSecond))
    let text = play.isPlaying ? "Scrobbles in \(remaining)" : "Paused · \(remaining) to go"
    return (min(listened / threshold, 1), text)
  }
}
