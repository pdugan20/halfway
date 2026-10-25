import Foundation
import Testing
@testable import Halfway

struct StorageTests {
  private struct LegacyScrobble: Codable {
    var track: Track
    var startedAt: Date
  }

  private let now = Date(timeIntervalSince1970: 2_000_000_000)
  private let track = Track(id: "1", title: "Song", artist: "Artist", album: nil, albumArtist: nil, duration: 200)

  private func tempURL(_ name: String) -> URL {
    FileManager.default.temporaryDirectory
      .appending(path: "halfway-tests-\(UUID().uuidString)")
      .appending(path: name)
  }

  @Test
  func queueKeepsPlaysPerAccountAcrossReloads() {
    let file = JSONFile<[Scrobble]>(url: tempURL("queue.json"))
    var queue = ScrobbleQueue(file: file)
    let mine = Scrobble(track: track, startedAt: now, username: "pat")
    let theirs = Scrobble(track: track, startedAt: now, username: "sam")
    queue.append(mine)
    queue.append(theirs)

    let reloaded = ScrobbleQueue(file: file)
    #expect(reloaded.items.count == 2)
    #expect(reloaded.items(for: "pat").map(\.id) == [mine.id])
    #expect(reloaded.items(for: "sam").map(\.id) == [theirs.id])
  }

  @Test
  func removesByIDAndPrunesExpiredPlays() {
    var queue = ScrobbleQueue(file: JSONFile(url: tempURL("queue.json")))
    let old = Scrobble(track: track, startedAt: now.addingTimeInterval(-ScrobbleQueue.maximumAge - 1), username: "pat")
    let fresh = Scrobble(track: track, startedAt: now.addingTimeInterval(-60), username: "pat")
    queue.append(old)
    queue.append(fresh)

    #expect(queue.pruneExpired(now: now) == [old.id])
    #expect(queue.items.map(\.id) == [fresh.id])
    queue.remove(ids: [fresh.id])
    #expect(queue.items.isEmpty)
  }

  @Test
  func legacyQueueEntriesLoadForWhoeverSignsIn() throws {
    let url = tempURL("queue.json")
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try JSONEncoder().encode([LegacyScrobble(track: track, startedAt: now)]).write(to: url)

    let queue = ScrobbleQueue(file: JSONFile(url: url))
    #expect(queue.items.count == 1)
    #expect(queue.items(for: "anyone").count == 1)
  }

  @Test
  func recentListKeepsNewestTenAndUpdatesStatus() {
    var recent = RecentScrobbles(file: JSONFile(url: tempURL("recent.json")))
    let scrobbles = (0..<12).map { Scrobble(track: track, startedAt: now.addingTimeInterval(Double($0))) }
    scrobbles.forEach { recent.record($0) }

    #expect(recent.items.count == RecentScrobbles.limit)
    #expect(recent.items.first?.id == scrobbles.last?.id)
    #expect(recent.items.allSatisfy { $0.status == .waiting })

    recent.update([scrobbles[11].id: .sent, scrobbles[10].id: .ignored])
    #expect(recent.items[0].status == .sent)
    #expect(recent.items[1].status == .ignored)
  }
}
