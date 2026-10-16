import Cocoa
import FlutterMacOS

/// The blur layer behind Flutter's surface. It only paints: it never takes a
/// click, a drag or the first-responder role from the Flutter view above it.
private final class PassiveEffectView: NSVisualEffectView {
  override func hitTest(_ point: NSPoint) -> NSView? { nil }
  override var acceptsFirstResponder: Bool { false }
  override var mouseDownCanMoveWindow: Bool { false }
  override func acceptsFirstMouse(for event: NSEvent?) -> Bool { false }
}

class MainFlutterWindow: NSWindow {
  /// Where the window buttons go, in points from the window's top-left
  /// corner. The sidebar island is inset 8 pt and its title bar row is 44 pt
  /// tall (SidebarIsland in ui_kit), so the buttons are centered in that row
  /// (8 + 44 / 2) with the same 15 pt gap to the island's left edge as to its
  /// top edge.
  private static let buttonsCenterY: CGFloat = 30
  private static let buttonsLeft: CGFloat = 23
  private static let buttonsSpacing: CGFloat = 20

  /// The user defaults key under which AppKit keeps the window frame.
  private static let frameName = "MainWindow"

  /// The blur behind the window while the Vesper Blur theme is on.
  private var vibrancyView: PassiveEffectView?

  private var notifications: NotificationsChannel?
  private var voiceCapture: VoiceCaptureChannel?
  private var videoNoteCapture: VideoNoteCaptureChannel?
  private var videoEdit: VideoEditChannel?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    // The view's own backing is black and shows wherever Flutter's surface
    // doesn't reach (the rounded corners, a fractional edge pixel); it is
    // made clear so the window's background, which Dart sets to the
    // frame's colour, shows there instead.
    flutterViewController.backgroundColor = .clear
    self.contentViewController = flutterViewController

    // Content extends under a transparent title bar: the window buttons stay
    // native and sit on top of the glass sidebar.
    self.titlebarAppearsTransparent = true
    self.titleVisibility = .hidden
    self.styleMask.insert(.fullSizeContentView)
    self.minSize = NSSize(width: 880, height: 560)
    // The size and position come back on the next launch; the defaults are
    // for the first one only.
    if !self.setFrameUsingName(Self.frameName) {
      self.setContentSize(NSSize(width: 1200, height: 780))
      self.center()
    }
    self.setFrameAutosaveName(Self.frameName)

    // Flutter takes all mouse events, so Dart asks the window to start a
    // drag when an empty header area is pressed.
    let channel = FlutterMethodChannel(
      name: "mollygram/window",
      binaryMessenger: flutterViewController.engine.binaryMessenger)
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { return }
      switch call.method {
      case "startDrag":
        if let event = NSApp.currentEvent { self.performDrag(with: event) }
        result(nil)
      case "setBlurred":
        self.setBlurred(call.arguments as? Bool ?? false)
        result(nil)
      case "setBackgroundColor":
        // The blurred theme keeps the window clear.
        if self.vibrancyView == nil, let argb = call.arguments as? Int {
          self.backgroundColor = NSColor(
            srgbRed: CGFloat((argb >> 16) & 0xFF) / 255,
            green: CGFloat((argb >> 8) & 0xFF) / 255,
            blue: CGFloat(argb & 0xFF) / 255,
            alpha: 1)
        }
        result(nil)
      case "setAppearance":
        // The app's own theme, not the system's: AppKit draws the window's
        // outline and shadow for the window's appearance. The blurred theme
        // keeps its own dark appearance.
        if self.vibrancyView == nil {
          let dark = call.arguments as? Bool ?? false
          self.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        }
        result(nil)
      case "zoom":
        self.zoom(nil)
        result(nil)
      case "setContentProtection":
        // Kept out of screenshots and screen recordings (secret chats).
        let protect = call.arguments as? Bool ?? false
        self.sharingType = protect ? .none : .readOnly
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    // Appearance's "App icon": Dart sends the PNG of the chosen Dock icon,
    // or asks for the bundled one back. Only the running app's Dock tile
    // changes; Finder keeps the bundled icon. Registered here, before Dart
    // runs, so the choice saved last time is applied at launch.
    let appIcon = FlutterMethodChannel(
      name: "mollygram/app_icon",
      binaryMessenger: flutterViewController.engine.binaryMessenger)
    appIcon.setMethodCallHandler { call, result in
      switch call.method {
      case "set":
        if let data = call.arguments as? FlutterStandardTypedData,
           let image = NSImage(data: data.data) {
          NSApp.applicationIconImage = image
          NSApp.dockTile.display()
          result(nil)
        } else {
          result(FlutterError(code: "bad_image", message: "Not a PNG", details: nil))
        }
      case "reset":
        NSApp.applicationIconImage = nil
        NSApp.dockTile.display()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    // Set up before launch finishes, so a notification tap that launched
    // the app is not lost.
    notifications = NotificationsChannel(
      messenger: flutterViewController.engine.binaryMessenger, window: self)

    voiceCapture = VoiceCaptureChannel(messenger: flutterViewController.engine.binaryMessenger)
    videoNoteCapture = VideoNoteCaptureChannel(
      messenger: flutterViewController.engine.binaryMessenger,
      textures: flutterViewController.registrar(forPlugin: "VideoNoteCapture").textures)
    videoEdit = VideoEditChannel(messenger: flutterViewController.engine.binaryMessenger)

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
    placeWindowButtons()
  }

  /// Turns the blurred, see-through window on or off. On, the window stops
  /// being opaque and a vibrancy view behind Flutter's surface blurs what
  /// lies under the window; the dark appearance keeps the material matte
  /// graphite whatever the system theme is.
  private func setBlurred(_ on: Bool) {
    if on {
      if vibrancyView == nil, let frameView = contentView?.superview,
         let content = contentView {
        let effect = PassiveEffectView(frame: frameView.bounds)
        effect.autoresizingMask = [.width, .height]
        effect.material = .hudWindow
        effect.blendingMode = .behindWindow
        effect.state = .active
        // Bottom-most in the frame view, so it can never sit over the content.
        frameView.addSubview(effect, positioned: .below, relativeTo: nil)
        vibrancyView = effect
      }
      appearance = NSAppearance(named: .darkAqua)
      isOpaque = false
      backgroundColor = .clear
      ignoresMouseEvents = false
      makeFirstResponder(contentViewController?.view)
    } else {
      vibrancyView?.removeFromSuperview()
      vibrancyView = nil
      appearance = nil
      isOpaque = true
      // Dart sends the frame's colour again once the blur is off.
    }
    invalidateShadow()
  }

  // AppKit puts the buttons back at their default spot whenever it lays out
  // the title bar (resize, full screen, key state), so they are moved again
  // after every layout pass.
  override func layoutIfNeeded() {
    super.layoutIfNeeded()
    placeWindowButtons()
  }

  private func placeWindowButtons() {
    // In full screen the buttons live in the menu-bar reveal; leave them.
    if styleMask.contains(.fullScreen) { return }
    guard
      let close = standardWindowButton(.closeButton),
      let titlebar = close.superview,
      let container = titlebar.superview,
      let frameView = container.superview
    else { return }
    let buttons: [NSView] = [
      close,
      standardWindowButton(.miniaturizeButton),
      standardWindowButton(.zoomButton),
    ].compactMap { $0 }

    // The native title bar takes the clicks it covers, so it is cut down to
    // just around the buttons: tall enough for them to sit 30 pt down, above
    // the search field (52 pt), and no wider than the buttons, so the rest
    // of the sidebar's title row (drag area, actions) stays Flutter's.
    let buttonHeight = close.frame.height
    let height = (Self.buttonsCenterY + buttonHeight / 2 + 4).rounded()
    let width = min(
      frameView.bounds.width,
      Self.buttonsLeft + CGFloat(buttons.count - 1) * Self.buttonsSpacing
        + close.frame.width + 4)
    let frame = NSRect(
      x: 0, y: frameView.bounds.height - height, width: width, height: height)
    if container.frame != frame { container.frame = frame }
    if titlebar.frame != container.bounds { titlebar.frame = container.bounds }

    // The title bar is not flipped: y counts up from its bottom edge.
    let y = (height - Self.buttonsCenterY - buttonHeight / 2).rounded()
    for (i, button) in buttons.enumerated() {
      let origin = NSPoint(x: Self.buttonsLeft + CGFloat(i) * Self.buttonsSpacing, y: y)
      if button.frame.origin != origin { button.setFrameOrigin(origin) }
    }
  }
}
