import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mollygram_media/mollygram_media.dart';

/// Reads the pages of an Ogg file back.
List<({int flags, int granule, int sequence, List<Uint8List> packets})>
readPages(Uint8List data) {
  final pages =
      <({int flags, int granule, int sequence, List<Uint8List> packets})>[];
  var at = 0;
  while (at < data.length) {
    final view = ByteData.sublistView(data, at);
    expect(String.fromCharCodes(data.sublist(at, at + 4)), 'OggS');
    final count = data[at + 26];
    final lacing = data.sublist(at + 27, at + 27 + count);
    final size = lacing.fold<int>(0, (a, b) => a + b);
    final length = 27 + count + size;
    final page = Uint8List.fromList(data.sublist(at, at + length));
    final crc = view.getUint32(22, Endian.little);
    page.fillRange(22, 26, 0);
    expect(oggCrc(page), crc, reason: 'page checksum');
    final packets = <Uint8List>[];
    var body = at + 27 + count;
    final current = BytesBuilder();
    for (final l in lacing) {
      current.add(data.sublist(body, body + l));
      body += l;
      if (l < 255) packets.add(current.takeBytes());
    }
    pages.add((
      flags: data[at + 5],
      granule: view.getUint64(6, Endian.little),
      sequence: view.getUint32(18, Endian.little),
      packets: packets,
    ));
    at += length;
  }
  return pages;
}

class FakeCapture implements OpusCapture {
  void Function(OpusBatch batch)? onData;
  bool cancelled = false;
  int samples = 0;
  List<OpusBatch> tail = [];

  @override
  Future<MicrophonePermission> permission() async =>
      MicrophonePermission.granted;

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<int> start(void Function(OpusBatch batch) onData) async {
    this.onData = onData;
    return 312;
  }

  @override
  Future<int> stop() async {
    tail.forEach(onData!);
    return samples;
  }

  @override
  Future<void> cancel() async => cancelled = true;
}

void main() {
  test(
    'Ogg checksum matches CRC-32 with polynomial 04C11DB7 and zero init',
    () {
      expect(oggCrc(Uint8List.fromList('123456789'.codeUnits)), 0x89A1897F);
    },
  );

  test('writes header pages and audio pages that read back', () async {
    final dir = await Directory.systemTemp.createTemp('ogg');
    addTearDown(() => dir.delete(recursive: true));
    final path = '${dir.path}/a.ogg';
    final writer = await OggOpusWriter.open(path, preSkip: 312, serial: 7);
    final packets = [
      for (var i = 0; i < 120; i++)
        Uint8List.fromList(List.filled(i == 3 ? 600 : 40 + i % 7, i & 0xFF)),
    ];
    packets.forEach(writer.add);
    await writer.close(inputSamples: 119 * 960 + 100);

    final pages = readPages(await File(path).readAsBytes());
    expect(pages.first.flags, 0x02);
    final head = pages[0].packets.single;
    expect(String.fromCharCodes(head.sublist(0, 8)), 'OpusHead');
    expect(head[9], 1);
    expect(ByteData.sublistView(head).getUint16(10, Endian.little), 312);
    expect(
      String.fromCharCodes(pages[1].packets.single.sublist(0, 8)),
      'OpusTags',
    );
    expect(
      [for (final p in pages) p.sequence],
      [for (var i = 0; i < pages.length; i++) i],
    );

    final audio = pages.skip(2).toList();
    expect([for (final p in audio) ...p.packets], packets);
    expect(audio.last.flags, 0x04);
    expect(audio.last.granule, 312 + 119 * 960 + 100);
    // Every full page ends on a whole second.
    expect(audio.first.granule, 50 * 960);
  });

  test('pages never take more than 255 lacing values', () async {
    final dir = await Directory.systemTemp.createTemp('ogg');
    addTearDown(() => dir.delete(recursive: true));
    final path = '${dir.path}/b.ogg';
    final writer = await OggOpusWriter.open(path);
    final packets = [for (var i = 0; i < 60; i++) Uint8List(1275)];
    packets.forEach(writer.add);
    await writer.close();
    final pages = readPages(await File(path).readAsBytes());
    expect([for (final p in pages.skip(2)) ...p.packets].length, 60);
  });

  test('waveform packs to 100 five-bit bars scaled to the loudest', () {
    final peaks = [for (var i = 0; i < 400; i++) i < 200 ? 0.25 : 0.5];
    final packed = packWaveform(peaks);
    expect(packed.length, 63);
    final bars = unpackWaveform(packed).take(100).toList();
    expect(bars.first, 16);
    expect(bars.last, 31);
    expect(packWaveform(const []), Uint8List(63));
  });

  test('a short recording still fills every bar', () {
    final bars = unpackWaveform(packWaveform([0.5, 1, 0.5])).take(100);
    expect(bars.where((b) => b == 0), isEmpty);
  });

  test('meter level is a 50 dB scale', () {
    expect(meterLevel(1), 1);
    expect(meterLevel(0), 0);
    expect(meterLevel(0.001), 0);
    expect(meterLevel(0.0316), closeTo(0.4, 0.01));
  });

  test('recorder writes the file and keeps batches from the stop', () async {
    final dir = await Directory.systemTemp.createTemp('voice');
    addTearDown(() => dir.delete(recursive: true));
    final capture = FakeCapture();
    final recorder = VoiceRecorder(
      directory: () async => dir.path,
      capture: capture,
    );
    await recorder.start();
    capture.onData!((
      packets: [Uint8List(30), Uint8List(30)],
      peaks: [0.1, 0.9],
    ));
    capture.tail = [
      (packets: [Uint8List(30)], peaks: [0.5]),
    ];
    capture.samples = 3 * 960 - 200;
    expect(recorder.captured, const Duration(milliseconds: 40));
    final voice = await recorder.stop();
    expect(
      voice.duration,
      const Duration(milliseconds: (3 * 960 - 200) * 1000 ~/ 48000),
    );
    final bars = unpackWaveform(voice.waveform);
    expect([bars[0], bars[33], bars[66]], [3, 31, 17]);
    final pages = readPages(await File(voice.path).readAsBytes());
    expect([for (final p in pages.skip(2)) ...p.packets].length, 3);
    expect(recorder.isRecording, isFalse);
  });

  test('cancel deletes the file', () async {
    final dir = await Directory.systemTemp.createTemp('voice');
    addTearDown(() => dir.delete(recursive: true));
    final capture = FakeCapture();
    final recorder = VoiceRecorder(
      directory: () async => dir.path,
      capture: capture,
    );
    await recorder.start();
    capture.onData!((packets: [Uint8List(30)], peaks: [0.1]));
    await recorder.cancel();
    expect(capture.cancelled, isTrue);
    expect(dir.listSync(), isEmpty);
  });
}
