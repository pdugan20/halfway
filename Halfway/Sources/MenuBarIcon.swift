import AppKit

/// Draws the menu bar icon: a ring that fills like a pie as the current song nears its scrobble point.
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

  nonisolated private static func draw(_ state: State, in rect: NSRect) {
    let center = NSPoint(x: rect.midX, y: rect.midY)
    let ring = NSBezierPath()
    ring.appendArc(withCenter: center, radius: 7.25, startAngle: 0, endAngle: 360)
    ring.lineWidth = 1.5
    NSColor.black.set()
    if state == .inactive {
      ring.setLineDash([2.4, 1.8], count: 2, phase: 0)
    }
    ring.stroke()

    let radius: CGFloat = 5
    let fill = NSBezierPath()
    switch state {
    case .inactive:
      return
    case .idle:
      fill.move(to: NSPoint(x: center.x, y: center.y + radius))
      fill.appendArc(withCenter: center, radius: radius, startAngle: 90, endAngle: 270)
      fill.close()
    case .progress(let fraction):
      guard fraction > 0 else { return }
      fill.move(to: center)
      fill.appendArc(withCenter: center, radius: radius, startAngle: 90, endAngle: 90 - 360 * fraction, clockwise: true)
      fill.close()
    case .scrobbled:
      fill.appendArc(withCenter: center, radius: radius, startAngle: 0, endAngle: 360)
    }
    fill.fill()
  }
}
