import Foundation
import Testing
@testable import Halfway

@MainActor
struct AccountLifecycleTests {
  private let accountA = StoredSession(username: "account-a", key: "fixture-session-a")
  private let accountB = StoredSession(username: "account-b", key: "fixture-session-b")

  @Test
  func cancelledSignInCannotRestoreTheSession() async throws {
    let context = Context()
    context.model.signIn()
    let task = context.model.signInTask
    try await wait { context.client.sessions.count == 1 }
    context.model.cancelSignIn()
    context.client.sessions[0].resume(returning: accountA)
    await task?.value
    #expect(context.model.account == .signedOut)
    #expect(context.saved.isEmpty)
  }

  @Test
  func expiredOldSessionCannotSignOutTheNewAccountOrStopItsQueue() async throws {
    let context = Context(session: accountA, queuedFor: [accountA.username, accountB.username])
    context.model.sendNow()
    let oldFlush = context.model.flushTask
    try await wait { context.client.scrobbles.count == 1 }
    context.model.signOut()
    context.model.signIn()
    try await wait { context.client.sessions.count == 1 }
    context.client.sessions[0].resume(returning: accountB)
    await context.model.signInTask?.value
    context.client.scrobbles[0].resume(throwing: LastFMClient.Failure.api(code: 9, message: "Fixture expired session"))
    await oldFlush?.value
    #expect(context.model.account == .signedIn(username: accountB.username))
    #expect(context.clears == 1)
    try await wait { context.client.scrobbles.count == 2 }
    #expect(context.client.scrobbleSessions == [accountA.key, accountB.key])
    context.client.scrobbles[1].resume(returning: [.accepted])
    await context.model.flushTask?.value
    #expect(context.model.pendingCount == 0)
    let queue = ScrobbleQueue(file: JSONFile(url: context.queueURL))
    #expect(queue.items(for: accountA.username).count == 1)
    #expect(queue.items(for: accountB.username).isEmpty)
  }

  @Test
  func loveWritesCannotOvertakeOneAnother() async throws {
    let context = Context(session: accountA)
    context.model.handle(PlayerSnapshot(state: .playing, track: context.track))
    await context.model.lovedTask?.value
    context.model.toggleLove()
    let love = context.model.loveUpdateTask
    context.model.toggleLove()
    try await wait { context.client.loveWrites.count == 1 }
    #expect(context.model.isUpdatingLove)
    #expect(context.client.loveChoices == [true])
    context.client.loveWrites[0].resume()
    await love?.value
    #expect(!context.model.isUpdatingLove)
    #expect(context.model.isCurrentTrackLoved == true)
    context.model.toggleLove()
    let unlove = context.model.loveUpdateTask
    try await wait { context.client.loveWrites.count == 2 }
    #expect(context.client.loveChoices == [true, false])
    context.client.loveWrites[1].resume()
    await unlove?.value
    #expect(context.model.isCurrentTrackLoved == false)
  }

  @Test
  func oldLoveFailureCannotOverwriteOrUnlockTheNewAccountsRequest() async throws {
    let context = Context(session: accountA)
    context.model.handle(PlayerSnapshot(state: .playing, track: context.track))
    await context.model.lovedTask?.value
    context.model.toggleLove()
    let oldLove = context.model.loveUpdateTask
    try await wait { context.client.loveWrites.count == 1 }
    context.model.signOut()
    context.model.signIn()
    try await wait { context.client.sessions.count == 1 }
    context.client.sessions[0].resume(returning: accountB)
    await context.model.signInTask?.value
    await context.model.lovedTask?.value
    context.model.toggleLove()
    let newLove = context.model.loveUpdateTask
    try await wait { context.client.loveWrites.count == 2 }
    context.client.loveWrites[0].resume(throwing: LastFMClient.Failure.badResponse)
    await oldLove?.value
    #expect(context.model.isCurrentTrackLoved == true)
    #expect(context.model.isUpdatingLove)
    #expect(context.model.message == nil)
    context.client.loveWrites[1].resume()
    await newLove?.value
    #expect(!context.model.isUpdatingLove)
  }

  private func wait(until condition: () -> Bool) async throws {
    let deadline = ContinuousClock.now.advanced(by: .seconds(3))
    while !condition() {
      if ContinuousClock.now >= deadline { throw FixtureFailure.timedOut }
      try await Task.sleep(for: .milliseconds(1))
    }
  }
}

private enum FixtureFailure: Error {
  case timedOut
}

@MainActor
private final class Context {
  let client = SuspendedClient()
  let directory = FileManager.default.temporaryDirectory.appending(path: "halfway-account-test-\(UUID())")
  let track = Track(id: "fixture", title: "Song", artist: "Artist", album: nil, albumArtist: nil, duration: 200)
  var saved: [StoredSession] = []
  var clears = 0
  private let initialSession: StoredSession?
  private let queuedAccounts: [String]
  lazy var model: AppModel = makeModel()
  var queueURL: URL { directory.appending(path: "queue.json") }

  init(session: StoredSession? = nil, queuedFor accounts: [String] = []) {
    initialSession = session
    queuedAccounts = accounts
  }

  private func makeModel() -> AppModel {
    var queue = ScrobbleQueue(file: JSONFile(url: queueURL))
    for account in queuedAccounts { queue.append(Scrobble(track: track, startedAt: .now, username: account)) }
    let io = AppModelServices.AccountIO(
      saveSession: { [weak self] in self?.saved.append($0) },
      clearSession: { [weak self] in self?.clears += 1 },
      openAuthorization: { _ in }, activate: { }, pollInterval: .zero
    )
    return AppModel(services: AppModelServices(
      client: client, storedSession: initialSession, queue: queue,
      recent: RecentScrobbles(file: JSONFile(url: directory.appending(path: "recent.json"))), accountIO: io
    ), startsObservers: false)
  }

  deinit { try? FileManager.default.removeItem(at: directory) }
}

@MainActor
private final class SuspendedClient: LastFMService {
  var sessions: [CheckedContinuation<StoredSession, any Error>] = []
  var scrobbles: [CheckedContinuation<[LastFMClient.Outcome], any Error>] = []
  var scrobbleSessions: [String] = []
  var loveWrites: [CheckedContinuation<Void, any Error>] = []
  var loveChoices: [Bool] = []

  @MainActor
  func getToken() async throws -> String { "fixture-token" }
  nonisolated func authorizationURL(token _: String) -> URL { URL(string: "https://example.invalid/")! }
  @MainActor
  func getSession(token _: String) async throws -> StoredSession {
    try await withCheckedThrowingContinuation { sessions.append($0) }
  }

  @MainActor
  func updateNowPlaying(_: Track, sessionKey _: String) async throws { }
  @MainActor
  func isLoved(_: Track, username _: String) async throws -> Bool { false }
  @MainActor
  func scrobble(_: [Scrobble], sessionKey: String) async throws -> [LastFMClient.Outcome] {
    scrobbleSessions.append(sessionKey)
    return try await withCheckedThrowingContinuation { scrobbles.append($0) }
  }

  @MainActor
  func love(_: Track, sessionKey _: String) async throws {
    loveChoices.append(true)
    try await withCheckedThrowingContinuation { loveWrites.append($0) }
  }

  @MainActor
  func unlove(_: Track, sessionKey _: String) async throws {
    loveChoices.append(false)
    try await withCheckedThrowingContinuation { loveWrites.append($0) }
  }
}
