import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  /// Where the window buttons go, in points from the window's top-left
  /// corner. The sidebar island is inset 8 pt and its title bar row is 44 pt
  /// tall (SidebarIsland in ui_kit), so the buttons are centered in that row
  /// (8 + 44 / 2) with the same 15 pt gap to the island's left edge as to its
  /// top edge.
  private static let buttonsCenterY: CGFloat = 30
  private static let buttonsLeft: CGFloat = 23
  private static let buttonsSpacing: CGFloat = 20

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController

    // Content extends under a transparent title bar: the window buttons stay
    // native and sit on top of the glass sidebar.
    self.titlebarAppearsTransparent = true
    self.titleVisibility = .hidden
    self.styleMask.insert(.fullSizeContentView)
    self.minSize = NSSize(width: 880, height: 560)
    self.setContentSize(NSSize(width: 1200, height: 780))
    self.center()

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
      case "zoom":
        self.zoom(nil)
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
    placeWindowButtons()
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
