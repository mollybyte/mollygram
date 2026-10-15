import AVFoundation
import FlutterMacOS

/// Microphone capture for voice messages, driven from Dart over the
/// `mollygram/voice_capture` channel (VoiceRecorder in packages/media).
///
/// AVAudioEngine taps the default input; each buffer is resampled to 48 kHz
/// mono and encoded to 20 ms Opus packets with AudioToolbox. The packets
/// and a peak per packet go to Dart in batches, and Dart writes the Ogg
/// file Telegram expects. All encoding happens on one serial queue, so a
/// stop delivers every packet of the recording before it completes.
final class VoiceCaptureChannel {
  private let channel: FlutterMethodChannel
  private let queue = DispatchQueue(label: "dev.mollygram.voice-capture", qos: .userInitiated)
  private var engine: AVAudioEngine?
  /// Touched only on [queue].
  private var encoder: OpusEncoderSession?

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "mollygram/voice_capture", binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "permission":
      switch AVCaptureDevice.authorizationStatus(for: .audio) {
      case .authorized: result("granted")
      case .notDetermined: result("undetermined")
      default: result("denied")
      }
    case "requestPermission":
      AVCaptureDevice.requestAccess(for: .audio) { granted in
        DispatchQueue.main.async { result(granted) }
      }
    case "start":
      start(result)
    case "stop":
      finish(send: true, result)
    case "cancel":
      finish(send: false, result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func start(_ result: @escaping FlutterResult) {
    if engine != nil {
      result(FlutterError(code: "busy", message: "Already recording.", details: nil))
      return
    }
    let engine = AVAudioEngine()
    let input = engine.inputNode
    let format = input.outputFormat(forBus: 0)
    guard format.sampleRate > 0, format.channelCount > 0,
      let session = OpusEncoderSession(inputFormat: format)
    else {
      result(FlutterError(code: "unavailable", message: "No microphone.", details: nil))
      return
    }
    queue.sync { encoder = session }
    input.installTap(onBus: 0, bufferSize: 2048, format: format) { [weak self] buffer, _ in
      // The engine reuses the buffer once the block returns.
      guard let self = self, let copy = buffer.copy() as? AVAudioPCMBuffer else { return }
      self.queue.async { self.process(copy) }
    }
    engine.prepare()
    do {
      try engine.start()
    } catch {
      input.removeTap(onBus: 0)
      queue.sync { encoder = nil }
      result(FlutterError(code: "unavailable", message: error.localizedDescription, details: nil))
      return
    }
    self.engine = engine
    result(["preSkip": session.preSkip])
  }

  private func process(_ buffer: AVAudioPCMBuffer) {
    guard let encoder = encoder else { return }
    encoder.append(buffer)
    deliver(encoder.encode(final: false), peaks: encoder.takePeaks())
  }

  private func finish(send: Bool, _ result: @escaping FlutterResult) {
    if let engine = engine {
      engine.inputNode.removeTap(onBus: 0)
      engine.stop()
      self.engine = nil
    }
    queue.async { [weak self] in
      guard let self = self else { return }
      guard let encoder = self.encoder else {
        DispatchQueue.main.async { result(["samples": 0]) }
        return
      }
      self.encoder = nil
      if send {
        self.deliver(encoder.encode(final: true), peaks: encoder.takePeaks())
      }
      let samples = encoder.inputSamples
      DispatchQueue.main.async { result(["samples": samples]) }
    }
  }

  /// Called on [queue]; hops to the main thread, where Flutter channels live.
  private func deliver(_ packets: [Data], peaks: [Double]) {
    if packets.isEmpty && peaks.isEmpty { return }
    let message: [String: Any] = [
      "packets": packets.map { FlutterStandardTypedData(bytes: $0) },
      "peaks": peaks,
    ]
    DispatchQueue.main.async { [weak self] in
      self?.channel.invokeMethod("data", arguments: message)
    }
  }
}

/// Resamples to 48 kHz mono and encodes 20 ms Opus packets.
private final class OpusEncoderSession {
  static let sampleRate = 48000.0
  static let packetFrames = 960

  let pcmFormat: AVAudioFormat
  let opusFormat: AVAudioFormat
  let resampler: AVAudioConverter
  let encoder: AVAudioConverter
  /// The encoder's lookahead, written into the Ogg header.
  let preSkip: Int
  /// Samples at 48 kHz fed to the encoder so far.
  private(set) var inputSamples = 0

  private var fifo: [Float] = []
  private var peaks: [Double] = []
  private var peak: Float = 0
  private var peakFrames = 0

  init?(inputFormat: AVAudioFormat) {
    var description = AudioStreamBasicDescription(
      mSampleRate: Self.sampleRate,
      mFormatID: kAudioFormatOpus,
      mFormatFlags: 0,
      mBytesPerPacket: 0,
      mFramesPerPacket: UInt32(Self.packetFrames),
      mBytesPerFrame: 0,
      mChannelsPerFrame: 1,
      mBitsPerChannel: 0,
      mReserved: 0)
    guard
      let pcm = AVAudioFormat(
        commonFormat: .pcmFormatFloat32, sampleRate: Self.sampleRate, channels: 1,
        interleaved: false),
      let opus = AVAudioFormat(streamDescription: &description),
      let resampler = AVAudioConverter(from: inputFormat, to: pcm),
      let encoder = AVAudioConverter(from: pcm, to: opus)
    else { return nil }
    resampler.downmix = true
    // Telegram's own apps record voice at about 32 kbit/s.
    if let rates = encoder.applicableEncodeBitRates,
      rates.contains(where: { $0.intValue == 32000 })
    {
      encoder.bitRate = 32000
    }
    pcmFormat = pcm
    opusFormat = opus
    self.resampler = resampler
    self.encoder = encoder
    let leading = Int(encoder.primeInfo.leadingFrames)
    preSkip = leading > 0 ? leading : 312
  }

  func append(_ buffer: AVAudioPCMBuffer) {
    let ratio = Self.sampleRate / buffer.format.sampleRate
    let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 64
    guard let out = AVAudioPCMBuffer(pcmFormat: pcmFormat, frameCapacity: capacity) else { return }
    var supplied = false
    var error: NSError?
    _ = resampler.convert(to: out, error: &error) { _, status in
      if supplied {
        status.pointee = .noDataNow
        return nil
      }
      supplied = true
      status.pointee = .haveData
      return buffer
    }
    guard error == nil, let samples = out.floatChannelData?[0] else { return }
    let count = Int(out.frameLength)
    fifo.append(contentsOf: UnsafeBufferPointer(start: samples, count: count))
    inputSamples += count
    for i in 0..<count {
      peak = max(peak, abs(samples[i]))
      peakFrames += 1
      if peakFrames == Self.packetFrames {
        peaks.append(Double(min(peak, 1)))
        peak = 0
        peakFrames = 0
      }
    }
  }

  func takePeaks() -> [Double] {
    defer { peaks.removeAll(keepingCapacity: true) }
    return peaks
  }

  /// Encodes whole packets from the queue; [final] also encodes the tail,
  /// padded with silence, and drains the encoder.
  func encode(final: Bool) -> [Data] {
    var frames = (fifo.count / Self.packetFrames) * Self.packetFrames
    if final && fifo.count > frames {
      fifo.append(contentsOf: [Float](repeating: 0, count: frames + Self.packetFrames - fifo.count))
      frames = fifo.count
    }
    if frames == 0 && !final { return [] }

    var input: AVAudioPCMBuffer?
    if frames > 0,
      let buffer = AVAudioPCMBuffer(pcmFormat: pcmFormat, frameCapacity: AVAudioFrameCount(frames)),
      let channel = buffer.floatChannelData?[0]
    {
      fifo.withUnsafeBufferPointer { source in
        channel.update(from: source.baseAddress!, count: frames)
      }
      buffer.frameLength = AVAudioFrameCount(frames)
      input = buffer
    }
    fifo.removeFirst(min(frames, fifo.count))

    var packets: [Data] = []
    var supplied = input == nil
    let maxPacket = max(encoder.maximumOutputPacketSize, 1500)
    while true {
      let out = AVAudioCompressedBuffer(
        format: opusFormat,
        packetCapacity: AVAudioPacketCount(frames / Self.packetFrames + 4),
        maximumPacketSize: maxPacket)
      var error: NSError?
      let status = encoder.convert(to: out, error: &error) { _, inputStatus in
        if !supplied, let input = input {
          supplied = true
          inputStatus.pointee = .haveData
          return input
        }
        inputStatus.pointee = final ? .endOfStream : .noDataNow
        return nil
      }
      if let descriptions = out.packetDescriptions {
        for i in 0..<Int(out.packetCount) {
          let d = descriptions[i]
          packets.append(
            Data(bytes: out.data.advanced(by: Int(d.mStartOffset)), count: Int(d.mDataByteSize)))
        }
      }
      // haveData: the output filled up and more may follow.
      if status != .haveData || error != nil || out.packetCount == 0 { break }
    }
    return packets
  }
}
