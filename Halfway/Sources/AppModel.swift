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
  private(set) var recent: [RecentScrobble] = []
  /// Whether the current track is loved on Last.fm; nil while unknown.
  private(set) var isCurrentTrackLoved: Bool?
  /// Progress toward the current track's scrobble point, in sixteenths, for the menu bar icon.
  private(set) var scrobbleProgress = 0.0
  private(set) var message: String?
  private(set) var opensAtLogin = SMAppService.mainApp.status == .enabled
  /// macOS registered the login item but the user switched it off in System Settings.
  private(set) var loginItemNeedsApproval = SMAppService.mainApp.status == .requiresApproval
  private(set) var hasCompletedSetup = UserDefaults.standard.bool(forKey: "hasCompletedSetup")
  var isScrobblingEnabled = UserDefaults.standard.object(forKey: "scrobblingEnabled") as? Bool ?? true {
    didSet { UserDefaults.standard.set(isScrobblingEnabled, forKey: "scrobblingEnabled") }
  }

  let isConfigured: Bool

  @ObservationIgnored private let client: any LastFMService
  @ObservationIgnored private let accountIO: AppModelServices.AccountIO
  @ObservationIgnored private let observer = MusicObserver()
  @ObservationIgnored private let pathMonitor = NWPathMonitor()
  @ObservationIgnored private let logger = Logger(subsystem: "com.patrickdugan.halfway", category: "scrobble")
  @ObservationIgnored private var tracker = PlaybackTracker()
  @ObservationIgnored private var queue: ScrobbleQueue
  @ObservationIgnored private var recentStore: RecentScrobbles
  @ObservationIgnored private var session: StoredSession?
  @ObservationIgnored private var lovedTrackID: String?
  @ObservationIgnored private var tickTask: Task<Void, Never>?
  @ObservationIgnored private var progressTask: Task<Void, Never>?
  @ObservationIgnored private(set) var signInTask: Task<Void, Never>?
  @ObservationIgnored private(set) var flushTask: Task<Void, Never>?
  @ObservationIgnored private(set) var loveUpdateTask: Task<Void, Never>?
  private var loveUpdateID: UUID?
  var isUpdatingLove: Bool { loveUpdateID != nil }
  @ObservationIgnored private var retryTask: Task<Void, Never>?
  @ObservationIgnored private(set) var lovedTask: Task<Void, Never>?
  @ObservationIgnored private var isFlushing = false

  init(services: AppModelServices = .live, startsObservers: Bool = true) {
    client = services.client
    accountIO = services.accountIO
    queue = services.queue
    recentStore = services.recent
    isConfigured = services.isConfigured
    session = services.storedSession
    if let stored = session { account = .signedIn(username: stored.username) }
    recent = recentStore.items
    refreshPendingCount()
    guard startsObservers else { return }

    observer.start { [weak self] snapshot in self?.handle(snapshot) }
    pathMonitor.pathUpdateHandler = { [weak self] path in
      guard path.status == .satisfied else { return }
      Task { @MainActor in self?.flush() }
    }
    pathMonitor.start(queue: DispatchQueue(label: "com.patrickdugan.halfway.network"))
    flush()
  }

  var menuBarIcon: MenuBarIcon.State {
    guard isSignedIn, isScrobblingEnabled else { return .inactive }
    guard let play, PlaybackTracker.threshold(for: play.track) != nil else { return .idle }
    return play.scrobbled ? .scrobbled : .progress(scrobbleProgress)
  }

  var profileURL: URL? {
    guard case .signedIn(let username) = account else { return nil }
    return URL(string: "https://www.last.fm/user/")?.appending(path: username)
  }

  var isSignedIn: Bool {
    if case .signedIn = account { return true }
    return false
  }

  // MARK: Setup

  func completeSetup() {
    hasCompletedSetup = true
    UserDefaults.standard.set(true, forKey: "hasCompletedSetup")
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
    refreshLoginItemStatus()
  }

  /// Re-reads the login item, which the user can also change in System Settings.
  func refreshLoginItemStatus() {
    let status = SMAppService.mainApp.status
    opensAtLogin = status == .enabled
    loginItemNeedsApproval = status == .requiresApproval
  }

  func openLoginItemsSettings() {
    SMAppService.openSystemSettingsLoginItems()
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
        try Task.checkCancellation()
        accountIO.openAuthorization(client.authorizationURL(token: token))
        // Tokens last 60 minutes; give the user ten to approve.
        let deadline = accountIO.now().addingTimeInterval(600)
        while accountIO.now() < deadline {
          try await Task.sleep(for: accountIO.pollInterval)
          do {
            let stored = try await client.getSession(token: token)
            try Task.checkCancellation()
            finishSignIn(stored)
            return
          } catch LastFMClient.Failure.api(code: 14, message: _) {
            continue // Not approved yet.
          }
        }
        try Task.checkCancellation()
        account = .signedOut
        message = "Sign-in timed out. Try again."
      } catch is CancellationError {
        // Cancelled by the user.
      } catch {
        guard !Task.isCancelled else { return }
        account = .signedOut
        message = "Couldn't sign in. \(LastFMClient.describe(error))"
      }
    }
  }

  func cancelSignIn() {
    signInTask?.cancel()
    signInTask = nil
    account = .signedOut
  }

  /// Signs out but keeps waiting scrobbles; they're sent if the same account signs in again.
  func signOut() {
    signInTask?.cancel()
    retryTask?.cancel()
    lovedTask?.cancel()
    loveUpdateTask?.cancel()
    loveUpdateID = nil
    accountIO.clearSession()
    session = nil
    account = .signedOut
    message = nil
    lovedTrackID = nil
    isCurrentTrackLoved = nil
    refreshPendingCount()
  }

  // MARK: Private

  private func finishSignIn(_ stored: StoredSession) {
    accountIO.saveSession(stored)
    session = stored
    account = .signedIn(username: stored.username)
    logger.info("signed in as \(stored.username, privacy: .public)")
    // Bring the welcome or Settings window back from the browser.
    accountIO.activate()
    loveUpdateTask?.cancel()
    loveUpdateID = nil
    refreshPendingCount()
    lovedTrackID = nil
    if let track = play?.track { refreshLovedState(for: track) }
    flush()
  }

  private func refreshPendingCount() {
    pendingCount = session.map { queue.items(for: $0.username).count } ?? 0
  }

  func handle(_ snapshot: PlayerSnapshot) {
    perform(tracker.handle(snapshot, at: .now))
    scheduleTick()
  }

  private func scheduleTick() {
    tickTask?.cancel()
    play = tracker.current
    refreshProgress()
    guard let deadline = tracker.nextDeadline(at: .now) else { return }
    tickTask = Task { [weak self] in
      try? await Task.sleep(for: .seconds(max(0.1, deadline.timeIntervalSinceNow + 0.05)))
      guard !Task.isCancelled, let self else { return }
      perform(tracker.tick(at: .now))
      scheduleTick()
    }
  }

  /// Updates the menu bar progress in sixteenths, waking once per step while playing.
  private func refreshProgress() {
    progressTask?.cancel()
    guard let play, !play.scrobbled, let threshold = PlaybackTracker.threshold(for: play.track) else {
      scrobbleProgress = 0
      return
    }
    scrobbleProgress = (min(play.listened(at: .now) / threshold, 1) * 16).rounded(.down) / 16
    guard play.isPlaying else { return }
    progressTask = Task { [weak self] in
      try? await Task.sleep(for: .seconds(max(1, threshold / 16)))
      guard !Task.isCancelled else { return }
      self?.refreshProgress()
    }
  }
}

// MARK: - Love

extension AppModel {
  func toggleLove() {
    guard !isUpdatingLove, let session, let track = play?.track, let loved = isCurrentTrackLoved else { return }
    let operation = UUID()
    loveUpdateID = operation
    isCurrentTrackLoved = !loved
    loveUpdateTask = Task { [weak self, client] in
      defer {
        if self?.loveUpdateID == operation { self?.loveUpdateID = nil }
      }
      do {
        if loved {
          try await client.unlove(track, sessionKey: session.key)
        } else {
          try await client.love(track, sessionKey: session.key)
        }
      } catch {
        guard let self, self.session == session, lovedTrackID == track.id else { return }
        isCurrentTrackLoved = loved
        message = "Couldn't update Love on Last.fm. \(LastFMClient.describe(error))"
      }
    }
  }
}

// MARK: - Playback and sending

extension AppModel {
  private func perform(_ actions: [PlaybackTracker.Action]) {
    play = tracker.current
    for action in actions {
      switch action {
      case .nowPlaying(let track):
        refreshLovedState(for: track)
        guard isScrobblingEnabled, let session else { continue }
        Task { [client, logger] in
          do {
            try await client.updateNowPlaying(track, sessionKey: session.key)
          } catch {
            logger.error("now playing failed: \(String(describing: error), privacy: .public)")
          }
        }
      case .scrobble(var scrobble):
        guard isScrobblingEnabled, let session else { continue }
        scrobble.username = session.username
        let track = scrobble.track
        logger.info("scrobble due: \(track.artist, privacy: .public) – \(track.title, privacy: .public)")
        queue.append(scrobble)
        recentStore.record(scrobble)
        recent = recentStore.items
        refreshPendingCount()
        flush()
      }
    }
  }

  private func refreshLovedState(for track: Track) {
    guard track.id != lovedTrackID else { return }
    lovedTask?.cancel()
    lovedTrackID = track.id
    isCurrentTrackLoved = nil
    guard let session else { return }
    lovedTask = Task { [weak self, client] in
      let loved = try? await client.isLoved(track, username: session.username)
      guard !Task.isCancelled, let self, lovedTrackID == track.id else { return }
      isCurrentTrackLoved = loved ?? false
    }
  }

  func sendNow() {
    retryTask?.cancel()
    flush()
  }

  private func flush() {
    let expired = queue.pruneExpired(now: .now)
    if !expired.isEmpty {
      recentStore.update(Dictionary(uniqueKeysWithValues: expired.map { ($0, .ignored) }))
      recent = recentStore.items
      refreshPendingCount()
    }
    guard !isFlushing, let session else { return }
    let batch = Array(queue.items(for: session.username).prefix(50))
    guard !batch.isEmpty else { return }
    isFlushing = true
    flushTask = Task { [weak self, client] in
      let result: Result<[LastFMClient.Outcome], LastFMClient.Failure>
      do {
        result = try await .success(client.scrobble(batch, sessionKey: session.key))
      } catch let failure as LastFMClient.Failure {
        result = .failure(failure)
      } catch {
        result = .failure(.network(error.localizedDescription))
      }
      self?.finishFlush(batch: batch, session: session, result: result)
    }
  }

  private func updateMessage(_ value: String?, for requestSession: StoredSession) {
    if session == requestSession { message = value }
  }

  private func finishFlush(
    batch: [Scrobble], session requestSession: StoredSession,
    result: Result<[LastFMClient.Outcome], LastFMClient.Failure>
  ) {
    isFlushing = false
    let ids = Set(batch.map(\.id))
    switch result {
    case .success(let outcomes):
      var statuses: [UUID: RecentScrobble.Status] = [:]
      for (scrobble, outcome) in zip(batch, outcomes) {
        statuses[scrobble.id] = outcome == .accepted ? .sent : .ignored
        if case .ignored(let reason) = outcome {
          logger.info("ignored: \(scrobble.track.title, privacy: .public) – \(reason, privacy: .public)")
        }
      }
      logger.info("sent \(batch.count) scrobbles")
      queue.remove(ids: ids)
      recentStore.update(statuses)
      updateMessage(nil, for: requestSession)
      flush()
    case .failure(let failure) where failure.needsReauth:
      guard session == requestSession else { flush()
        return
      }
      accountIO.clearSession()
      session = nil
      account = .signedOut
      message = "Last.fm signed you out. Sign in again to send waiting scrobbles."
    case .failure(let failure) where failure.isTransient:
      guard session == requestSession else { flush()
        return
      }
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
      queue.remove(ids: ids)
      recentStore.update(Dictionary(uniqueKeysWithValues: ids.map { ($0, .rejected) }))
      updateMessage("Last.fm rejected some scrobbles. \(LastFMClient.describe(failure))", for: requestSession)
    }
    recent = recentStore.items
    refreshPendingCount()
  }
}
