import Combine
import Sparkle

/// One updater for the lifetime of the app. Debug builds never contact the update feed.
@MainActor
final class AppUpdater: NSObject, ObservableObject, SPUUpdaterDelegate {
  #if DEBUG
  static let releaseBuild = false
  #else
  static let releaseBuild = true
  #endif

  let isEnabled: Bool
  let userDriver = InlineUpdateDriver()
  @Published private(set) var canCheckForUpdates = false
  @Published private(set) var keepsUpToDate = false

  private var updater: SPUUpdater?

  init(isEnabled: Bool = AppUpdater.releaseBuild) {
    self.isEnabled = isEnabled
    super.init()
    guard isEnabled else { return }

    let updater = SPUUpdater(hostBundle: .main, applicationBundle: .main, userDriver: userDriver, delegate: self)
    self.updater = updater
    userDriver.automaticallyDownloadsUpdates = { [weak updater] in
      updater?.automaticallyDownloadsUpdates ?? false
    }
    updater.publisher(for: \.canCheckForUpdates).assign(to: &$canCheckForUpdates)
    Publishers.CombineLatest(
      updater.publisher(for: \.automaticallyChecksForUpdates),
      updater.publisher(for: \.automaticallyDownloadsUpdates)
    )
    .map { $0 && $1 }
    .assign(to: &$keepsUpToDate)
    do {
      try updater.start()
    } catch {
      userDriver.showStartupError()
    }
  }

  func checkForUpdates() {
    guard isEnabled, canCheckForUpdates else { return }
    updater?.checkForUpdates()
  }

  func setKeepsUpToDate(_ value: Bool) {
    guard let updater else { return }
    // Change Sparkle's preferences only in response to the user's toggle.
    if value {
      updater.automaticallyDownloadsUpdates = true
      updater.automaticallyChecksForUpdates = true
    } else {
      updater.automaticallyChecksForUpdates = false
      updater.automaticallyDownloadsUpdates = false
    }
  }

  func updater(
    _: SPUUpdater,
    willInstallUpdateOnQuit item: SUAppcastItem,
    immediateInstallationBlock immediateInstallHandler: @escaping () -> Void
  ) -> Bool {
    userDriver.offerRelaunch(version: item.displayVersionString, action: immediateInstallHandler)
    // Sparkle still installs on quit. Taking control avoids its eventual reminder window.
    return true
  }
}
