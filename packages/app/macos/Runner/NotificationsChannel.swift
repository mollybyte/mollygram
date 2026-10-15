import Cocoa
import FlutterMacOS
import UserNotifications

/// Desktop notifications and the dock badge, driven from Dart over the
/// `mollygram/notifications` channel (lib/src/notifications).
///
/// Dart decides what to show; this side builds the system notification
/// (title, avatar, reply field), hides banners while the window is in
/// front, as the official client does, and sends taps and replies back.
/// Responses that arrive before Dart is listening, such as the tap that
/// launched the app, wait until Dart calls `configure`.
final class NotificationsChannel: NSObject, UNUserNotificationCenterDelegate {
  private static let replyCategory = "message"
  private static let readOnlyCategory = "message.readonly"
  private static let replyAction = "reply"
  private static let readAction = "read"

  private let channel: FlutterMethodChannel
  private weak var window: NSWindow?
  private let center = UNUserNotificationCenter.current()
  private var dartReady = false
  private var pending: [(method: String, arguments: [String: Any])] = []

  init(messenger: FlutterBinaryMessenger, window: NSWindow) {
    channel = FlutterMethodChannel(name: "mollygram/notifications", binaryMessenger: messenger)
    self.window = window
    super.init()
    center.delegate = self
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    switch call.method {
    case "configure":
      registerCategories(labels: args)
      dartReady = true
      let queued = pending
      pending.removeAll()
      for response in queued { channel.invokeMethod(response.method, arguments: response.arguments) }
      result(nil)
    case "requestAuthorization":
      center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
        DispatchQueue.main.async { result(granted) }
      }
    case "status":
      center.getNotificationSettings { settings in
        let status: String
        switch settings.authorizationStatus {
        case .denied: status = "denied"
        case .notDetermined: status = "notDetermined"
        default: status = "authorized"
        }
        DispatchQueue.main.async { result(status) }
      }
    case "show":
      show(args)
      result(nil)
    case "remove":
      let ids = args["ids"] as? [String] ?? []
      center.removeDeliveredNotifications(withIdentifiers: ids)
      center.removePendingNotificationRequests(withIdentifiers: ids)
      result(nil)
    case "retain":
      let keep = Set(args["ids"] as? [String] ?? [])
      center.getDeliveredNotifications { [center] delivered in
        let stale = delivered.map(\.request.identifier).filter { !keep.contains($0) }
        center.removeDeliveredNotifications(withIdentifiers: stale)
      }
      result(nil)
    case "removeAll":
      center.removeAllDeliveredNotifications()
      center.removeAllPendingNotificationRequests()
      result(nil)
    case "setBadge":
      let label = args["label"] as? String
      NSApp.dockTile.badgeLabel = (label?.isEmpty ?? true) ? nil : label
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func registerCategories(labels: [String: Any]) {
    let markRead = UNNotificationAction(
      identifier: Self.readAction, title: labels["markRead"] as? String ?? "Mark as Read")
    let reply = UNTextInputNotificationAction(
      identifier: Self.replyAction,
      title: labels["reply"] as? String ?? "Reply",
      options: [],
      textInputButtonTitle: labels["send"] as? String ?? "Send",
      textInputPlaceholder: labels["placeholder"] as? String ?? "")
    center.setNotificationCategories([
      UNNotificationCategory(
        identifier: Self.replyCategory, actions: [reply, markRead], intentIdentifiers: []),
      UNNotificationCategory(
        identifier: Self.readOnlyCategory, actions: [markRead], intentIdentifiers: []),
    ])
  }

  private func show(_ args: [String: Any]) {
    guard let id = args["id"] as? String else { return }
    let content = UNMutableNotificationContent()
    content.title = args["title"] as? String ?? ""
    content.subtitle = args["subtitle"] as? String ?? ""
    content.body = args["body"] as? String ?? ""
    content.threadIdentifier = args["thread"] as? String ?? ""
    content.categoryIdentifier =
      args["canReply"] as? Bool ?? false ? Self.replyCategory : Self.readOnlyCategory
    content.userInfo = args["payload"] as? [String: Any] ?? [:]
    if args["sound"] as? Bool ?? false { content.sound = .default }
    // An edit replaces the text in Notification Center without a new banner.
    if args["quiet"] as? Bool ?? false { content.interruptionLevel = .passive }
    if let avatar = Avatar.file(
      photoPath: args["photoPath"] as? String, monogram: args["monogram"] as? String ?? ""),
      let attachment = try? UNNotificationAttachment(identifier: "avatar", url: avatar)
    {
      content.attachments = [attachment]
    }
    center.add(UNNotificationRequest(identifier: id, content: content, trigger: nil))
  }

  // MARK: UNUserNotificationCenterDelegate

  func userNotificationCenter(
    _ center: UNUserNotificationCenter, willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    // The window is in front: the message is already on screen or a click
    // away, so no banner and no sound.
    if NSApp.isActive, window?.isKeyWindow == true {
      completionHandler([])
    } else {
      completionHandler([.banner, .list, .sound])
    }
  }

  func userNotificationCenter(
    _ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    var payload = response.notification.request.content.userInfo as? [String: Any] ?? [:]
    payload["id"] = response.notification.request.identifier
    switch response.actionIdentifier {
    case UNNotificationDefaultActionIdentifier:
      NSApp.activate(ignoringOtherApps: true)
      window?.makeKeyAndOrderFront(nil)
      send("open", payload)
    case Self.replyAction:
      if let text = (response as? UNTextInputNotificationResponse)?.userText {
        payload["text"] = text
        send("reply", payload)
      }
    case Self.readAction:
      send("markRead", payload)
    default:
      break
    }
    completionHandler()
  }

  private func send(_ method: String, _ arguments: [String: Any]) {
    DispatchQueue.main.async { [self] in
      if dartReady {
        channel.invokeMethod(method, arguments: arguments)
      } else {
        pending.append((method, arguments))
      }
    }
  }
}

/// The round picture on the right of a notification: the chat photo, or the
/// app's gray monogram when the chat has none.
private enum Avatar {
  private static let size: CGFloat = 96
  private static let top = NSColor(srgbRed: 0xA9 / 255, green: 0xAD / 255, blue: 0xB6 / 255, alpha: 1)
  private static let bottom = NSColor(srgbRed: 0x87 / 255, green: 0x8B / 255, blue: 0x94 / 255, alpha: 1)

  /// A fresh PNG in the temporary directory: the system moves attachment
  /// files into its own store, so each notification gets its own copy.
  static func file(photoPath: String?, monogram: String) -> URL? {
    let photo = photoPath.flatMap { NSImage(contentsOfFile: $0) }
    if photo == nil && monogram.isEmpty { return nil }
    let rect = NSRect(x: 0, y: 0, width: size, height: size)
    guard
      let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size), bitsPerSample: 8,
        samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
        bytesPerRow: 0, bitsPerPixel: 0),
      let context = NSGraphicsContext(bitmapImageRep: bitmap)
    else { return nil }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    NSBezierPath(ovalIn: rect).addClip()
    if let photo = photo {
      photo.draw(in: aspectFill(photo.size, in: rect), from: .zero, operation: .copy, fraction: 1)
    } else {
      NSGradient(starting: top, ending: bottom)?.draw(in: rect, angle: -90)
      let text = NSAttributedString(
        string: monogram,
        attributes: [
          .font: NSFont.systemFont(ofSize: size * 0.36, weight: .semibold),
          .foregroundColor: NSColor.white,
        ])
      let textSize = text.size()
      text.draw(
        at: NSPoint(x: (size - textSize.width) / 2, y: (size - textSize.height) / 2))
    }
    NSGraphicsContext.restoreGraphicsState()
    guard let png = bitmap.representation(using: .png, properties: [:]) else { return nil }
    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent("notification-avatar-\(UUID().uuidString).png")
    do {
      try png.write(to: url)
      return url
    } catch {
      return nil
    }
  }

  private static func aspectFill(_ image: NSSize, in rect: NSRect) -> NSRect {
    guard image.width > 0, image.height > 0 else { return rect }
    let scale = max(rect.width / image.width, rect.height / image.height)
    let width = image.width * scale
    let height = image.height * scale
    return NSRect(x: (rect.width - width) / 2, y: (rect.height - height) / 2, width: width, height: height)
  }
}
