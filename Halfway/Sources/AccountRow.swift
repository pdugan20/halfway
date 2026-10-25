import SwiftUI

/// Last.fm sign-in state with its one relevant action. Shared by Welcome and Settings.
struct AccountRow: View {
  let model: AppModel

  var body: some View {
    if !model.isConfigured {
      LabeledContent("Last.fm") {
        Text("This build is missing its API key.")
          .foregroundStyle(.secondary)
      }
    } else {
      switch model.account {
      case .signedOut:
        LabeledContent {
          Button("Sign In…") { model.signIn() }
        } label: {
          Text("Last.fm")
          Text("Not signed in")
        }
      case .waitingForApproval:
        LabeledContent {
          HStack(spacing: 8) {
            ProgressView()
              .controlSize(.small)
            Button("Cancel") { model.cancelSignIn() }
          }
        } label: {
          Text("Last.fm")
          Text("Approve Halfway in your browser")
        }
      case .signedIn(let username):
        LabeledContent {
          Button("Sign Out") { model.signOut() }
        } label: {
          Text(username)
          Text("Signed in to Last.fm")
        }
      }
    }
  }
}

/// Open at Login, including the case where the user turned it off in System Settings.
struct LoginItemRow: View {
  let model: AppModel

  var body: some View {
    Toggle(isOn: Binding(get: { model.opensAtLogin }, set: { model.setOpensAtLogin($0) })) {
      Text("Open at Login")
      if model.loginItemNeedsApproval {
        Text("Allowed only after you turn it on in Login Items.")
      } else {
        Text("Start Halfway when you log in so no plays are missed.")
      }
    }
    if model.loginItemNeedsApproval {
      Button("Open Login Items Settings…") { model.openLoginItemsSettings() }
    }
  }
}
