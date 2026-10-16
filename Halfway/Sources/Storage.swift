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

/// Scrobbles waiting to be sent, persisted so they survive quitting or going offline.
struct ScrobbleQueue {
  static var defaultURL: URL {
    URL.applicationSupportDirectory
      .appending(path: "Halfway", directoryHint: .isDirectory)
      .appending(path: "pending-scrobbles.json")
  }

  private(set) var items: [Scrobble] = []
  private let fileURL: URL

  init(fileURL: URL = ScrobbleQueue.defaultURL) {
    self.fileURL = fileURL
    if
      let data = try? Data(contentsOf: fileURL),
      let saved = try? JSONDecoder().decode([Scrobble].self, from: data) {
      items = saved
    }
  }

  mutating func append(_ scrobble: Scrobble) {
    items.append(scrobble)
    save()
  }

  mutating func removeFirst(_ count: Int) {
    items.removeFirst(min(count, items.count))
    save()
  }

  mutating func removeAll() {
    items.removeAll()
    save()
  }

  private func save() {
    try? FileManager.default.createDirectory(
      at: fileURL.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    try? JSONEncoder().encode(items).write(to: fileURL, options: .atomic)
  }
}
