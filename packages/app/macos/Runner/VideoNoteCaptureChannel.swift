import AVFoundation
import FlutterMacOS

/// Camera and microphone capture for video messages (circles), driven from
/// Dart over the `mollygram/video_note_capture` channel (VideoNoteRecorder
/// in packages/media).
///
/// Frames go to Flutter as a texture for the round preview and, at the
/// same time, into an H.264 + AAC MP4 cropped to a square of the side Dart
/// asks for (Telegram takes up to 640). Writing starts with the first
/// camera frame, so the camera warming up never shows as black.
final class VideoNoteCaptureChannel: NSObject, FlutterTexture,
  AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate
{
  private let channel: FlutterMethodChannel
  private let textures: FlutterTextureRegistry
  /// Capture callbacks and the writer live on this queue.
  private let queue = DispatchQueue(label: "dev.mollygram.video-note", qos: .userInitiated)

  private var session: AVCaptureSession?
  /// The camera in use; touched on the main thread.
  private var cameraInput: AVCaptureDeviceInput?
  private var textureId: Int64 = -1

  /// The newest camera frame, read by Flutter from its raster thread.
  private let frameLock = NSLock()
  private var frame: CVPixelBuffer?

  // Touched only on [queue].
  private var writer: AVAssetWriter?
  private var videoInput: AVAssetWriterInput?
  private var audioInput: AVAssetWriterInput?
  private var firstTime: CMTime?
  private var lastTime: CMTime = .zero
  private var path: String?

  init(messenger: FlutterBinaryMessenger, textures: FlutterTextureRegistry) {
    channel = FlutterMethodChannel(name: "mollygram/video_note_capture", binaryMessenger: messenger)
    self.textures = textures
    super.init()
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    switch call.method {
    case "permission":
      let statuses = [
        AVCaptureDevice.authorizationStatus(for: .video),
        AVCaptureDevice.authorizationStatus(for: .audio),
      ]
      if statuses.allSatisfy({ $0 == .authorized }) {
        result("granted")
      } else if statuses.contains(where: { $0 == .denied || $0 == .restricted }) {
        result("denied")
      } else {
        result("undetermined")
      }
    case "requestPermission":
      AVCaptureDevice.requestAccess(for: .video) { video in
        AVCaptureDevice.requestAccess(for: .audio) { audio in
          DispatchQueue.main.async { result(video && audio) }
        }
      }
    case "start":
      start(
        side: args["side"] as? Int ?? 640, path: args["path"] as? String ?? "",
        camera: args["camera"] as? String, result)
    case "switchCamera":
      switchCamera(result)
    case "stop":
      stop(result)
    case "cancel":
      cancel(result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: - Session

  /// The cameras a video message can use: built in, external and, on
  /// macOS 14, an iPhone through Continuity Camera.
  private static func cameras() -> [AVCaptureDevice] {
    var types: [AVCaptureDevice.DeviceType] = [.builtInWideAngleCamera]
    if #available(macOS 14.0, *) {
      types += [.external, .continuityCamera]
    } else {
      types.append(.externalUnknown)
    }
    return AVCaptureDevice.DiscoverySession(
      deviceTypes: types, mediaType: .video, position: .unspecified
    ).devices
  }

  /// An iPhone through Continuity Camera films with its back camera, but
  /// reports no position.
  private static func facesAway(_ device: AVCaptureDevice) -> Bool {
    if device.position == .back { return true }
    if #available(macOS 14.0, *) { return device.deviceType == .continuityCamera }
    return false
  }

  /// What Dart needs to show [device] in the round preview.
  private func previewInfo(_ device: AVCaptureDevice) -> [String: Any] {
    let dimensions = CMVideoFormatDescriptionGetDimensions(device.activeFormat.formatDescription)
    return [
      "textureId": textureId,
      "width": Int(dimensions.width),
      "height": Int(dimensions.height),
      "camera": device.uniqueID,
      "cameras": Self.cameras().count,
      // A camera that looks away from the user is shown as it is.
      "mirrored": !Self.facesAway(device),
    ]
  }

  private func start(
    side: Int, path: String, camera preferred: String?, _ result: @escaping FlutterResult
  ) {
    if session != nil {
      result(FlutterError(code: "busy", message: "Already recording.", details: nil))
      return
    }
    let chosen = Self.cameras().first { $0.uniqueID == preferred }
    guard let camera = chosen ?? AVCaptureDevice.default(for: .video),
      let cameraInput = try? AVCaptureDeviceInput(device: camera)
    else {
      result(FlutterError(code: "unavailable", message: "No camera.", details: nil))
      return
    }
    let session = AVCaptureSession()
    session.beginConfiguration()
    if session.canSetSessionPreset(.hd1280x720) { session.sessionPreset = .hd1280x720 }
    guard session.canAddInput(cameraInput) else {
      result(FlutterError(code: "unavailable", message: "Camera is busy.", details: nil))
      return
    }
    session.addInput(cameraInput)
    self.cameraInput = cameraInput
    let videoOutput = AVCaptureVideoDataOutput()
    videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
    videoOutput.alwaysDiscardsLateVideoFrames = true
    videoOutput.setSampleBufferDelegate(self, queue: queue)
    if session.canAddOutput(videoOutput) { session.addOutput(videoOutput) }

    if let microphone = AVCaptureDevice.default(for: .audio),
      let micInput = try? AVCaptureDeviceInput(device: microphone),
      session.canAddInput(micInput)
    {
      session.addInput(micInput)
      let audioOutput = AVCaptureAudioDataOutput()
      audioOutput.setSampleBufferDelegate(self, queue: queue)
      if session.canAddOutput(audioOutput) { session.addOutput(audioOutput) }
    }
    session.commitConfiguration()

    let url = URL(fileURLWithPath: path)
    try? FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try? FileManager.default.removeItem(at: url)
    guard let writer = try? AVAssetWriter(outputURL: url, fileType: .mp4) else {
      result(FlutterError(code: "unavailable", message: "Cannot write the file.", details: nil))
      return
    }
    let video = AVAssetWriterInput(
      mediaType: .video,
      outputSettings: [
        AVVideoCodecKey: AVVideoCodecType.h264,
        AVVideoWidthKey: side,
        AVVideoHeightKey: side,
        // Fills the square from the middle of the wide camera frame.
        AVVideoScalingModeKey: AVVideoScalingModeResizeAspectFill,
        AVVideoCompressionPropertiesKey: [
          AVVideoAverageBitRateKey: side * side * 5,
          AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
          AVVideoExpectedSourceFrameRateKey: 30,
        ],
      ])
    video.expectsMediaDataInRealTime = true
    let audio = AVAssetWriterInput(
      mediaType: .audio,
      outputSettings: [
        AVFormatIDKey: kAudioFormatMPEG4AAC,
        AVNumberOfChannelsKey: 1,
        AVSampleRateKey: 48000,
        AVEncoderBitRateKey: 64000,
      ])
    audio.expectsMediaDataInRealTime = true
    if writer.canAdd(video) { writer.add(video) }
    if writer.canAdd(audio) { writer.add(audio) }

    self.session = session
    textureId = textures.register(self)
    queue.async { [weak self] in
      guard let self = self else { return }
      self.writer = writer
      self.videoInput = video
      self.audioInput = audio
      self.firstTime = nil
      self.lastTime = .zero
      self.path = path
      session.startRunning()
      DispatchQueue.main.async {
        result(self.previewInfo(camera))
      }
    }
  }

  /// Goes on recording with the next camera. The file keeps going: the
  /// writer scales every camera to the same square.
  private func switchCamera(_ result: @escaping FlutterResult) {
    guard let session = session, let current = cameraInput else {
      result(FlutterError(code: "idle", message: "Not recording.", details: nil))
      return
    }
    let all = Self.cameras()
    let index = all.firstIndex { $0.uniqueID == current.device.uniqueID } ?? -1
    // The others in order after the current one; a camera that cannot be
    // opened is skipped, so it never hides the ones after it.
    let candidates = (1..<max(all.count, 1)).map { all[(index + $0 + all.count) % all.count] }
      .filter { $0.uniqueID != current.device.uniqueID }
    queue.async { [weak self] in
      session.beginConfiguration()
      session.removeInput(current)
      var now = current
      for device in candidates {
        if let input = try? AVCaptureDeviceInput(device: device), session.canAddInput(input) {
          now = input
          break
        }
      }
      session.addInput(now)
      session.sessionPreset = session.canSetSessionPreset(.hd1280x720) ? .hd1280x720 : .high
      session.commitConfiguration()
      DispatchQueue.main.async {
        guard let self = self, self.session === session else {
          result(nil)
          return
        }
        self.cameraInput = now
        result(self.previewInfo(now.device))
      }
    }
  }

  private func stop(_ result: @escaping FlutterResult) {
    queue.async { [weak self] in
      guard let self = self else { return }
      guard let writer = self.writer, let first = self.firstTime, let path = self.path,
        writer.status == .writing
      else {
        self.discard()
        DispatchQueue.main.async {
          self.teardown()
          result(FlutterError(code: "empty", message: "Nothing was recorded.", details: nil))
        }
        return
      }
      let duration = CMTimeSubtract(self.lastTime, first)
      self.videoInput?.markAsFinished()
      self.audioInput?.markAsFinished()
      writer.endSession(atSourceTime: self.lastTime)
      self.writer = nil
      writer.finishWriting {
        let ok = writer.status == .completed
        DispatchQueue.main.async {
          self.teardown()
          if ok {
            result(["path": path, "durationMs": Int(CMTimeGetSeconds(duration) * 1000)])
          } else {
            result(FlutterError(code: "failed", message: writer.error?.localizedDescription, details: nil))
          }
        }
      }
    }
  }

  private func cancel(_ result: @escaping FlutterResult) {
    queue.async { [weak self] in
      self?.discard()
      DispatchQueue.main.async {
        self?.teardown()
        result(nil)
      }
    }
  }

  /// On [queue]: drops the file being written.
  private func discard() {
    if let writer = writer, writer.status == .writing { writer.cancelWriting() }
    writer = nil
    if let path = path { try? FileManager.default.removeItem(atPath: path) }
    path = nil
  }

  /// On the main thread: stops the camera and the preview.
  private func teardown() {
    if let session = session {
      queue.async { session.stopRunning() }
    }
    session = nil
    cameraInput = nil
    if textureId >= 0 { textures.unregisterTexture(textureId) }
    textureId = -1
    frameLock.lock()
    frame = nil
    frameLock.unlock()
  }

  // MARK: - Frames

  func copyPixelBuffer() -> Unmanaged<CVPixelBuffer>? {
    frameLock.lock()
    defer { frameLock.unlock() }
    guard let frame = frame else { return nil }
    return Unmanaged.passRetained(frame)
  }

  func captureOutput(
    _ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer,
    from connection: AVCaptureConnection
  ) {
    let time = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
    if output is AVCaptureVideoDataOutput {
      if let pixels = CMSampleBufferGetImageBuffer(sampleBuffer) {
        frameLock.lock()
        frame = pixels
        frameLock.unlock()
        let id = textureId
        DispatchQueue.main.async { [weak self] in
          if id >= 0, id == self?.textureId { self?.textures.textureFrameAvailable(id) }
        }
      }
      guard let writer = writer, let input = videoInput else { return }
      if firstTime == nil {
        guard writer.startWriting() else { return }
        writer.startSession(atSourceTime: time)
        firstTime = time
      }
      if writer.status == .writing, input.isReadyForMoreMediaData, input.append(sampleBuffer),
        CMTimeCompare(time, lastTime) > 0
      {
        lastTime = time
      }
    } else if output is AVCaptureAudioDataOutput {
      guard let writer = writer, let input = audioInput, let first = firstTime,
        CMTimeCompare(time, first) >= 0, writer.status == .writing,
        input.isReadyForMoreMediaData
      else { return }
      input.append(sampleBuffer)
    }
  }
}
