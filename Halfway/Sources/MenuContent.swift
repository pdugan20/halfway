import SwiftUI

/// The menu bar panel: what's playing, its scrobble status, recent plays, and the way to Settings.
struct MenuContent: View {
  let model: AppModel
  @ObservedObject var updater: AppUpdater
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
      if !model.recent.isEmpty {
        Divider()
        RecentList(items: Array(model.recent.prefix(5)))
      }
      Divider()
      UpdateStatusRow(updater: updater, driver: updater.userDriver)
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
        HStack(alignment: .top, spacing: 8) {
          VStack(alignment: .leading, spacing: 2) {
            Text(play.track.title)
              .font(.headline)
              .lineLimit(1)
            Text(play.track.artist)
              .foregroundStyle(.secondary)
              .lineLimit(1)
          }
          Spacer(minLength: 0)
          if model.isSignedIn {
            LoveButton(model: model)
          }
        }
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
    guard model.isSignedIn else { return (nil, "Sign in to scrobble") }
    guard model.isScrobblingEnabled else { return (nil, "Scrobbling is off") }
    let listened = play.listened(at: now)
    let remaining = Duration.seconds(max(0, threshold - listened).rounded(.up))
      .formatted(.time(pattern: .minuteSecond))
    let text = play.isPlaying ? "Scrobbles in \(remaining)" : "Paused · \(remaining) to go"
    return (min(listened / threshold, 1), text)
  }
}

private struct LoveButton: View {
  let model: AppModel

  private var isLoved: Bool { model.isCurrentTrackLoved == true }

  var body: some View {
    Button { model.toggleLove() } label: {
      Image(systemName: isLoved ? "heart.fill" : "heart")
        .foregroundStyle(isLoved ? AnyShapeStyle(.red) : AnyShapeStyle(.secondary))
        .contentTransition(.symbolEffect(.replace))
    }
    .buttonStyle(.borderless)
    .disabled(model.isCurrentTrackLoved == nil)
    .help(isLoved ? "Unlove on Last.fm" : "Love on Last.fm")
    .accessibilityLabel(isLoved ? "Unlove on Last.fm" : "Love on Last.fm")
  }
}

private struct RecentList: View {
  let items: [RecentScrobble]

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text("Recent")
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
      ForEach(items) { item in
        HStack(spacing: 8) {
          VStack(alignment: .leading, spacing: 1) {
            Text(item.title)
              .font(.callout)
              .lineLimit(1)
            Text(item.artist)
              .font(.caption)
              .foregroundStyle(.secondary)
              .lineLimit(1)
          }
          Spacer(minLength: 8)
          StatusIcon(status: item.status)
        }
        .accessibilityElement(children: .combine)
      }
    }
  }
}

private struct StatusIcon: View {
  let status: RecentScrobble.Status

  var body: some View {
    Image(systemName: symbol)
      .foregroundStyle(color)
      .help(label)
      .accessibilityLabel(label)
  }

  private var symbol: String {
    switch status {
    case .waiting: "clock"
    case .sent: "checkmark.circle"
    case .ignored: "exclamationmark.circle"
    case .rejected: "xmark.circle"
    }
  }

  private var color: Color {
    switch status {
    case .waiting, .sent: .secondary
    case .ignored: .orange
    case .rejected: .red
    }
  }

  private var label: String {
    switch status {
    case .waiting: "Waiting to send"
    case .sent: "Scrobbled"
    case .ignored: "Last.fm didn't count this play"
    case .rejected: "Last.fm rejected this play"
    }
  }
}
