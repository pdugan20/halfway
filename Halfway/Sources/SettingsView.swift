import SwiftUI

struct SettingsView: View {
  @Bindable var model: AppModel

  var body: some View {
    TabView {
      Tab("General", systemImage: "gearshape") {
        GeneralSettings(model: model)
      }
      Tab("Account", systemImage: "person.crop.circle") {
        AccountSettings(model: model)
      }
    }
    .frame(width: 460)
    .onAppear { model.refreshLoginItemStatus() }
  }
}

private struct GeneralSettings: View {
  private static let rules = """
  A song counts once you've heard half of it or four minutes, whichever comes first. \
  Songs under 30 seconds don't count.
  """

  @Bindable var model: AppModel

  var body: some View {
    Form {
      Section {
        LoginItemRow(model: model)
      }
      Section {
        Toggle(isOn: $model.isScrobblingEnabled) {
          Text("Scrobble to Last.fm")
          Text("Turn off to listen without sending plays.")
        }
        if model.isSignedIn, model.pendingCount > 0 {
          LabeledContent("^[\(model.pendingCount) scrobble](inflect: true) waiting") {
            Button("Send Now") { model.sendNow() }
          }
        }
      } footer: {
        Text(Self.rules)
          .font(.footnote)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
    .formStyle(.grouped)
    .scrollDisabled(true)
    .frame(height: 260)
  }
}

private struct AccountSettings: View {
  let model: AppModel

  var body: some View {
    Form {
      Section {
        AccountRow(model: model)
        if let url = model.profileURL {
          Link("View Profile on Last.fm", destination: url)
        }
      } footer: {
        if let message = model.message {
          Text(message)
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
      }
      Section {
        LabeledContent("Version", value: Self.version)
      }
    }
    .formStyle(.grouped)
    .scrollDisabled(true)
    .frame(height: 220)
  }

  private static var version: String {
    let info = Bundle.main.infoDictionary ?? [:]
    let short = info["CFBundleShortVersionString"] as? String ?? "?"
    let build = info["CFBundleVersion"] as? String ?? "?"
    return "\(short) (\(build))"
  }
}
