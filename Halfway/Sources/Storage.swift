import Foundation
import Security

nonisolated struct StoredSession: Codable, Equatable, Sendable {
  var username: String
  var key: String
}

/// Keeps the Last.fm session key in the login keychain.
enum SessionStore {
  private static let service = "com.patrickdugan.halfway.lastfm"
  private static let account = "session"

  static func load() -> StoredSession? {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
      kSecReturnData as String: true,
    ]
    var result: AnyObject?
    guard
      SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
      let data = result as? Data
    else { return nil }
    return try? JSONDecoder().decode(StoredSession.self, from: data)
  }

  static func save(_ session: StoredSession) {
    clear()
    guard let data = try? JSONEncoder().encode(session) else { return }
    let item: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
      kSecAttrLabel as String: "Halfway Last.fm session",
      kSecValueData as String: data,
    ]
    SecItemAdd(item as CFDictionary, nil)
  }

  static func clear() {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
    ]
    SecItemDelete(query as CFDictionary)
  }
}

/// A JSON file in Application Support (inside the sandbox container).
nonisolated struct JSONFile<Value: Codable> {
  let url: URL

  init(_ name: String) {
    url = URL.applicationSupportDirectory
      .appending(path: "Halfway", directoryHint: .isDirectory)
      .appending(path: name)
  }

  init(url: URL) {
    self.url = url
  }

  func load() -> Value? {
    guard let data = try? Data(contentsOf: url) else { return nil }
    return try? JSONDecoder().decode(Value.self, from: data)
  }

  func save(_ value: Value) {
    try? FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    try? JSONEncoder().encode(value).write(to: url, options: .atomic)
  }
}

/// Scrobbles waiting to be sent. They survive quitting, going offline and signing out,
/// and are only sent to the account they were played under.
nonisolated struct ScrobbleQueue {
  /// Last.fm ignores scrobbles older than two weeks.
  static let maximumAge: TimeInterval = 14 * 24 * 60 * 60

  private(set) var items: [Scrobble]
  private let file: JSONFile<[Scrobble]>

  init(file: JSONFile<[Scrobble]> = JSONFile("pending-scrobbles.json")) {
    self.file = file
    items = file.load() ?? []
  }

  /// Plays that belong to `username`, oldest first. Unattributed plays go to whoever signs in.
  func items(for username: String) -> [Scrobble] {
    items.filter { $0.username == nil || $0.username == username }
  }

  mutating func append(_ scrobble: Scrobble) {
    items.append(scrobble)
    file.save(items)
  }

  mutating func remove(ids: Set<UUID>) {
    items.removeAll { ids.contains($0.id) }
    file.save(items)
  }

  /// Drops plays Last.fm would ignore as too old and returns their ids.
  mutating func pruneExpired(now: Date) -> Set<UUID> {
    let expired = Set(items.filter { now.timeIntervalSince($0.startedAt) > Self.maximumAge }.map(\.id))
    if !expired.isEmpty { remove(ids: expired) }
    return expired
  }
}

/// The last few plays and their outcome, newest first.
nonisolated struct RecentScrobbles {
  static let limit = 10

  private(set) var items: [RecentScrobble]
  private let file: JSONFile<[RecentScrobble]>

  init(file: JSONFile<[RecentScrobble]> = JSONFile("recent-scrobbles.json")) {
    self.file = file
    items = file.load() ?? []
  }

  mutating func record(_ scrobble: Scrobble) {
    let entry = RecentScrobble(
      id: scrobble.id,
      title: scrobble.track.title,
      artist: scrobble.track.artist,
      startedAt: scrobble.startedAt,
      status: .waiting
    )
    items.insert(entry, at: 0)
    items = Array(items.prefix(Self.limit))
    file.save(items)
  }

  mutating func update(_ statuses: [UUID: RecentScrobble.Status]) {
    guard !statuses.isEmpty else { return }
    for index in items.indices {
      if let status = statuses[items[index].id] { items[index].status = status }
    }
    file.save(items)
  }
}
