import AppKit
import SwiftUI

// Exploration only. This executable never instantiates Halfway or its scrobbling services.
private let ink = Color(red: 0.18, green: 0.20, blue: 0.14)
private let muted = Color(red: 0.43, green: 0.44, blue: 0.38)
private let paper = Color(red: 0.955, green: 0.950, blue: 0.918)

enum Direction: Int, CaseIterable, Identifiable {
  case sleeve, quiet, split, drawn, record, margins
  case whiteBrush, whiteFine, whiteWordmark, paperBrush, quietGrooves, whiteGrooves
  case notchClassic, notchSmall, notchBrush, notchDestination
  var id: Int { rawValue }
  static let current: [Direction] = [.notchClassic, .notchSmall, .notchBrush, .notchDestination]
  static let roundThree: [Direction] = [.whiteBrush, .whiteFine, .whiteWordmark, .paperBrush, .quietGrooves, .whiteGrooves]
  static let roundTwo: [Direction] = [.drawn, .record, .margins]
  static let earlier: [Direction] = [.sleeve, .quiet, .split]
  var name: String {
    [
      "01 · Paper sleeve",
      "02 · Quiet utility",
      "03 · Listening room",
      "01 · Drawn minimal",
      "02 · Soft sleeve",
      "03 · Illustrated margins",
      "01 · Brush",
      "02 · Fine",
      "03 · Wordmark",
      "04 · Paper",
      "05 · Grooves",
      "06 · White grooves",
      "01 · Classic ticks",
      "02 · Small ticks",
      "03 · Brush + ticks",
      "04 · Destination ticks",
    ][rawValue]
  }

  var slug: String {
    [
      "paper-sleeve",
      "quiet-utility",
      "listening-room",
      "drawn-minimal",
      "soft-sleeve",
      "illustrated-margins",
      "white-brush",
      "white-fine",
      "white-wordmark",
      "paper-brush",
      "quiet-grooves",
      "white-grooves",
      "notch-classic",
      "notch-small",
      "notch-brush",
      "notch-destination",
    ][rawValue]
  }

  var thesis: String {
    [
      "Warm paper, editorial type, and faint record grooves.",
      "One clear instruction and generous space. Almost no decoration.",
      "A graphic olive sleeve beside a calm, functional installation area.",
      "A drawn arrow and small lime accents; the icons do the talking.",
      "Quiet record grooves, warm paper, and a compact instruction.",
      "Drawn music details at the edges, with a clear center for installation.",
      "Pure white. Two icons and a bold drawn arrow; no headline or instruction.",
      "Pure white. A fine directional line and one small instruction.",
      "Pure white. A quiet sans-serif wordmark above the installation area.",
      "The same spare brush composition, on warm paper.",
      "Warm paper with a few faint record grooves and a compact instruction.",
      "The quiet groove composition on a pure white background.",
      "Pure white, the curved arrow, and lime ticks at the outer corners.",
      "The same composition with smaller, closer accent ticks.",
      "A heavier brush arrow with the original lime corner ticks.",
      "Three lime ticks emphasize the destination folder only.",
    ][rawValue]
  }
}

enum StudySet: String, CaseIterable, Identifiable {
  case notches = "Notch studies", minimal = "Minimal studies", roundTwo = "Previous studies", original = "Original studies"
  var id: String { rawValue }
  var directions: [Direction] {
    switch self {
    case .notches: Direction.current
    case .minimal: Direction.roundThree
    case .roundTwo: Direction.roundTwo
    case .original: Direction.earlier
    }
  }
}

struct Artwork {
  let light: NSImage
  let dark: NSImage
  let folder: NSImage
  init(directory: String) {
    light = NSImage(contentsOfFile: directory + "/icon-default.png")!
    dark = NSImage(contentsOfFile: directory + "/icon-dark.png")!
    folder = NSImage(contentsOfFile:
      "/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/ApplicationsFolderIcon.icns")
      ?? NSWorkspace.shared.icon(forFile: "/Applications")
    folder.size = NSSize(width: 512, height: 512)
  }
}

struct InstallItem: View {
  let image: NSImage
  let label: String
  var size: CGFloat = 148
  var alias = false
  var body: some View {
    VStack(spacing: 13) {
      Image(nsImage: image).resizable().interpolation(.high).frame(width: size, height: size)
        .overlay(alignment: .bottomLeading) {
          if alias {
            Image(systemName: "arrow.turn.up.right")
              .font(.system(size: 14, weight: .bold)).foregroundStyle(.black.opacity(0.75))
              .frame(width: 27, height: 27).background(.white, in: Circle())
              .shadow(color: .black.opacity(0.15), radius: 1, y: 1)
          }
        }
      Text(label).font(.system(size: 14)).foregroundStyle(ink)
    }
    .accessibilityElement(children: .combine)
  }
}

struct Grooves: View {
  var light = false
  var body: some View {
    Canvas { context, size in
      for i in 0..<8 {
        let radius = CGFloat(170 + i * 27)
        let rect = CGRect(
          x: size.width * 0.12 - radius,
          y: size.height * 1.22 - radius,
          width: radius * 2,
          height: radius * 2
        )
        context.stroke(Path(ellipseIn: rect), with: .color(light ? .white.opacity(0.12) : ink.opacity(0.065)), lineWidth: 0.7)
      }
    }.allowsHitTesting(false).accessibilityHidden(true)
  }
}

struct DrawnArrow: View {
  var body: some View {
    Canvas { context, size in
      let sx = size.width / 128
      let sy = size.height / 136
      var curve = Path()
      curve.move(to: CGPoint(x: 7 * sx, y: 72 * sy))
      curve.addCurve(
        to: CGPoint(x: 119 * sx, y: 66 * sy),
        control1: CGPoint(x: 40 * sx, y: 54 * sy),
        control2: CGPoint(x: 82 * sx, y: 54 * sy)
      )
      context.stroke(curve, with: .color(ink), style: StrokeStyle(lineWidth: 3.7, lineCap: .round))
      var tip = Path()
      tip.move(to: CGPoint(x: 101 * sx, y: 49 * sy))
      tip.addQuadCurve(
        to: CGPoint(x: 120 * sx, y: 66 * sy),
        control: CGPoint(x: 112 * sx, y: 55 * sy)
      )
      tip.addQuadCurve(
        to: CGPoint(x: 103 * sx, y: 77 * sy),
        control: CGPoint(x: 111 * sx, y: 72 * sy)
      )
      context.stroke(tip, with: .color(ink), style: StrokeStyle(lineWidth: 3.3, lineCap: .round, lineJoin: .round))
    }.accessibilityHidden(true)
  }
}

// All decorative paths are authored here; the app and destination remain separate Finder items.
struct MarginDrawing: View {
  let direction: Direction
  var body: some View {
    Canvas { context, _ in
      func line(_ points: [CGPoint], colour: Color = ink, width: CGFloat = 2.4) {
        var path = Path()
        path.addLines(points)
        context.stroke(path, with: .color(colour), style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
      }
      let lime = Color(red: 0.75, green: 0.85, blue: 0.34)
      if direction == .drawn {
        // A little glint outside each icon; no competing illustration.
        line([CGPoint(x: 164, y: 163), CGPoint(x: 160, y: 152)], colour: lime, width: 3)
        line([CGPoint(x: 155, y: 176), CGPoint(x: 143, y: 172)], colour: lime, width: 3)
        line([CGPoint(x: 594, y: 173), CGPoint(x: 600, y: 160)], colour: lime, width: 3)
        line([CGPoint(x: 603, y: 185), CGPoint(x: 616, y: 182)], colour: lime, width: 3)
      } else if direction == .record {
        // Only the outside rim enters the window, like an LP tucked into a sleeve.
        for radius in stride(from: CGFloat(260), through: 348, by: 11) {
          let rect = CGRect(x: -145 - radius, y: 475 - radius, width: radius * 2, height: radius * 2)
          context.stroke(Path(ellipseIn: rect), with: .color(ink.opacity(0.07)), lineWidth: 0.7)
        }
        line([CGPoint(x: 679, y: 405), CGPoint(x: 693, y: 405)], colour: lime, width: 3)
      } else if direction == .margins {
        // A softly coloured record peeks in from the top left.
        let sleeve = Path(ellipseIn: CGRect(x: -51, y: 43, width: 143, height: 143))
        context.fill(sleeve, with: .color(Color(red: 0.78, green: 0.83, blue: 0.54).opacity(0.55)))
        for radius in [CGFloat(42), 51, 60] {
          context.stroke(
            Path(ellipseIn: CGRect(
              x: 17 - radius,
              y: 114 - radius,
              width: radius * 2,
              height: radius * 2
            )),
            with: .color(ink.opacity(0.15)),
            lineWidth: 1
          )
        }
        context.fill(Path(ellipseIn: CGRect(x: 5, y: 102, width: 24, height: 24)), with: .color(paper))
        context.fill(Path(ellipseIn: CGRect(x: 14, y: 111, width: 6, height: 6)), with: .color(ink.opacity(0.4)))

        // A relaxed pair of headphones, partly cropped at the right edge.
        let peach = Color(red: 0.90, green: 0.73, blue: 0.57)
        var arch = Path()
        arch.move(to: CGPoint(x: 685, y: 116))
        arch.addCurve(
          to: CGPoint(x: 773, y: 127),
          control1: CGPoint(x: 675, y: 33),
          control2: CGPoint(x: 773, y: 37)
        )
        context.stroke(arch, with: .color(peach), style: StrokeStyle(lineWidth: 14, lineCap: .round))
        context.fill(
          Path(roundedRect: CGRect(x: 674, y: 100, width: 24, height: 42), cornerRadius: 10),
          with: .color(peach)
        )
        context.fill(
          Path(roundedRect: CGRect(x: 758, y: 111, width: 23, height: 42), cornerRadius: 10),
          with: .color(peach)
        )
        line([CGPoint(x: 689, y: 100), CGPoint(x: 686, y: 120)], colour: ink.opacity(0.32), width: 2)

        // A loose music note at the bottom left.
        let lilac = Color(red: 0.72, green: 0.68, blue: 0.82)
        var note = Path()
        note.move(to: CGPoint(x: 73, y: 430))
        note.addCurve(
          to: CGPoint(x: 84, y: 367),
          control1: CGPoint(x: 77, y: 413),
          control2: CGPoint(x: 81, y: 381)
        )
        note.addQuadCurve(to: CGPoint(x: 114, y: 379), control: CGPoint(x: 101, y: 366))
        context.stroke(note, with: .color(lilac), style: StrokeStyle(lineWidth: 11, lineCap: .round))
        context.fill(Path(ellipseIn: CGRect(x: 49, y: 420, width: 30, height: 21)), with: .color(lilac))

        // A few abstract rhythm marks in the opposite corner.
        line([CGPoint(x: 649, y: 411), CGPoint(x: 655, y: 388)], colour: lime.opacity(0.8), width: 11)
        line([CGPoint(x: 672, y: 427), CGPoint(x: 686, y: 374)], colour: lime.opacity(0.8), width: 11)
        line([CGPoint(x: 702, y: 411), CGPoint(x: 707, y: 392)], colour: lime.opacity(0.8), width: 11)
      }
    }.accessibilityHidden(true).allowsHitTesting(false)
  }
}

struct NewStudy: View {
  let direction: Direction
  let single: Bool
  let artwork: Artwork
  let backgroundOnly: Bool

  var body: some View {
    ZStack {
      if direction == .margins {
        Color(red: 0.94, green: 0.96, blue: 0.86)
      } else if direction == .record {
        Color(red: 0.957, green: 0.947, blue: 0.910)
      } else {
        Color(red: 0.990, green: 0.987, blue: 0.973)
      }
      MarginDrawing(direction: direction)
      VStack(spacing: 0) {
        Text("Halfway").font(.custom("Baskerville", size: 28)).tracking(-0.6)
          .foregroundStyle(ink).padding(.top, 48)
        Spacer().frame(height: 99)
        HStack(alignment: .top, spacing: 34) {
          if !backgroundOnly {
            InstallItem(image: artwork.light, label: single ? "Install Halfway" : "Halfway", size: 136)
          } else {
            Color.clear.frame(width: 136, height: 166)
          }
          if !single {
            // The arrow belongs to the background artwork and survives background-only export.
            DrawnArrow().frame(width: 128, height: 136)
            if !backgroundOnly {
              InstallItem(image: artwork.folder, label: "Applications", size: 136, alias: true)
            } else {
              Color.clear.frame(width: 136, height: 166)
            }
          }
        }
        Spacer().frame(height: 45)
        Text(single ? "Double-click to install Halfway." : "Drag Halfway to Applications.")
          .font(.system(size: 15)).foregroundStyle(ink.opacity(0.8))
        Spacer()
      }
    }.frame(width: 760, height: 480).clipped()
  }
}

struct BrushArrow: View {
  var body: some View {
    Canvas { context, size in
      let scale = CGAffineTransform(scaleX: size.width / 150, y: size.height / 128)
      // One asymmetric filled outline gives the arrow the weight of a marker stroke.
      var path = Path()
      path.move(to: CGPoint(x: 8, y: 65))
      path.addCurve(to: CGPoint(x: 120, y: 60), control1: CGPoint(x: 32, y: 59), control2: CGPoint(x: 86, y: 58))
      path.addCurve(to: CGPoint(x: 105, y: 43), control1: CGPoint(x: 116, y: 55), control2: CGPoint(x: 105, y: 48))
      path.addCurve(to: CGPoint(x: 111, y: 40), control1: CGPoint(x: 103, y: 39), control2: CGPoint(x: 107, y: 37))
      path.addCurve(to: CGPoint(x: 144, y: 63), control1: CGPoint(x: 121, y: 47), control2: CGPoint(x: 135, y: 58))
      path.addCurve(to: CGPoint(x: 141, y: 70), control1: CGPoint(x: 148, y: 65), control2: CGPoint(x: 147, y: 67))
      path.addCurve(to: CGPoint(x: 115, y: 92), control1: CGPoint(x: 130, y: 77), control2: CGPoint(x: 122, y: 88))
      path.addCurve(to: CGPoint(x: 110, y: 87), control1: CGPoint(x: 109, y: 96), control2: CGPoint(x: 106, y: 91))
      path.addCurve(to: CGPoint(x: 125, y: 71), control1: CGPoint(x: 114, y: 81), control2: CGPoint(x: 119, y: 76))
      path.addCurve(to: CGPoint(x: 8, y: 72), control1: CGPoint(x: 83, y: 74), control2: CGPoint(x: 33, y: 77))
      path.addQuadCurve(to: CGPoint(x: 8, y: 65), control: CGPoint(x: -2, y: 69))
      path.closeSubpath()
      context.fill(path.applying(scale), with: .color(ink))
    }.accessibilityHidden(true)
  }
}

struct MinimalStudy: View {
  let direction: Direction
  let single: Bool
  let artwork: Artwork
  let backgroundOnly: Bool
  private var brush: Bool { direction == .whiteBrush || direction == .paperBrush || direction == .notchBrush }
  private var notches: Bool { Direction.current.contains(direction) }
  private var grooves: Bool { direction == .quietGrooves || direction == .whiteGrooves }
  private var warm: Bool { direction == .paperBrush || direction == .quietGrooves }

  var body: some View {
    ZStack {
      warm ? Color(red: 0.964, green: 0.955, blue: 0.928) : Color.white
      if notches && !single {
        Canvas { context, _ in
          let lime = Color(red: 0.73, green: 0.84, blue: 0.30)
          func tick(_ x: CGFloat, _ y: CGFloat, _ dx: CGFloat, _ dy: CGFloat, width: CGFloat = 2.8) {
            var path = Path()
            path.move(to: CGPoint(x: x, y: y))
            path.addLine(to: CGPoint(x: x + dx, y: y + dy))
            context.stroke(path, with: .color(lime), style: StrokeStyle(lineWidth: width, lineCap: .round))
          }
          switch direction {
          case .notchSmall:
            tick(139, 163, -2, -7, width: 2.4)
            tick(131, 172, -7, -2, width: 2.4)
            tick(620, 174, 3, -7, width: 2.4)
            tick(628, 182, 7, -2, width: 2.4)
          case .notchDestination:
            tick(627, 157, 1, -12)
            tick(639, 166, 7, -10)
            tick(649, 179, 12, -3)
          default:
            tick(133, 160, -4, -11)
            tick(124, 172, -11, -4)
            tick(627, 171, 5, -11)
            tick(636, 183, 12, -3)
          }
        }.accessibilityHidden(true)
      }
      if grooves {
        Canvas { context, _ in
          for radius in stride(from: CGFloat(255), through: 323, by: 17) {
            let path = Path(ellipseIn: CGRect(
              x: -200 - radius,
              y: 440 - radius,
              width: radius * 2,
              height: radius * 2
            ))
            context.stroke(path, with: .color(ink.opacity(0.065)), lineWidth: 0.75)
          }
        }.accessibilityHidden(true)
      }
      if direction == .whiteWordmark {
        Text("Halfway").font(.system(size: 23, weight: .medium)).tracking(-0.8).foregroundStyle(ink)
          .position(x: 380, y: 67)
      }
      HStack(alignment: .top, spacing: 40) {
        item(artwork.light, name: single ? "Install Halfway" : "Halfway")
        if !single {
          Group {
            if brush {
              BrushArrow()
            } else if direction == .whiteFine {
              Image(systemName: "arrow.right").font(.system(size: 32, weight: .ultraLight))
                .foregroundStyle(ink.opacity(0.65))
            } else {
              DrawnArrow()
            }
          }.frame(width: 150, height: 128)
          item(artwork.folder, name: "Applications", alias: true)
        }
      }.position(x: 380, y: 250)
      if (!brush || single) && !notches {
        Text(single ? "Double-click to install Halfway." : "Drag Halfway to Applications.")
          .font(.system(size: 13)).foregroundStyle(ink.opacity(0.65))
          .position(x: 380, y: 380)
      }
    }.frame(width: 760, height: 480).clipped()
  }

  @ViewBuilder
  private func item(_ image: NSImage, name: String, alias: Bool = false) -> some View {
    if backgroundOnly {
      Color.clear.frame(width: 128, height: 158)
    } else {
      InstallItem(image: image, label: name, size: 128, alias: alias)
    }
  }
}

struct DMGArt: View {
  let direction: Direction
  let single: Bool
  let artwork: Artwork
  var backgroundOnly = false
  private var instruction: String {
    single ? "Double-click below to install." : "Drag Halfway to Applications to install."
  }

  private var label: String { single ? "Install Halfway" : "Halfway" }

  @ViewBuilder private var items: some View {
    if !backgroundOnly {
      HStack(alignment: .top, spacing: 54) {
        InstallItem(image: artwork.light, label: label, size: single ? 164 : 136)
        if !single {
          Image(systemName: "arrow.right").font(.system(size: 25, weight: .light))
            .foregroundStyle(muted.opacity(0.7)).frame(height: 136)
          InstallItem(image: artwork.folder, label: "Applications", size: 136, alias: true)
        }
      }
    }
  }

  var body: some View {
    ZStack {
      direction == .quiet ? Color.white : paper
      if direction == .sleeve { Grooves() }
      switch direction {
      case .whiteBrush, .whiteFine, .whiteWordmark, .paperBrush, .quietGrooves, .whiteGrooves,
           .notchClassic, .notchSmall, .notchBrush, .notchDestination:
        MinimalStudy(direction: direction, single: single, artwork: artwork, backgroundOnly: backgroundOnly)
      case .drawn, .record, .margins:
        NewStudy(direction: direction, single: single, artwork: artwork, backgroundOnly: backgroundOnly)
      case .sleeve:
        VStack(spacing: 0) {
          Text("Welcome to Halfway.")
            .font(.custom("Baskerville", size: 47)).tracking(-1.5).foregroundStyle(ink)
            .padding(.top, 49)
          Text(instruction).font(.system(size: 15)).foregroundStyle(muted).padding(.top, 12)
          items.padding(.top, 43)
          Spacer()
          footer.padding(.horizontal, 35).padding(.bottom, 24)
        }
      case .quiet:
        VStack(spacing: 0) {
          Text("Install Halfway").font(.system(size: 30, weight: .semibold)).tracking(-0.8)
            .foregroundStyle(ink).padding(.top, 54)
          Text(instruction).font(.system(size: 15)).foregroundStyle(muted).padding(.top, 12)
          items.padding(.top, 43)
          Spacer()
          Text("Your Apple Music listening, saved to Last.fm.")
            .font(.system(size: 12)).foregroundStyle(muted).padding(.bottom, 28)
        }
      case .split:
        HStack(spacing: 0) {
          ZStack(alignment: .topLeading) {
            Color(red: 0.23, green: 0.27, blue: 0.18)
            Grooves(light: true)
            VStack(alignment: .leading, spacing: 0) {
              Text("Halfway").font(.custom("Baskerville", size: 31)).tracking(-0.6)
              Spacer()
              Text("Every listen.\nA little history.")
                .font(.custom("Baskerville", size: 36)).tracking(-0.7).lineSpacing(-2)
              Text("APPLE MUSIC  →  LAST.FM")
                .font(.system(size: 9, weight: .medium)).tracking(1.3).padding(.top, 22)
            }.foregroundStyle(Color(red: 0.91, green: 0.94, blue: 0.76)).padding(30)
          }.frame(width: 270)
          VStack(spacing: 0) {
            Text("Make yourself at home.")
              .font(.system(size: 23, weight: .medium)).tracking(-0.7).foregroundStyle(ink)
              .padding(.top, 60)
            Text(single ? "Double-click below to install." : "Drag Halfway to Applications.")
              .font(.system(size: 14)).foregroundStyle(muted).padding(.top, 13)
            if !backgroundOnly {
              if single {
                InstallItem(image: artwork.light, label: label, size: 152).padding(.top, 48)
              } else {
                HStack(alignment: .top, spacing: 19) {
                  InstallItem(image: artwork.light, label: label, size: 112)
                  Image(systemName: "arrow.right").font(.system(size: 20, weight: .light))
                    .foregroundStyle(muted).frame(height: 112)
                  InstallItem(image: artwork.folder, label: "Applications", size: 112, alias: true)
                }.padding(.top, 67)
              }
            }
            Spacer()
            Text("Once open, find the h in your menu bar.")
              .font(.system(size: 11)).foregroundStyle(muted).padding(.bottom, 27)
          }.frame(maxWidth: .infinity)
        }
      }
    }.frame(width: 760, height: 480).clipped()
  }

  private var footer: some View {
    HStack {
      Text("Apple Music → Last.fm").font(.system(size: 11))
      Spacer()
      Text("At home in your menu bar.").font(.system(size: 11))
    }.foregroundStyle(muted)
  }
}

struct FinderPreview: View {
  let direction: Direction
  let single: Bool
  let darkChrome: Bool
  let artwork: Artwork
  var body: some View {
    VStack(spacing: 0) {
      HStack(spacing: 8) {
        ForEach([
          Color(red: 1, green: 0.37, blue: 0.34),
          Color(red: 1, green: 0.75, blue: 0.18),
          Color(red: 0.18, green: 0.79, blue: 0.27),
        ], id: \.self) { colour in
          Circle().fill(colour).overlay(Circle().stroke(.black.opacity(0.1), lineWidth: 0.5))
            .frame(width: 12, height: 12)
        }
        Image(nsImage: artwork.light).resizable().frame(width: 18, height: 18).padding(.leading, 11)
        Text(single ? "Install Halfway" : "Halfway").font(.system(size: 14, weight: .semibold))
          .foregroundStyle(darkChrome ? Color.white.opacity(0.88) : Color.black.opacity(0.65))
        Spacer()
      }.padding(.horizontal, 16).frame(height: 41)
        .background(darkChrome ? Color(white: 0.19) : Color(white: 0.985))
      DMGArt(direction: direction, single: single, artwork: artwork)
    }.frame(width: 760).clipShape(RoundedRectangle(cornerRadius: 13))
      .overlay(RoundedRectangle(cornerRadius: 13).stroke(.black.opacity(0.16), lineWidth: 1))
  }
}

struct Workbench: View {
  let artwork: Artwork
  @State private var direction = Direction.notchClassic
  @State private var single = false
  @State private var darkChrome = false
  @State private var studySet = StudySet.notches
  private var directions: [Direction] { studySet.directions }
  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack {
        Picker("Design", selection: $direction) {
          ForEach(directions) { Text($0.name).tag($0) }
        }.pickerStyle(.segmented).frame(width: 630)
        Spacer()
        Toggle("Dark chrome", isOn: $darkChrome).toggleStyle(.switch).controlSize(.small)
      }
      HStack {
        Text(direction.thesis).font(.system(size: 12)).foregroundStyle(.secondary)
        Spacer()
        Picker("Installation", selection: $single) {
          Text("Double-click concept").tag(true)
          Text("Drag to install").tag(false)
        }.labelsHidden().frame(width: 190)
      }
      FinderPreview(direction: direction, single: single, darkChrome: darkChrome, artwork: artwork)
        .shadow(color: .black.opacity(0.13), radius: 18, y: 10)
        .frame(maxWidth: .infinity)
      HStack {
        Text(single
          ? "Concept only: requires an installation step."
          : "Design preview · fits the current drag-to-install flow.")
          .font(.system(size: 11)).foregroundStyle(.secondary)
        Spacer()
        Picker("Studies", selection: $studySet) {
          ForEach(StudySet.allCases) { Text($0.rawValue).tag($0) }
        }.labelsHidden().frame(width: 160)
          .onChange(of: studySet) { direction = directions[0] }
      }
      HStack(spacing: 0) {
        ForEach(Array(directions.indices), id: \.self) { index in
          Button("") { direction = directions[index] }
            .keyboardShortcut(KeyEquivalent(Character(String(index + 1))), modifiers: [])
        }
        Button("") { single.toggle() }.keyboardShortcut("i", modifiers: [])
        Button("") { darkChrome.toggle() }.keyboardShortcut("d", modifiers: [])
      }.hidden().frame(height: 0)
    }.padding(24).frame(width: 860).background(Color(nsColor: .windowBackgroundColor))
  }
}

@MainActor
func export<V: View>(_ view: V, path: String) throws {
  let renderer = ImageRenderer(content: view)
  renderer.scale = 2
  guard let image = renderer.cgImage else { fatalError("Could not render " + path) }
  let bitmap = NSBitmapImageRep(cgImage: image)
  try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path))
}

let arguments = CommandLine.arguments
guard arguments.count >= 2 else { fatalError("Usage: dmg-preview ASSETS_DIRECTORY [--export OUTPUT_DIRECTORY]") }
let app = NSApplication.shared
app.setActivationPolicy(.regular)
let artwork = Artwork(directory: arguments[1])
if arguments.count == 4, ["--export", "--export-current"].contains(arguments[2]) {
  let output = arguments[3]
  try FileManager.default.createDirectory(atPath: output, withIntermediateDirectories: true)
  let directions = arguments[2] == "--export-current" ? Direction.current : Direction.allCases
  for direction in directions {
    for single in [true, false] {
      let stem = direction.slug + (single ? "-single" : "-drag")
      for dark in [false, true] {
        try export(
          FinderPreview(direction: direction, single: single, darkChrome: dark, artwork: artwork),
          path: output + "/" + stem + (dark ? "-dark-chrome" : "") + ".png"
        )
      }
      try export(
        DMGArt(direction: direction, single: single, artwork: artwork, backgroundOnly: true),
        path: output + "/" + stem + "-background@2x.png"
      )
    }
  }
  print("Exported \(directions.count * 4) previews and \(directions.count * 2) backgrounds at 2×.")
} else {
  let window = NSWindow(
    contentRect: NSRect(x: 0, y: 0, width: 860, height: 670),
    styleMask: [.titled, .closable, .miniaturizable],
    backing: .buffered,
    defer: false
  )
  window.title = "Halfway · DMG design workbench"
  window.contentView = NSHostingView(rootView: Workbench(artwork: artwork))
  window.center()
  window.makeKeyAndOrderFront(nil)
  app.activate(ignoringOtherApps: true)
  app.run()
}
