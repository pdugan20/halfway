import Foundation

/// Turns Music playback events into Last.fm "now playing" and scrobble actions.
///
/// Last.fm's rule: a track longer than 30 seconds scrobbles once it has played
/// for half its length or four minutes, whichever comes first. Listening time is
/// counted only while Music reports `playing`, so pauses don't count.
nonisolated struct PlaybackTracker {
  enum Action: Equatable {
    case nowPlaying(Track)
    case scrobble(Scrobble)
  }

  struct Play: Equatable {
    var track: Track
    var startedAt: Date
    /// Listening time banked before the current playing stretch.
    var banked: TimeInterval = 0
    /// Start of the current playing stretch, or nil while paused.
    var resumedAt: Date?
    var scrobbled = false

    var isPlaying: Bool { resumedAt != nil }

    func listened(at now: Date) -> TimeInterval {
      banked + (resumedAt.map { max(0, now.timeIntervalSince($0)) } ?? 0)
    }
  }

  static let minimumLength: TimeInterval = 30
  static let maximumWait: TimeInterval = 240
  /// Slack used to recognise a track that looped (repeat one) without a new event.
  static let loopSlack: TimeInterval = 3

  private(set) var current: Play?

  /// Listening time needed before `track` scrobbles, or nil if it never will.
  /// Without a known length we fall back to the four-minute rule.
  static func threshold(for track: Track) -> TimeInterval? {
    guard let duration = track.duration else { return maximumWait }
    guard duration > minimumLength else { return nil }
    return min(duration / 2, maximumWait)
  }

  mutating func handle(_ snapshot: PlayerSnapshot, at now: Date) -> [Action] {
    switch snapshot.state {
    case .playing:
      guard let track = snapshot.track else { return stop(at: now) }
      return play(track, at: now)
    case .paused:
      let actions = evaluate(at: now)
      if var play = current, play.isPlaying {
        play.banked = play.listened(at: now)
        play.resumedAt = nil
        current = play
      }
      return actions
    case .stopped:
      return stop(at: now)
    }
  }

  /// Call when `nextDeadline` passes, or any time, to emit due scrobbles.
  mutating func tick(at now: Date) -> [Action] {
    var actions = evaluate(at: now)
    if
      let play = current, play.isPlaying, let duration = play.track.duration,
      play.listened(at: now) >= duration + Self.loopSlack {
      // Repeat-one loops don't always produce a new notification.
      actions += restart(play.track, at: now)
    }
    return actions
  }

  /// The next moment `tick` could produce an action.
  func nextDeadline(at now: Date) -> Date? {
    guard let play = current, let resumedAt = play.resumedAt else { return nil }
    var targets: [TimeInterval] = []
    if !play.scrobbled, let threshold = Self.threshold(for: play.track) {
      targets.append(threshold)
    }
    if let duration = play.track.duration {
      targets.append(duration + Self.loopSlack)
    }
    guard let target = targets.min() else { return nil }
    return max(now, resumedAt.addingTimeInterval(target - play.banked))
  }

  // MARK: Private

  private mutating func play(_ track: Track, at now: Date) -> [Action] {
    guard var play = current, play.track.id == track.id else {
      return evaluate(at: now) + restart(track, at: now)
    }
    play.track = track
    if !play.isPlaying {
      play.resumedAt = now
      current = play
      return evaluate(at: now) + [.nowPlaying(track)]
    }
    current = play
    // Already playing the same track. If it has nearly run its length, this is
    // a repeat; otherwise it's a duplicate notification (rating, artwork, etc.).
    if let duration = track.duration, play.listened(at: now) >= duration - Self.loopSlack {
      return evaluate(at: now) + restart(track, at: now)
    }
    return evaluate(at: now)
  }

  private mutating func restart(_ track: Track, at now: Date) -> [Action] {
    current = Play(track: track, startedAt: now, resumedAt: now)
    return [.nowPlaying(track)]
  }

  private mutating func stop(at now: Date) -> [Action] {
    let actions = evaluate(at: now)
    current = nil
    return actions
  }

  private mutating func evaluate(at now: Date) -> [Action] {
    guard
      var play = current, !play.scrobbled,
      let threshold = Self.threshold(for: play.track),
      play.listened(at: now) >= threshold
    else { return [] }
    play.scrobbled = true
    current = play
    return [.scrobble(Scrobble(track: play.track, startedAt: play.startedAt))]
  }
}
