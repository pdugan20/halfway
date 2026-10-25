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
  private enum CodingKeys: String, CodingKey {
    case id
    case track
    case startedAt
    case username
  }

  var id: UUID
  var track: Track
  /// When the play started, which is the timestamp Last.fm expects.
  var startedAt: Date
  /// The Last.fm account the play belongs to. Nil for plays queued before accounts were recorded.
  var username: String?

  init(track: Track, startedAt: Date, username: String? = nil, id: UUID = UUID()) {
    self.id = id
    self.track = track
    self.startedAt = startedAt
    self.username = username
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
    track = try container.decode(Track.self, forKey: .track)
    startedAt = try container.decode(Date.self, forKey: .startedAt)
    username = try container.decodeIfPresent(String.self, forKey: .username)
  }

  /// Two scrobbles are the same play when track, start time and account match; `id` is storage identity.
  static func ==(lhs: Scrobble, rhs: Scrobble) -> Bool {
    lhs.track == rhs.track && lhs.startedAt == rhs.startedAt && lhs.username == rhs.username
  }
}

/// A recent play shown in the menu with what happened to it.
nonisolated struct RecentScrobble: Codable, Equatable, Identifiable, Sendable {
  enum Status: String, Codable, Sendable {
    case waiting
    case sent
    /// Last.fm accepted the request but didn't count the play (for example, too old).
    case ignored
    /// Last.fm refused the request.
    case rejected
  }

  var id: UUID
  var title: String
  var artist: String
  var startedAt: Date
  var status: Status
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
