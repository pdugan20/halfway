import SwiftUI

/// First-launch window: what Halfway does, sign in, and Open at Login.
struct WelcomeView: View {
  static let windowID = "welcome"
  private static let summary = """
  Halfway scrobbles what you play in Apple Music to Last.fm. \
  A song counts once you've heard half of it, or four minutes.
  """

  let model: AppModel
  @Environment(\.dismissWindow) private var dismissWindow

  var body: some View {
    VStack(spacing: 20) {
      VStack(spacing: 8) {
        Image(nsImage: NSApp.applicationIconImage)
          .resizable()
          .frame(width: 88, height: 88)
          .accessibilityHidden(true)
        Text("Welcome to Halfway")
          .font(.title.weight(.semibold))
        Text(Self.summary)
          .font(.callout)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
          .fixedSize(horizontal: false, vertical: true)
      }
      .padding(.horizontal, 24)

      Form {
        Section {
          AccountRow(model: model)
          LoginItemRow(model: model)
        }
      }
      .formStyle(.grouped)
      .scrollDisabled(true)
      .scrollContentBackground(.hidden)
      .frame(height: model.loginItemNeedsApproval ? 168 : 132)

      Button(model.isSignedIn ? "Done" : "Not Now") { finish() }
        .buttonStyle(.glassProminent)
        .controlSize(.large)
        .keyboardShortcut(.defaultAction)
    }
    .padding(.top, 28)
    .padding(.bottom, 24)
    .frame(width: 440)
    .onAppear {
      model.refreshLoginItemStatus()
      NSApp.activate()
    }
  }

  private func finish() {
    model.completeSetup()
    dismissWindow(id: Self.windowID)
  }
}
