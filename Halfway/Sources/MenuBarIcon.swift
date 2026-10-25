import AppKit

/// Draws the Halfway mark, filling from the bottom as the current song nears its scrobble point.
enum MenuBarIcon {
  nonisolated enum State: Equatable, Hashable, Sendable {
    /// Signed out or scrobbling turned off.
    case inactive
    /// Nothing scrobbleable is playing. Shows the Halfway mark.
    case idle
    /// Fraction of the way to the scrobble point.
    case progress(Double)
    case scrobbled
  }

  private static var cache: [State: NSImage] = [:]
  private static let mark = NSImage(named: "MenuBarMark")

  static func image(for state: State) -> NSImage {
    if let cached = cache[state] { return cached }
    let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { rect in
      draw(state, in: rect)
      return true
    }
    image.isTemplate = true
    image.accessibilityDescription = description(of: state)
    cache[state] = image
    return image
  }

  static func description(of state: State) -> String {
    switch state {
    case .inactive: "Halfway, not scrobbling"
    case .idle: "Halfway"
    case .progress(let fraction): "Halfway, \(Int(fraction * 100)) percent to scrobble"
    case .scrobbled: "Halfway, scrobbled"
    }
  }

  private static func draw(_ state: State, in rect: NSRect) {
    // The PDF shares the app icon's 1024-point canvas. Enlarge slightly for optical size in the menu bar.
    let markRect = rect.insetBy(dx: -1, dy: -1)
    switch state {
    case .inactive:
      mark?.draw(in: markRect, from: .zero, operation: .sourceOver, fraction: 0.35)
    case .idle, .scrobbled:
      mark?.draw(in: markRect)
    case .progress(let fraction):
      mark?.draw(in: markRect, from: .zero, operation: .sourceOver, fraction: 0.25)
      NSGraphicsContext.saveGraphicsState()
      let progress = min(max(fraction, 0), 1)
      NSBezierPath(rect: NSRect(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height * progress))
        .addClip()
      mark?.draw(in: markRect)
      NSGraphicsContext.restoreGraphicsState()
    }
  }
}
