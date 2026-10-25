import AppKit
import Combine
import Sparkle

/// Sparkle owns verification and installation; this driver only presents inline controls.
@MainActor
final class InlineUpdateDriver: NSObject, ObservableObject, SPUUserDriver {
  enum Status: Equatable {
    case idle, checking, downloading, preparing, installing, upToDate
    case available(String), ready(String), information(String), failed(String)

    var message: String? {
      switch self {
      case .idle: nil
      case .checking: "Checking for updates…"
      case .downloading: "Downloading update…"
      case .preparing: "Preparing update…"
      case .installing: "Relaunching Halfway…"
      case .upToDate: "You’re up to date"
      case .available(let version): "Halfway \(version) is available"
      case .ready(let version): "Halfway \(version) is ready"
      case .information(let version): "About Halfway \(version)"
      case .failed(let message): message
      }
    }

    var actionLabel: String? {
      switch self {
      case .available: "Download Update"
      case .ready: "Update and Relaunch"
      case .information: "Learn More"
      case .failed: "Retry"
      default: nil
      }
    }

    var isBusy: Bool {
      switch self {
      case .checking, .downloading, .preparing, .installing: true
      default: false
      }
    }
  }

  @Published private(set) var status = Status.idle
  @Published private(set) var progress: Double?
  @Published private(set) var releaseNotesURL: URL?
  var automaticallyDownloadsUpdates: () -> Bool = { false }

  private var userInitiated = false
  private var version = ""
  private var expectedLength: UInt64 = 0
  private var receivedLength: UInt64 = 0
  private var action: (() -> Void)?
  private var cancellation: (() -> Void)?

  func performAction() {
    guard let pendingAction = action else { return }
    action = nil
    userInitiated = true
    pendingAction()
  }

  func cancel() {
    let pendingCancellation = cancellation
    resetSession()
    status = .idle
    pendingCancellation?()
  }

  func offerRelaunch(version: String, action: @escaping () -> Void) {
    self.version = version
    status = .ready(version)
    progress = nil
    cancellation = nil
    self.action = { [weak self] in
      self?.status = .installing
      action()
    }
  }

  func showStartupError() {
    status = .failed("Updates couldn’t start. Reopen Halfway to try again.")
  }

  func show(
    _: SPUUpdatePermissionRequest,
    reply: @escaping (SUUpdatePermissionResponse) -> Void
  ) {
    // Info.plist explicitly enables updates. If configuration ever changes, default to off
    // rather than manufacturing consent or presenting an unexpected permission window.
    reply(SUUpdatePermissionResponse(automaticUpdateChecks: false, sendSystemProfile: false))
  }

  func showUserInitiatedUpdateCheck(cancellation: @escaping () -> Void) {
    resetSession()
    userInitiated = true
    status = .checking
    self.cancellation = cancellation
  }

  func showUpdateFound(
    with appcastItem: SUAppcastItem,
    state: SPUUserUpdateState,
    reply: @escaping (SPUUserUpdateChoice) -> Void
  ) {
    userInitiated = state.userInitiated
    version = appcastItem.displayVersionString
    releaseNotesURL = Self.webURL(appcastItem.fullReleaseNotesURL ?? appcastItem.releaseNotesURL)
    cancellation = nil
    if appcastItem.isInformationOnlyUpdate {
      status = .information(version)
      action = {
        if let url = Self.webURL(appcastItem.infoURL) { NSWorkspace.shared.open(url) }
        reply(.dismiss)
      }
    } else if state.stage == .installing {
      offerRelaunch(version: version) { reply(.install) }
    } else if !state.userInitiated, automaticallyDownloadsUpdates() {
      // Critical updates and other scheduled fallbacks may reach the UI driver before
      // downloading. Continue preparing silently; the ready callback never relaunches.
      status = .idle
      reply(.install)
    } else {
      status = .available(version)
      action = { [weak self] in
        // This prepares the update. The later ready callback still requires an explicit
        // click before Halfway is allowed to quit and relaunch.
        self?.userInitiated = true
        self?.status = .downloading
        reply(.install)
      }
    }
  }

  func showUpdateReleaseNotes(with _: SPUDownloadData) { }
  func showUpdateReleaseNotesFailedToDownloadWithError(_: Error) { }

  func showUpdateNotFoundWithError(_ error: Error, acknowledgement: @escaping () -> Void) {
    let reason = (error as NSError).userInfo[SPUNoUpdateFoundReasonKey] as? NSNumber
    if
      reason?.intValue == Int(SPUNoUpdateFoundReason.systemIsTooOld.rawValue)
      || reason?.intValue == Int(SPUNoUpdateFoundReason.systemIsTooNew.rawValue)
      || reason?.intValue == Int(SPUNoUpdateFoundReason.hardwareDoesNotSupportARM64.rawValue) {
      status = .failed("The latest update isn’t compatible with this Mac.")
    } else if
      reason?.intValue == Int(SPUNoUpdateFoundReason.onLatestVersion.rawValue)
      || reason?.intValue == Int(SPUNoUpdateFoundReason.onNewerThanLatestVersion.rawValue) {
      status = .upToDate
    } else {
      status = .failed("No compatible update is available right now.")
    }
    acknowledgement()
  }

  func showUpdaterError(_: Error, acknowledgement: @escaping () -> Void) {
    // Never surface transient background failures or log server response bodies.
    status = userInitiated ? .failed("Couldn’t update Halfway. Try again.") : .idle
    acknowledgement()
  }

  func showDownloadInitiated(cancellation: @escaping () -> Void) {
    expectedLength = 0
    receivedLength = 0
    self.cancellation = cancellation
    if userInitiated { status = .downloading }
  }

  func showDownloadDidReceiveExpectedContentLength(_ expectedContentLength: UInt64) {
    expectedLength = expectedContentLength
  }

  func showDownloadDidReceiveData(ofLength length: UInt64) {
    receivedLength += length
    if userInitiated, expectedLength > 0 {
      progress = min(1, Double(receivedLength) / Double(expectedLength))
    }
  }

  func showDownloadDidStartExtractingUpdate() {
    cancellation = nil
    progress = nil
    if userInitiated { status = .preparing }
  }

  func showExtractionReceivedProgress(_ progress: Double) {
    if userInitiated { self.progress = min(1, max(0, progress)) }
  }

  func showReady(toInstallAndRelaunch reply: @escaping (SPUUserUpdateChoice) -> Void) {
    offerRelaunch(version: version) { reply(.install) }
  }

  func showInstallingUpdate(
    withApplicationTerminated applicationTerminated: Bool,
    retryTerminatingApplication: @escaping () -> Void
  ) {
    status = .installing
    if !applicationTerminated {
      status = .ready(version)
      action = retryTerminatingApplication
    }
  }

  func showUpdateInstalledAndRelaunched(_: Bool, acknowledgement: @escaping () -> Void) {
    resetSession()
    status = .idle
    acknowledgement()
  }

  func dismissUpdateInstallation() {
    let previousStatus = status
    resetSession()
    switch previousStatus {
    case .upToDate, .failed: status = previousStatus
    default: status = .idle
    }
  }

  private func resetSession() {
    action = nil
    cancellation = nil
    userInitiated = false
    progress = nil
    releaseNotesURL = nil
  }

  private static func webURL(_ url: URL?) -> URL? {
    guard let url, url.scheme == "https" else { return nil }
    return url
  }
}
