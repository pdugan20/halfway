import AppKit
import Network
import Observation
import OSLog
import ServiceManagement

/// Wires Music playback, the scrobble rules, the pending queue and Last.fm together.
@Observable
final class AppModel {
  enum Account: Equatable {
    case signedOut
    case waitingForApproval
    case signedIn(username: String)
  }

  private(set) var account: Account = .signedOut
  private(set) var play: PlaybackTracker.Play?
  private(set) var pendingCount = 0
  private(set) var message: String?
  private(set) var opensAtLogin = SMAppService.mainApp.status == .enabled
  var isScrobblingEnabled = UserDefaults.standard.object(forKey: "scrobblingEnabled") as? Bool ?? true {
    didSet { UserDefaults.standard.set(isScrobblingEnabled, forKey: "scrobblingEnabled") }
  }

  let isConfigured: Bool

  @ObservationIgnored private let client: LastFMClient
  @ObservationIgnored private let observer = MusicObserver()
  @ObservationIgnored private let pathMonitor = NWPathMonitor()
  @ObservationIgnored private let logger = Logger(subsystem: "com.patrickdugan.halfway", category: "scrobble")
  @ObservationIgnored private var tracker = PlaybackTracker()
  @ObservationIgnored private var queue = ScrobbleQueue()
  @ObservationIgnored private var session: StoredSession?
  @ObservationIgnored private var tickTask: Task<Void, Never>?
  @ObservationIgnored private var signInTask: Task<Void, Never>?
  @ObservationIgnored private var retryTask: Task<Void, Never>?
  @ObservationIgnored private var isFlushing = false

  init() {
    let info = Bundle.main.infoDictionary ?? [:]
    let apiKey = info["LastFMAPIKey"] as? String ?? ""
    let secret = info["LastFMAPISecret"] as? String ?? ""
    client = LastFMClient(apiKey: apiKey, secret: secret)
    isConfigured = !apiKey.isEmpty && !secret.isEmpty

    if let stored = SessionStore.load() {
      session = stored
      account = .signedIn(username: stored.username)
    }
    pendingCount = queue.items.count

    observer.start { [weak self] snapshot in self?.handle(snapshot) }
    pathMonitor.pathUpdateHandler = { [weak self] path in
      guard path.status == .satisfied else { return }
      Task { @MainActor in self?.flush() }
    }
    pathMonitor.start(queue: DispatchQueue(label: "com.patrickdugan.halfway.network"))
    flush()
  }

  var menuBarSymbol: String {
    if case .signedIn = account, isScrobblingEnabled { return "circle.lefthalf.filled" }
    return "circle.dashed"
  }

  var profileURL: URL? {
    guard case .signedIn(let username) = account else { return nil }
    return URL(string: "https://www.last.fm/user/")?.appending(path: username)
  }

  // MARK: Account

  func signIn() {
    guard isConfigured else { return }
    signInTask?.cancel()
    account = .waitingForApproval
    message = nil
    signInTask = Task { [weak self] in
      guard let self else { return }
      do {
        let token = try await client.getToken()
        NSWorkspace.shared.open(client.authorizationURL(token: token))
        // Tokens last 60 minutes; give the user ten to approve.
        let deadline = Date.now.addingTimeInterval(600)
        while Date.now < deadline {
          try await Task.sleep(for: .seconds(3))
          do {
            let stored = try await client.getSession(token: token)
            SessionStore.save(stored)
            session = stored
            account = .signedIn(username: stored.username)
            logger.info("signed in as \(stored.username, privacy: .public)")
            flush()
            return
          } catch LastFMClient.Failure.api(code: 14, message: _) {
            continue // Not approved yet.
          }
        }
        account = .signedOut
        message = "Sign-in timed out. Try again."
      } catch is CancellationError {
        // Cancelled by the user.
      } catch {
        account = .signedOut
        message = "Couldn't sign in. \(Self.describe(error))"
      }
    }
  }

  func cancelSignIn() {
    signInTask?.cancel()
    signInTask = nil
    account = .signedOut
  }

  func signOut() {
    signInTask?.cancel()
    retryTask?.cancel()
    SessionStore.clear()
    session = nil
    queue.removeAll()
    pendingCount = 0
    account = .signedOut
    message = nil
  }

  func setOpensAtLogin(_ enabled: Bool) {
    do {
      if enabled {
        try SMAppService.mainApp.register()
      } else {
        try SMAppService.mainApp.unregister()
      }
    } catch {
      message = "Couldn't change Open at Login. \(error.localizedDescription)"
    }
    opensAtLogin = SMAppService.mainApp.status == .enabled
  }

  // MARK: Playback

  private static func describe(_ error: Error) -> String {
    switch error {
    case LastFMClient.Failure.api(_, let message): message
    case LastFMClient.Failure.network(let message): message
    case LastFMClient.Failure.badResponse: "Last.fm sent an unexpected response."
    default: error.localizedDescription
    }
  }

  private func handle(_ snapshot: PlayerSnapshot) {
    perform(tracker.handle(snapshot, at: .now))
    scheduleTick()
  }

  private func scheduleTick() {
    tickTask?.cancel()
    play = tracker.current
    guard let deadline = tracker.nextDeadline(at: .now) else { return }
    tickTask = Task { [weak self] in
      try? await Task.sleep(for: .seconds(max(0.1, deadline.timeIntervalSinceNow + 0.05)))
      guard !Task.isCancelled, let self else { return }
      perform(tracker.tick(at: .now))
      scheduleTick()
    }
  }

  private func perform(_ actions: [PlaybackTracker.Action]) {
    play = tracker.current
    guard isScrobblingEnabled, let session else { return }
    for action in actions {
      switch action {
      case .nowPlaying(let track):
        Task { [client, logger] in
          do {
            try await client.updateNowPlaying(track, sessionKey: session.key)
          } catch {
            logger.error("now playing failed: \(String(describing: error), privacy: .public)")
          }
        }
      case .scrobble(let scrobble):
        let track = scrobble.track
        logger.info("scrobble due: \(track.artist, privacy: .public) – \(track.title, privacy: .public)")
        queue.append(scrobble)
        pendingCount = queue.items.count
        flush()
      }
    }
  }

  // MARK: Sending

  private func flush() {
    guard !isFlushing, let session, !queue.items.isEmpty else { return }
    isFlushing = true
    let batch = Array(queue.items.prefix(50))
    Task { [weak self, client] in
      let result: Result<(accepted: Int, ignored: Int), LastFMClient.Failure>
      do {
        result = try await .success(client.scrobble(batch, sessionKey: session.key))
      } catch let failure as LastFMClient.Failure {
        result = .failure(failure)
      } catch {
        result = .failure(.network(error.localizedDescription))
      }
      self?.finishFlush(batch: batch, result: result)
    }
  }

  private func finishFlush(batch: [Scrobble], result: Result<(accepted: Int, ignored: Int), LastFMClient.Failure>) {
    isFlushing = false
    switch result {
    case .success(let counts):
      logger.info("sent \(batch.count) scrobbles: \(counts.accepted) accepted, \(counts.ignored) ignored")
      queue.removeFirst(batch.count)
      message = nil
      pendingCount = queue.items.count
      flush()
    case .failure(let failure) where failure.needsReauth:
      SessionStore.clear()
      session = nil
      account = .signedOut
      message = "Last.fm signed you out. Sign in again to send waiting scrobbles."
    case .failure(let failure) where failure.isTransient:
      logger.error("send failed, will retry: \(String(describing: failure), privacy: .public)")
      retryTask?.cancel()
      retryTask = Task { [weak self] in
        try? await Task.sleep(for: .seconds(60))
        guard !Task.isCancelled else { return }
        self?.flush()
      }
    case .failure(let failure):
      // Last.fm rejected the request itself; drop it so the queue can't jam.
      logger.error("dropping \(batch.count) scrobbles: \(String(describing: failure), privacy: .public)")
      queue.removeFirst(batch.count)
      pendingCount = queue.items.count
      message = "Last.fm rejected some scrobbles. \(Self.describe(failure))"
    }
  }
}
