import Foundation

/// A track as reported by Music, reduced to what Last.fm needs.
nonisolated struct Track: Codable, Equatable, Hashable, Sendable {
  /// Stable identity for the current play. Music's persistent ID when available.
  var id: String
  var title: String
  var artist: String
  var album: String?
  var albumArtist: String?
  /// Length in seconds, when Music reports it.
  var duration: TimeInterval?
}

/// A play that met Last.fm's scrobble rules and is waiting to be sent.
nonisolated struct Scrobble: Codable, Equatable, Sendable {
  var track: Track
  /// When the play started, which is the timestamp Last.fm expects.
  var startedAt: Date
}

/// One `com.apple.Music.playerInfo` notification, parsed.
nonisolated struct PlayerSnapshot: Equatable, Sendable {
  enum State: String, Sendable {
    case playing
    case paused
    case stopped
  }

  var state: State
  var track: Track?
}
