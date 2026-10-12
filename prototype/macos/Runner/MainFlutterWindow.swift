import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController

    // Контент под прозрачной строкой заголовка: кнопки окна остаются
    // системными и ложатся на стеклянную боковую панель.
    self.titlebarAppearsTransparent = true
    self.titleVisibility = .hidden
    self.styleMask.insert(.fullSizeContentView)
    self.minSize = NSSize(width: 880, height: 560)
    self.setContentSize(NSSize(width: 1440, height: 900))
    self.center()

    // Flutter забирает все события мыши, поэтому окно перетаскивается
    // по запросу из Dart с пустых мест шапок.
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
  }
}
