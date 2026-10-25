import SwiftUI

@main
struct HalfwayApp: App {
  @State private var model = AppModel()
  @StateObject private var updater = AppUpdater()

  var body: some Scene {
    MenuBarExtra {
      MenuContent(model: model, updater: updater)
    } label: {
      Image(nsImage: MenuBarIcon.image(for: model.menuBarIcon))
        .accessibilityLabel(MenuBarIcon.description(of: model.menuBarIcon))
    }
    .menuBarExtraStyle(.window)

    Window("Welcome to Halfway", id: WelcomeView.windowID) {
      WelcomeView(model: model)
    }
    .windowStyle(.hiddenTitleBar)
    .windowResizability(.contentSize)
    .windowBackgroundDragBehavior(.enabled)
    .restorationBehavior(.disabled)
    .defaultPosition(.center)
    .defaultLaunchBehavior(model.hasCompletedSetup ? .suppressed : .presented)

    Settings {
      SettingsView(model: model, updater: updater)
    }
  }
}
