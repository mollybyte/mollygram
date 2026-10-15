import AVFoundation
import Cocoa
import FlutterMacOS

/// Reading and rewriting outgoing videos for the editor, driven from Dart
/// over the `mollygram/video_edit` channel (NativeVideoEngine in the app).
///
/// `probe` reads the size, length and sound of a file; `frame` renders the
/// frame at a time as JPEG, oriented the way it plays; `export` keeps a
/// range of the video, with or without its sound, and writes it next to
/// JPEGs of the cover frame. All work runs off the main thread and results
/// are delivered back on it.
final class VideoEditChannel {
  private let channel: FlutterMethodChannel
  private let queue = DispatchQueue(label: "dev.mollygram.video-edit", qos: .userInitiated)

  /// The generator of the file scrubbed last, kept so every frame does not
  /// reopen the asset.
  private var generatorPath: String?
  private var generator: AVAssetImageGenerator?

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "mollygram/video_edit", binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    guard let path = args["path"] as? String else {
      result(FlutterError(code: "argument", message: "No path.", details: nil))
      return
    }
    let reply: FlutterResult = { value in DispatchQueue.main.async { result(value) } }
    switch call.method {
    case "probe":
      queue.async { self.probe(path, reply) }
    case "frame":
      let ms = args["ms"] as? Int ?? 0
      let maxSide = args["maxSide"] as? Int ?? 1280
      queue.async { self.frame(path, ms: ms, maxSide: maxSide, reply) }
    case "export":
      queue.async { self.export(path, args, reply) }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: - Probe

  private func probe(_ path: String, _ result: @escaping FlutterResult) {
    let asset = AVURLAsset(url: URL(fileURLWithPath: path))
    guard let track = asset.tracks(withMediaType: .video).first else {
      result(FlutterError(code: "unreadable", message: "No video track.", details: nil))
      return
    }
    let size = Self.displaySize(of: track)
    result([
      "durationMs": Int((CMTimeGetSeconds(asset.duration) * 1000).rounded()),
      "width": Int(size.width.rounded()),
      "height": Int(size.height.rounded()),
      "hasAudio": !asset.tracks(withMediaType: .audio).isEmpty,
    ])
  }

  /// The size a track shows at, with its rotation applied.
  private static func displaySize(of track: AVAssetTrack) -> CGSize {
    let size = track.naturalSize.applying(track.preferredTransform)
    return CGSize(width: abs(size.width), height: abs(size.height))
  }

  // MARK: - Frames

  private func frame(_ path: String, ms: Int, maxSide: Int, _ result: @escaping FlutterResult) {
    let generator: AVAssetImageGenerator
    if let cached = self.generator, generatorPath == path {
      generator = cached
    } else {
      generator = AVAssetImageGenerator(asset: AVURLAsset(url: URL(fileURLWithPath: path)))
      generator.appliesPreferredTrackTransform = true
      // Scrubbing wants speed over the exact frame.
      generator.requestedTimeToleranceBefore = CMTime(value: 1, timescale: 10)
      generator.requestedTimeToleranceAfter = CMTime(value: 1, timescale: 10)
      self.generator = generator
      generatorPath = path
    }
    generator.maximumSize = CGSize(width: maxSide, height: maxSide)
    do {
      let image = try generator.copyCGImage(
        at: CMTime(value: CMTimeValue(ms), timescale: 1000), actualTime: nil)
      guard let data = Self.jpeg(image, quality: 0.86) else {
        throw NSError(domain: "VideoEditChannel", code: 1)
      }
      result(FlutterStandardTypedData(bytes: data))
    } catch {
      result(FlutterError(code: "unreadable", message: error.localizedDescription, details: nil))
    }
  }

  private static func jpeg(_ image: CGImage, quality: Double) -> Data? {
    NSBitmapImageRep(cgImage: image).representation(
      using: .jpeg, properties: [.compressionFactor: quality])
  }

  /// A JPEG of the frame at [seconds], exact to the frame, no larger than
  /// [maxSide], written to [url].
  private static func writeFrame(
    of asset: AVAsset, at seconds: Double, maxSide: Int, to url: URL
  ) throws -> CGSize {
    let generator = AVAssetImageGenerator(asset: asset)
    generator.appliesPreferredTrackTransform = true
    generator.requestedTimeToleranceBefore = .zero
    generator.requestedTimeToleranceAfter = .zero
    generator.maximumSize = CGSize(width: maxSide, height: maxSide)
    let time = CMTime(seconds: seconds, preferredTimescale: 1000)
    let image = try generator.copyCGImage(at: time, actualTime: nil)
    guard let data = jpeg(image, quality: 0.9) else {
      throw NSError(domain: "VideoEditChannel", code: 2)
    }
    try data.write(to: url)
    return CGSize(width: image.width, height: image.height)
  }

  // MARK: - Export

  private func export(_ path: String, _ args: [String: Any], _ result: @escaping FlutterResult) {
    let asset = AVURLAsset(url: URL(fileURLWithPath: path))
    let startMs = args["startMs"] as? Int ?? 0
    let endMs = args["endMs"] as? Int
    let muted = args["muted"] as? Bool ?? false
    let coverMs = args["coverMs"] as? Int
    let outputDirectory = args["outputDirectory"] as? String ?? NSTemporaryDirectory()

    guard let videoTrack = asset.tracks(withMediaType: .video).first else {
      result(FlutterError(code: "unreadable", message: "No video track.", details: nil))
      return
    }
    let start = CMTime(value: CMTimeValue(startMs), timescale: 1000)
    let end = endMs.map { CMTime(value: CMTimeValue($0), timescale: 1000) } ?? asset.duration
    let range = CMTimeRange(start: start, end: min(end, asset.duration))

    // The kept range goes into a composition, with the sound unless it is
    // muted; the export then writes the composition.
    let composition = AVMutableComposition()
    do {
      guard
        let video = composition.addMutableTrack(
          withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
      else { throw NSError(domain: "VideoEditChannel", code: 3) }
      try video.insertTimeRange(range, of: videoTrack, at: .zero)
      video.preferredTransform = videoTrack.preferredTransform
      if !muted, let audioTrack = asset.tracks(withMediaType: .audio).first,
        let audio = composition.addMutableTrack(
          withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
      {
        try audio.insertTimeRange(range, of: audioTrack, at: .zero)
      }
    } catch {
      result(FlutterError(code: "unreadable", message: error.localizedDescription, details: nil))
      return
    }

    let directory = URL(fileURLWithPath: outputDirectory)
      .appendingPathComponent("mollygram-video-\(UUID().uuidString.prefix(8))")
    let name = URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
    let output = directory.appendingPathComponent("\(name).mp4")
    do {
      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    } catch {
      result(FlutterError(code: "unwritable", message: error.localizedDescription, details: nil))
      return
    }

    // The cover: the chosen frame, or the first kept one. The same frame,
    // small, is the message thumbnail.
    let coverSeconds = coverMs.map { Double($0) / 1000 } ?? CMTimeGetSeconds(start)
    let cover = directory.appendingPathComponent("cover.jpg")
    let thumbnail = directory.appendingPathComponent("thumbnail.jpg")
    do {
      _ = try Self.writeFrame(of: asset, at: coverSeconds, maxSide: 1280, to: cover)
      _ = try Self.writeFrame(of: asset, at: coverSeconds, maxSide: 320, to: thumbnail)
    } catch {
      result(FlutterError(code: "unreadable", message: error.localizedDescription, details: nil))
      return
    }

    let size = Self.displaySize(of: videoTrack)
    let finish: (Bool) -> Void = { ok in
      guard ok else { return }
      result([
        "path": output.path,
        "width": Int(size.width.rounded()),
        "height": Int(size.height.rounded()),
        "durationMs": Int((CMTimeGetSeconds(range.duration) * 1000).rounded()),
        "cover": cover.path,
        "thumbnail": thumbnail.path,
      ])
    }
    // Passthrough keeps the picture as it is and is nearly instant; when
    // the source cannot go into an MP4 untouched, it is re-encoded.
    Self.run(composition, preset: AVAssetExportPresetPassthrough, to: output) { error in
      if error == nil {
        finish(true)
        return
      }
      try? FileManager.default.removeItem(at: output)
      Self.run(composition, preset: AVAssetExportPresetHighestQuality, to: output) { error in
        if let error = error {
          result(FlutterError(code: "export", message: error.localizedDescription, details: nil))
        } else {
          finish(true)
        }
      }
    }
  }

  private static func run(
    _ asset: AVAsset, preset: String, to output: URL, completion: @escaping (Error?) -> Void
  ) {
    guard let session = AVAssetExportSession(asset: asset, presetName: preset) else {
      completion(NSError(domain: "VideoEditChannel", code: 4))
      return
    }
    session.outputURL = output
    session.outputFileType = .mp4
    session.shouldOptimizeForNetworkUse = true
    session.exportAsynchronously {
      switch session.status {
      case .completed:
        completion(nil)
      default:
        completion(session.error ?? NSError(domain: "VideoEditChannel", code: 5))
      }
    }
  }
}
