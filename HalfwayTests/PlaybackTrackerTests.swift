import Foundation
import Testing
@testable import Halfway

struct PlaybackTrackerTests {
  private let start = Date(timeIntervalSince1970: 1_000_000)

  private func track(_ id: String = "1", duration: TimeInterval? = 200) -> Track {
    Track(id: id, title: "Song \(id)", artist: "Artist", album: "Album", albumArtist: nil, duration: duration)
  }

  private func at(_ seconds: TimeInterval) -> Date { start.addingTimeInterval(seconds) }

  private func playing(_ track: Track) -> PlayerSnapshot { PlayerSnapshot(state: .playing, track: track) }

  private func paused(_ track: Track) -> PlayerSnapshot { PlayerSnapshot(state: .paused, track: track) }

  @Test
  func scrobblesAtHalfLengthWithStartTimestamp() {
    var tracker = PlaybackTracker()
    let song = track()
    #expect(tracker.handle(playing(song), at: at(0)) == [.nowPlaying(song)])
    #expect(tracker.nextDeadline(at: at(0)) == at(100))
    #expect(tracker.tick(at: at(99)).isEmpty)
    #expect(tracker.tick(at: at(100)) == [.scrobble(Scrobble(track: song, startedAt: at(0)))])
    #expect(tracker.tick(at: at(150)).isEmpty)
  }

  @Test
  func longTracksScrobbleAfterFourMinutes() {
    var tracker = PlaybackTracker()
    _ = tracker.handle(playing(track(duration: 600)), at: at(0))
    #expect(tracker.tick(at: at(239)).isEmpty)
    #expect(tracker.tick(at: at(240)).count == 1)
  }

  @Test
  func unknownLengthUsesFourMinutes() {
    var tracker = PlaybackTracker()
    _ = tracker.handle(playing(track(duration: nil)), at: at(0))
    #expect(tracker.nextDeadline(at: at(0)) == at(240))
  }

  @Test
  func shortTracksNeverScrobble() {
    var tracker = PlaybackTracker()
    _ = tracker.handle(playing(track(duration: 30)), at: at(0))
    #expect(tracker.tick(at: at(29)).isEmpty)
    #expect(tracker.handle(PlayerSnapshot(state: .stopped, track: nil), at: at(30)).isEmpty)
  }

  @Test
  func pausedTimeDoesNotCount() {
    var tracker = PlaybackTracker()
    let song = track()
    _ = tracker.handle(playing(song), at: at(0))
    #expect(tracker.handle(paused(song), at: at(60)).isEmpty)
    #expect(tracker.nextDeadline(at: at(500)) == nil)
    #expect(tracker.handle(playing(song), at: at(1000)) == [.nowPlaying(song)])
    #expect(tracker.tick(at: at(1039)).isEmpty)
    #expect(tracker.tick(at: at(1040)) == [.scrobble(Scrobble(track: song, startedAt: at(0)))])
  }

  @Test
  func skippingEarlyDoesNotScrobble() {
    var tracker = PlaybackTracker()
    let next = track("2")
    _ = tracker.handle(playing(track("1")), at: at(0))
    #expect(tracker.handle(playing(next), at: at(50)) == [.nowPlaying(next)])
    #expect(tracker.current?.startedAt == at(50))
  }

  @Test
  func switchingTracksAfterThresholdStillScrobblesOnce() {
    var tracker = PlaybackTracker()
    let first = track("1")
    let next = track("2")
    _ = tracker.handle(playing(first), at: at(0))
    let actions = tracker.handle(playing(next), at: at(150))
    #expect(actions == [.scrobble(Scrobble(track: first, startedAt: at(0))), .nowPlaying(next)])
  }

  @Test
  func duplicateNotificationsDoNotRestartThePlay() {
    var tracker = PlaybackTracker()
    let song = track()
    _ = tracker.handle(playing(song), at: at(0))
    #expect(tracker.handle(playing(song), at: at(50)).isEmpty)
    #expect(tracker.current?.startedAt == at(0))
    #expect(tracker.tick(at: at(100)).count == 1)
  }

  @Test
  func repeatOneNotificationStartsANewPlay() {
    var tracker = PlaybackTracker()
    let song = track()
    _ = tracker.handle(playing(song), at: at(0))
    _ = tracker.tick(at: at(100))
    #expect(tracker.handle(playing(song), at: at(199)) == [.nowPlaying(song)])
    #expect(tracker.tick(at: at(299)) == [.scrobble(Scrobble(track: song, startedAt: at(199)))])
  }

  @Test
  func silentRepeatIsDetectedFromLength() {
    var tracker = PlaybackTracker()
    let song = track()
    _ = tracker.handle(playing(song), at: at(0))
    _ = tracker.tick(at: at(100))
    #expect(tracker.nextDeadline(at: at(100)) == at(203))
    #expect(tracker.tick(at: at(203)) == [.nowPlaying(song)])
    #expect(tracker.tick(at: at(303)) == [.scrobble(Scrobble(track: song, startedAt: at(203)))])
  }
}
