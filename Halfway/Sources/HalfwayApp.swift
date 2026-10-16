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
  }
}
