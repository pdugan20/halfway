import Foundation

/// The request boundary lets account-lifecycle tests use a suspended, offline client.
nonisolated protocol LastFMService: Sendable {
  func getToken() async throws -> String
  func authorizationURL(token: String) -> URL
  func getSession(token: String) async throws -> StoredSession
  func updateNowPlaying(_ track: Track, sessionKey: String) async throws
  func scrobble(_ scrobbles: [Scrobble], sessionKey: String) async throws -> [LastFMClient.Outcome]
  func love(_ track: Track, sessionKey: String) async throws
  func unlove(_ track: Track, sessionKey: String) async throws
  func isLoved(_ track: Track, username: String) async throws -> Bool
}

extension LastFMClient: LastFMService { }
