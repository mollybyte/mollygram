import 'dart:io';
import 'dart:typed_data';

/// Writes Opus packets into an Ogg file (RFC 7845), the container Telegram
/// expects for voice messages.
///
/// The encoder runs elsewhere (natively); this side only frames its packets.
/// Pages are flushed to disk about once a second, so a long recording never
/// sits in memory.
class OggOpusWriter {
  OggOpusWriter._(this._sink, this.preSkip, this._serial);

  /// Opens [path] for writing and writes the two header pages.
  ///
  /// [preSkip] is the encoder's lookahead in 48 kHz samples; players drop
  /// that many samples from the start.
  static Future<OggOpusWriter> open(
    String path, {
    int preSkip = 312,
    int inputSampleRate = 48000,
    String vendor = 'Mollygram',
    int? serial,
  }) async {
    final file = File(path);
    await file.parent.create(recursive: true);
    final writer = OggOpusWriter._(
      file.openWrite(),
      preSkip,
      serial ?? DateTime.now().microsecondsSinceEpoch & 0x7FFFFFFF,
    );
    writer
      .._writePage(
        [opusHead(preSkip: preSkip, inputSampleRate: inputSampleRate)],
        granule: 0,
        flags: _beginOfStream,
      )
      .._writePage([opusTags(vendor)], granule: 0, flags: 0);
    return writer;
  }

  static const _beginOfStream = 0x02;
  static const _endOfStream = 0x04;

  /// Opus in Telegram is always 48 kHz; one 20 ms packet is 960 samples.
  static const samplesPerPacket = 960;

  /// A page ends after one second of audio, or earlier when its 255
  /// lacing values run out.
  static const _packetsPerPage = 50;

  final IOSink _sink;
  final int preSkip;
  final int _serial;
  int _sequence = 0;
  int _packets = 0;
  bool _closed = false;
  final List<Uint8List> _page = [];
  int _segments = 0;

  /// Packets written so far.
  int get packetCount => _packets;

  /// Adds one encoded Opus packet of [samplesPerPacket] samples.
  void add(Uint8List packet) {
    if (_closed) throw StateError('The writer is closed.');
    if (packet.length > 255 * 254) {
      throw ArgumentError.value(packet.length, 'packet', 'Too large.');
    }
    final segments = packet.length ~/ 255 + 1;
    if (_page.isNotEmpty && _segments + segments > 255) _flush();
    _page.add(packet);
    _segments += segments;
    _packets++;
    if (_page.length >= _packetsPerPage) _flush();
  }

  void _flush() {
    _writePage(_page, granule: _packets * samplesPerPacket, flags: 0);
    _page.clear();
    _segments = 0;
  }

  /// Writes the last page and closes the file.
  ///
  /// [inputSamples] is how many samples were fed to the encoder; the last
  /// page's granule position then trims the padding of the final packet.
  Future<void> close({int? inputSamples}) async {
    if (_closed) return;
    _closed = true;
    var granule = _packets * samplesPerPacket;
    if (inputSamples != null && preSkip + inputSamples < granule) {
      granule = preSkip + inputSamples;
    }
    _writePage(_page, granule: granule, flags: _endOfStream);
    _page.clear();
    await _sink.flush();
    await _sink.close();
  }

  void _writePage(
    List<Uint8List> packets, {
    required int granule,
    required int flags,
  }) {
    final lacing = <int>[];
    var bodyLength = 0;
    for (final p in packets) {
      var left = p.length;
      while (left >= 255) {
        lacing.add(255);
        left -= 255;
      }
      lacing.add(left);
      bodyLength += p.length;
    }
    final header = 27 + lacing.length;
    final page = Uint8List(header + bodyLength);
    final view = ByteData.sublistView(page);
    page.setAll(0, 'OggS'.codeUnits);
    page[4] = 0; // version
    page[5] = flags;
    view.setUint64(6, granule, Endian.little);
    view.setUint32(14, _serial, Endian.little);
    view.setUint32(18, _sequence++, Endian.little);
    // 22..25: checksum, filled in below.
    page[26] = lacing.length;
    page.setAll(27, lacing);
    var offset = header;
    for (final p in packets) {
      page.setAll(offset, p);
      offset += p.length;
    }
    view.setUint32(22, oggCrc(page), Endian.little);
    _sink.add(page);
  }

  /// The identification header.
  static Uint8List opusHead({
    required int preSkip,
    int inputSampleRate = 48000,
    int channels = 1,
  }) {
    final head = Uint8List(19);
    final view = ByteData.sublistView(head);
    head.setAll(0, 'OpusHead'.codeUnits);
    head[8] = 1; // version
    head[9] = channels;
    view.setUint16(10, preSkip, Endian.little);
    view.setUint32(12, inputSampleRate, Endian.little);
    view.setInt16(16, 0, Endian.little); // output gain
    head[18] = 0; // mapping family: mono or stereo
    return head;
  }

  /// The comment header: vendor and no comments.
  static Uint8List opusTags(String vendor) {
    final name = vendor.codeUnits;
    final tags = Uint8List(8 + 4 + name.length + 4);
    final view = ByteData.sublistView(tags);
    tags.setAll(0, 'OpusTags'.codeUnits);
    view.setUint32(8, name.length, Endian.little);
    tags.setAll(12, name);
    view.setUint32(12 + name.length, 0, Endian.little);
    return tags;
  }
}

final Uint32List _crcTable = () {
  final table = Uint32List(256);
  for (var i = 0; i < 256; i++) {
    var r = i << 24;
    for (var j = 0; j < 8; j++) {
      r = (r & 0x80000000) != 0 ? ((r << 1) ^ 0x04C11DB7) : (r << 1);
      r &= 0xFFFFFFFF;
    }
    table[i] = r;
  }
  return table;
}();

/// The Ogg page checksum: CRC-32 with polynomial 0x04C11DB7, no reflection,
/// initial value 0, over the page with its checksum field zeroed.
int oggCrc(Uint8List data) {
  var crc = 0;
  for (final byte in data) {
    crc = ((crc << 8) & 0xFFFFFFFF) ^ _crcTable[((crc >> 24) & 0xFF) ^ byte];
  }
  return crc;
}
