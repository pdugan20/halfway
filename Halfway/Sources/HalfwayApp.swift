import SwiftUI

@main
struct HalfwayApp: App {
  @State private var model = AppModel()

  var body: some Scene {
    MenuBarExtra {
      MenuContent(model: model)
    } label: {
      Image(systemName: model.menuBarSymbol)
        .accessibilityLabel("Halfway")
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
      SettingsView(model: model)
    }
  }
}
