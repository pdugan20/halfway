import SwiftUI

struct MenuContent: View {
  @Bindable var model: AppModel

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      NowPlayingView(model: model)
      Divider()
      account
      if let message = model.message {
        Text(message)
          .font(.callout)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
      Divider()
      SettingRow("Scrobbling", isOn: $model.isScrobblingEnabled)
      SettingRow(
        "Open at Login",
        isOn: Binding(get: { model.opensAtLogin }, set: { model.setOpensAtLogin($0) })
      )
      Divider()
      footer
    }
    .padding(14)
    .frame(width: 290)
  }

  @ViewBuilder
  private var account: some View {
    if !model.isConfigured {
      Text("This build is missing its Last.fm API key.")
        .foregroundStyle(.secondary)
    } else {
      switch model.account {
      case .signedOut:
        Button("Sign In with Last.fm") { model.signIn() }
          .controlSize(.large)
          .buttonStyle(.borderedProminent)
          .frame(maxWidth: .infinity)
      case .waitingForApproval:
        HStack(spacing: 8) {
          ProgressView().controlSize(.small)
          Text("Approve Halfway in your browser…")
          Spacer()
          Button("Cancel") { model.cancelSignIn() }
        }
      case .signedIn:
        if model.pendingCount > 0 {
          Text("^[\(model.pendingCount) scrobble](inflect: true) waiting to send")
            .font(.callout)
            .foregroundStyle(.secondary)
        }
      }
    }
  }

  private var footer: some View {
    HStack {
      if case .signedIn(let username) = model.account, let url = model.profileURL {
        Link(username, destination: url)
        Spacer()
        Button("Sign Out") { model.signOut() }
      } else {
        Spacer()
      }
      Button("Quit") { NSApplication.shared.terminate(nil) }
        .keyboardShortcut("q")
    }
    .buttonStyle(.borderless)
  }
}

private struct SettingRow: View {
  let title: String
  @Binding var isOn: Bool

  init(_ title: String, isOn: Binding<Bool>) {
    self.title = title
    _isOn = isOn
  }

  var body: some View {
    Toggle(title, isOn: $isOn)
      .toggleStyle(.switch)
      .controlSize(.small)
      .frame(maxWidth: .infinity, alignment: .leading)
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
