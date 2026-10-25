import Sparkle
import Testing
@testable import Halfway

@MainActor
struct UpdateDriverTests {
  @Test
  func readyUpdateWaitsForExplicitClickAndRunsOnce() {
    let driver = InlineUpdateDriver()
    var installs = 0
    driver.offerRelaunch(version: "1.2.3") { installs += 1 }
    #expect(driver.status == .ready("1.2.3"))
    #expect(installs == 0)
    driver.performAction()
    driver.performAction()
    #expect(installs == 1)
    #expect(driver.status == .installing)
  }

  @Test
  func cancellationAndDismissalDiscardStaleActions() {
    let driver = InlineUpdateDriver()
    var cancelled = false
    driver.showUserInitiatedUpdateCheck { cancelled = true }
    #expect(driver.status == .checking)
    driver.cancel()
    #expect(cancelled)
    #expect(driver.status == .idle)
    var installed = false
    driver.offerRelaunch(version: "1.2.3") { installed = true }
    driver.dismissUpdateInstallation()
    driver.performAction()
    #expect(!installed)
    #expect(driver.status == .idle)
  }

  @Test
  func backgroundFailuresStayInvisibleAndManualFailuresStayInline() {
    let driver = InlineUpdateDriver()
    let error = NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet)
    var acknowledgements = 0
    driver.showUpdaterError(error) { acknowledgements += 1 }
    #expect(driver.status == .idle)
    driver.showUserInitiatedUpdateCheck(cancellation: { })
    driver.showUpdaterError(error) { acknowledgements += 1 }
    #expect(driver.status.actionLabel == "Retry")
    driver.dismissUpdateInstallation()
    #expect(driver.status.actionLabel == "Retry")
    #expect(acknowledgements == 2)
  }

  @Test
  func progressIsBoundedAndExtractionCannotCancelTheDownload() {
    let driver = InlineUpdateDriver()
    driver.showUserInitiatedUpdateCheck(cancellation: { })
    var cancelled = false
    driver.showDownloadInitiated { cancelled = true }
    driver.showDownloadDidReceiveExpectedContentLength(100)
    driver.showDownloadDidReceiveData(ofLength: 140)
    #expect(driver.progress == 1)
    driver.showDownloadDidStartExtractingUpdate()
    #expect(driver.status == .preparing)
    #expect(driver.progress == nil)
    driver.showExtractionReceivedProgress(-1)
    #expect(driver.progress == 0)
    driver.cancel()
    #expect(!cancelled)
  }

  @Test
  func unsupportedMacIsNotReportedAsUpToDate() {
    let driver = InlineUpdateDriver()
    driver.showUserInitiatedUpdateCheck(cancellation: { })
    let error = NSError(domain: SUSparkleErrorDomain, code: 0, userInfo: [
      SPUNoUpdateFoundReasonKey: SPUNoUpdateFoundReason.systemIsTooOld.rawValue
    ])
    var acknowledged = false
    driver.showUpdateNotFoundWithError(error) { acknowledged = true }
    #expect(driver.status != .upToDate)
    #expect(acknowledged)
  }

  @Test
  func preparingAnUpdateNeverRelaunchesWithoutClick() {
    let driver = InlineUpdateDriver()
    var choice: SPUUserUpdateChoice?
    driver.showReady(toInstallAndRelaunch: { choice = $0 })
    #expect(choice == nil)
    driver.performAction()
    #expect(choice == .install)
  }

  @Test
  func debugUpdaterNeverStartsTheEngine() {
    let updater = AppUpdater(isEnabled: false)
    updater.checkForUpdates()
    updater.setKeepsUpToDate(true)
    #expect(!updater.canCheckForUpdates)
    #expect(!updater.keepsUpToDate)
    #expect(updater.userDriver.status == .idle)
  }

  @Test
  func failureAfterExplicitRelaunchStaysInline() {
    let driver = InlineUpdateDriver()
    driver.offerRelaunch(version: "1.2.3", action: { })
    driver.performAction()
    driver.showUpdaterError(NSError(domain: NSURLErrorDomain, code: -1), acknowledgement: { })
    #expect(driver.status.actionLabel == "Retry")
  }

  @Test
  func freshInstallUsesBothAutomaticDefaultsWithoutStartingChecks() throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: "halfway-update-tests-\(UUID()).app")
    defer { try? FileManager.default.removeItem(at: directory) }
    let contents = directory.appending(path: "Contents")
    try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
    let info: [String: Any] = [
      "CFBundleIdentifier": "test.halfway.\(UUID().uuidString)",
      "CFBundleName": "Halfway Update Test",
      "CFBundleVersion": "1",
      "SUEnableAutomaticChecks": true,
      "SUAutomaticallyUpdate": true,
    ]
    try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0)
      .write(to: contents.appending(path: "Info.plist"))
    let bundle = try #require(Bundle(url: directory))
    let updater = SPUUpdater(
      hostBundle: bundle, applicationBundle: bundle, userDriver: InlineUpdateDriver(), delegate: nil
    )
    #expect(updater.automaticallyChecksForUpdates)
    #expect(updater.automaticallyDownloadsUpdates)
  }
}
