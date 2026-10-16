import Foundation
import OSLog

/// Listens for the playback notification Music broadcasts on every play, pause,
/// stop and track change. Receiving it needs no entitlement or Automation
/// permission, which keeps the app sandbox-friendly.
final class MusicObserver {
  static let notificationName = Notification.Name("com.apple.Music.playerInfo")

  private var token: NSObjectProtocol?
  private let logger = Logger(subsystem: "com.patrickdugan.halfway", category: "music")

  func start(_ handler: @escaping @MainActor (PlayerSnapshot) -> Void) {
    stop()
    let logger = logger
    token = DistributedNotificationCenter.default().addObserver(
      forName: Self.notificationName,
      object: nil,
      queue: .main
    ) { notification in
      let info = notification.userInfo ?? [:]
      let snapshot = Self.parse(info)
      logger.debug("playerInfo keys=\(info.keys.map { "\($0)" }.sorted(), privacy: .public)")
      logger.info(
        """
        playerInfo state=\(snapshot.state.rawValue, privacy: .public) \
        title=\(snapshot.track?.title ?? "-", privacy: .public) \
        artist=\(snapshot.track?.artist ?? "-", privacy: .public) \
        duration=\(snapshot.track?.duration ?? -1, privacy: .public) \
        id=\(snapshot.track?.id ?? "-", privacy: .public)
        """
      )
      MainActor.assumeIsolated { handler(snapshot) }
    }
  }

  func stop() {
    if let token {
      DistributedNotificationCenter.default().removeObserver(token)
    }
    token = nil
  }

  nonisolated static func parse(_ info: [AnyHashable: Any]) -> PlayerSnapshot {
    let state: PlayerSnapshot.State = switch info["Player State"] as? String {
    case "Playing": .playing
    case "Paused": .paused
    default: .stopped
    }

    func text(_ key: String) -> String? {
      guard let value = info[key] as? String else { return nil }
      let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
      return trimmed.isEmpty ? nil : trimmed
    }

    guard let title = text("Name"), let artist = text("Artist") else {
      return PlayerSnapshot(state: state, track: nil)
    }

    let album = text("Album")
    let duration = (info["Total Time"] as? NSNumber).map { $0.doubleValue / 1000 }
    let persistentID = (info["PersistentID"] as? NSNumber).map { String($0.int64Value) }
    let track = Track(
      id: persistentID ?? [artist, title, album ?? ""].joined(separator: "|"),
      title: title,
      artist: artist,
      album: album,
      albumArtist: text("Album Artist"),
      duration: duration.flatMap { $0 > 0 ? $0 : nil }
    )
    return PlayerSnapshot(state: state, track: track)
  }
}
