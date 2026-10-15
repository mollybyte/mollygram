import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  override func applicationDidFinishLaunching(_ notification: Notification) {
    super.applicationDidFinishLaunching(notification)
    registerAppIconChannel()
  }

  /// Appearance's "App icon": Dart sends the PNG of the chosen Dock icon,
  /// or asks for the one from the bundle back. Only the running app's Dock
  /// tile changes; Finder keeps the bundled icon.
  private func registerAppIconChannel() {
    guard let window = mainFlutterWindow,
          let controller = window.contentViewController as? FlutterViewController
    else { return }
    let channel = FlutterMethodChannel(
      name: "mollygram/app_icon",
      binaryMessenger: controller.engine.binaryMessenger)
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "set":
        if let data = call.arguments as? FlutterStandardTypedData,
           let image = NSImage(data: data.data) {
          NSApp.applicationIconImage = image
          result(nil)
        } else {
          result(FlutterError(code: "bad_image", message: "Not a PNG", details: nil))
        }
      case "reset":
        NSApp.applicationIconImage = nil
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
