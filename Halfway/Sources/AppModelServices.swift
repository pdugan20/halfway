import AppKit

/// Production defaults are evaluated only by the live initializer, never by isolated tests.
struct AppModelServices {
  struct AccountIO {
    var saveSession: @MainActor (StoredSession) -> Void = SessionStore.save
    var clearSession: @MainActor () -> Void = SessionStore.clear
    var openAuthorization: @MainActor (URL) -> Void = { NSWorkspace.shared.open($0) }
    var activate: @MainActor () -> Void = { NSApp.activate() }
    var pollInterval: Duration = .seconds(3)
    var now: @MainActor () -> Date = { .now }
  }

  var client: any LastFMService
  var storedSession: StoredSession?
  var queue: ScrobbleQueue
  var recent: RecentScrobbles
  var isConfigured = true
  var accountIO = AccountIO()

  static var live: Self {
    let info = Bundle.main.infoDictionary ?? [:]
    let apiKey = info["LastFMAPIKey"] as? String ?? ""
    let secret = info["LastFMAPISecret"] as? String ?? ""
    return Self(
      client: LastFMClient(apiKey: apiKey, secret: secret),
      storedSession: SessionStore.load(),
      queue: ScrobbleQueue(),
      recent: RecentScrobbles(),
      isConfigured: !apiKey.isEmpty && !secret.isEmpty
    )
  }
}
