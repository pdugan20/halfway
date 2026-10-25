import CryptoKit
import Foundation

/// Minimal Last.fm API client: desktop auth, now playing and scrobbling.
nonisolated struct LastFMClient: Sendable {
  /// What Last.fm did with one scrobble in a batch.
  enum Outcome: Equatable, Sendable {
    case accepted
    case ignored(String)
  }

  enum Failure: Error, Equatable {
    case api(code: Int, message: String)
    case badResponse
    case network(String)

    /// Worth retrying later without user action.
    var isTransient: Bool {
      switch self {
      case .network, .badResponse: true
      case .api(let code, _): [8, 11, 16, 29].contains(code)
      }
    }

    /// The stored session no longer works and the user must sign in again.
    var needsReauth: Bool {
      if case .api(let code, _) = self { return [4, 9, 26].contains(code) }
      return false
    }
  }

  static let endpoint = URL(string: "https://ws.audioscrobbler.com/2.0/")!

  let apiKey: String
  let secret: String
  var session: URLSession = .shared

  /// Last.fm signature: every parameter except `format` and `callback`, sorted
  /// by name, concatenated as name+value, followed by the secret, MD5-hashed.
  static func signature(_ params: [String: String], secret: String) -> String {
    let payload = params
      .filter { $0.key != "format" && $0.key != "callback" }
      .sorted { $0.key < $1.key }
      .map { $0.key + $0.value }
      .joined() + secret
    return Insecure.MD5.hash(data: Data(payload.utf8))
      .map { String(format: "%02x", $0) }
      .joined()
  }

  static func formBody(_ params: [String: String]) -> Data {
    var allowed = CharacterSet.alphanumerics
    allowed.insert(charactersIn: "-._~")
    let body = params
      .sorted { $0.key < $1.key }
      .map { key, value in
        let name = key.addingPercentEncoding(withAllowedCharacters: allowed) ?? key
        let encoded = value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
        return "\(name)=\(encoded)"
      }
      .joined(separator: "&")
    return Data(body.utf8)
  }

  // MARK: Auth

  func getToken() async throws -> String {
    let json = try await call("auth.getToken")
    guard let token = json["token"] as? String else { throw Failure.badResponse }
    return token
  }

  func authorizationURL(token: String) -> URL {
    var components = URLComponents(string: "https://www.last.fm/api/auth/")!
    components.queryItems = [
      URLQueryItem(name: "api_key", value: apiKey),
      URLQueryItem(name: "token", value: token),
    ]
    return components.url!
  }

  /// Exchanges an approved token for a session. Throws `.api(14)` until the
  /// user approves the token in the browser.
  func getSession(token: String) async throws -> StoredSession {
    let json = try await call("auth.getSession", ["token": token])
    guard
      let session = json["session"] as? [String: Any],
      let name = session["name"] as? String,
      let key = session["key"] as? String
    else { throw Failure.badResponse }
    return StoredSession(username: name, key: key)
  }

  // MARK: Scrobbling

  func updateNowPlaying(_ track: Track, sessionKey: String) async throws {
    var params = ["artist": track.artist, "track": track.title]
    params["album"] = track.album
    params["albumArtist"] = track.albumArtist
    params["duration"] = track.duration.map { String(Int($0.rounded())) }
    _ = try await call("track.updateNowPlaying", params, sessionKey: sessionKey)
  }

  /// Sends up to 50 scrobbles and returns one outcome per scrobble, in order.
  func scrobble(_ scrobbles: [Scrobble], sessionKey: String) async throws -> [Outcome] {
    precondition(scrobbles.count <= 50, "Last.fm accepts at most 50 scrobbles per request")
    var params: [String: String] = [:]
    for (index, item) in scrobbles.enumerated() {
      params["artist[\(index)]"] = item.track.artist
      params["track[\(index)]"] = item.track.title
      params["timestamp[\(index)]"] = String(Int(item.startedAt.timeIntervalSince1970))
      params["album[\(index)]"] = item.track.album
      params["albumArtist[\(index)]"] = item.track.albumArtist
      params["duration[\(index)]"] = item.track.duration.map { String(Int($0.rounded())) }
    }
    let json = try await call("track.scrobble", params, sessionKey: sessionKey)
    return try Self.outcomes(from: json, count: scrobbles.count)
  }

  func love(_ track: Track, sessionKey: String) async throws {
    _ = try await call("track.love", ["artist": track.artist, "track": track.title], sessionKey: sessionKey)
  }

  func unlove(_ track: Track, sessionKey: String) async throws {
    _ = try await call("track.unlove", ["artist": track.artist, "track": track.title], sessionKey: sessionKey)
  }

  /// Whether `username` has loved `track` on Last.fm.
  func isLoved(_ track: Track, username: String) async throws -> Bool {
    let json = try await call(
      "track.getInfo",
      ["artist": track.artist, "track": track.title, "username": username, "autocorrect": "1"]
    )
    guard let info = json["track"] as? [String: Any] else { throw Failure.badResponse }
    return Self.int(info["userloved"]) == 1
  }

  /// Reads per-scrobble results. Last.fm returns an object for one scrobble and an array for several.
  static func outcomes(from json: [String: Any], count: Int) throws -> [Outcome] {
    guard let scrobbles = json["scrobbles"] as? [String: Any] else { throw Failure.badResponse }
    let entries: [[String: Any]] = if let list = scrobbles["scrobble"] as? [[String: Any]] {
      list
    } else if let single = scrobbles["scrobble"] as? [String: Any] {
      [single]
    } else {
      []
    }
    guard entries.count == count else {
      // Results can't be matched to plays. The request succeeded, so treat them as sent
      // rather than resending and risking duplicates.
      return Array(repeating: .accepted, count: count)
    }
    return entries.map { entry in
      let ignored = entry["ignoredMessage"] as? [String: Any] ?? [:]
      guard int(ignored["code"]) != 0 else { return .accepted }
      return .ignored(ignored["#text"] as? String ?? "Ignored by Last.fm")
    }
  }

  static func describe(_ error: Error) -> String {
    switch error {
    case LastFMClient.Failure.api(_, let message): message
    case LastFMClient.Failure.network(let message): message
    case LastFMClient.Failure.badResponse: "Last.fm sent an unexpected response."
    default: error.localizedDescription
    }
  }

  // MARK: Private

  private static func int(_ value: Any?) -> Int {
    if let number = value as? Int { return number }
    if let text = value as? String { return Int(text) ?? 0 }
    return 0
  }

  private func call(
    _ method: String,
    _ extra: [String: String] = [:],
    sessionKey: String? = nil
  ) async throws -> [String: Any] {
    var params = extra
    params["method"] = method
    params["api_key"] = apiKey
    params["sk"] = sessionKey
    params["api_sig"] = Self.signature(params, secret: secret)
    params["format"] = "json"

    var request = URLRequest(url: Self.endpoint)
    request.httpMethod = "POST"
    request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
    request.setValue("Halfway/0.1 (macOS)", forHTTPHeaderField: "User-Agent")
    request.httpBody = Self.formBody(params)
    request.timeoutInterval = 20

    let data: Data
    do {
      (data, _) = try await session.data(for: request)
    } catch {
      throw Failure.network(error.localizedDescription)
    }
    guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
      throw Failure.badResponse
    }
    if let code = json["error"] as? Int {
      throw Failure.api(code: code, message: json["message"] as? String ?? "Unknown error")
    }
    return json
  }
}
