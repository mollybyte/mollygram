import 'dart:math' as math;
import 'dart:typed_data';

/// How many bars Telegram clients put in a voice message waveform.
const voiceWaveformBars = 100;

/// Packs peaks (0 to 1, one per 20 ms) into Telegram's waveform: [bars]
/// 5-bit values, little-endian, scaled so the loudest bar is 31.
Uint8List packWaveform(List<double> peaks, {int bars = voiceWaveformBars}) {
  final values = List<int>.filled(bars, 0);
  if (peaks.isNotEmpty) {
    // Each bar takes the loudest peak of its slice, as tdesktop does.
    final buckets = List<double>.filled(bars, 0);
    for (var i = 0; i < peaks.length; i++) {
      final b = math.min(bars - 1, i * bars ~/ peaks.length);
      buckets[b] = math.max(buckets[b], peaks[i]);
    }
    // Short recordings have fewer peaks than bars; fill the gaps.
    for (var b = 1; b < bars; b++) {
      if (buckets[b] == 0 && peaks.length < bars) {
        buckets[b] = buckets[b - 1];
      }
    }
    final loudest = buckets.reduce(math.max);
    if (loudest > 0) {
      for (var b = 0; b < bars; b++) {
        values[b] = (buckets[b] / loudest * 31).round().clamp(0, 31);
      }
    }
  }
  final out = Uint8List((bars * 5 + 7) ~/ 8);
  for (var i = 0; i < bars; i++) {
    final bit = i * 5;
    final byte = bit >> 3;
    final shift = bit & 7;
    final v = values[i] << shift;
    out[byte] |= v & 0xFF;
    if (byte + 1 < out.length) out[byte + 1] |= v >> 8;
  }
  return out;
}

/// Unpacks Telegram's waveform: 5-bit values packed little-endian.
List<int> unpackWaveform(Uint8List data) {
  final count = data.length * 8 ~/ 5;
  return [
    for (var i = 0; i < count; i++)
      () {
        final bit = i * 5;
        final byte = bit >> 3;
        final shift = bit & 7;
        final low = data[byte];
        final high = byte + 1 < data.length ? data[byte + 1] : 0;
        return ((low | (high << 8)) >> shift) & 31;
      }(),
  ];
}

/// A peak (0 to 1) as a bar height (0 to 1) on a 50 dB scale, the way the
/// ear hears loudness, for live meters.
double meterLevel(double peak) {
  if (peak <= 0) return 0;
  final db = 20 * math.log(peak) / math.ln10;
  return ((db + 50) / 50).clamp(0.0, 1.0);
}
