import SwiftUI

struct UpdateSettings: View {
  @ObservedObject var updater: AppUpdater

  var body: some View {
    Section {
      Toggle("Keep Halfway up to date", isOn: Binding(
        get: { updater.keepsUpToDate },
        set: { updater.setKeepsUpToDate($0) }
      ))
      UpdateStatusRow(updater: updater, driver: updater.userDriver, showsCheck: true)
    } header: {
      Text("Updates")
    } footer: {
      Text(updater.isEnabled
        ? "Updates download quietly and install when you quit."
        : "Updates are available in release builds.")
        .font(.footnote)
        .foregroundStyle(.secondary)
    }
    .disabled(!updater.isEnabled)
  }
}

/// Shared by the menu and Settings so manual checks never need a separate window.
struct UpdateStatusRow: View {
  @ObservedObject var updater: AppUpdater
  @ObservedObject var driver: InlineUpdateDriver
  var showsCheck = false

  var body: some View {
    if driver.status != .idle || showsCheck {
      VStack(alignment: .leading, spacing: 6) {
        if let message = driver.status.message {
          HStack(spacing: 6) {
            if driver.status.isBusy {
              ProgressView().controlSize(.mini)
            }
            Text(message)
              .font(.callout)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }
          .accessibilityElement(children: .combine)
        }
        if let progress = driver.progress {
          ProgressView(value: progress)
            .accessibilityLabel("Update progress")
        }
        HStack {
          if let label = driver.status.actionLabel {
            Button(label) {
              if case .failed = driver.status { updater.checkForUpdates() } else { driver.performAction() }
            }
            .disabled(isRetryDisabled)
          } else if !driver.status.isBusy, showsCheck {
            Button("Check for Updates", action: updater.checkForUpdates)
              .disabled(!updater.canCheckForUpdates)
          }
          if driver.status == .checking || driver.status == .downloading {
            Button("Cancel", action: driver.cancel)
          }
          if let url = driver.releaseNotesURL {
            Spacer()
            Link("What’s New", destination: url)
          }
        }
        .buttonStyle(.borderless)
      }
    }
  }

  private var isRetryDisabled: Bool {
    if case .failed = driver.status { return !updater.canCheckForUpdates }
    return false
  }
}
