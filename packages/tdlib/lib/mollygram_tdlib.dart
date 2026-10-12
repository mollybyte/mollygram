/// Binding to TDLib via td_json, plus the td_api types.
///
/// td_api has more than two thousand types, and some names clash with Flutter
/// (`Text`, `Animation`, `Image`, etc.), so import it with a prefix:
///
/// ```dart
/// import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;
/// ```
library;

export 'src/generated/td_api.dart';
export 'src/td.dart';
export 'src/td_events.dart';
export 'src/td_json.dart';
export 'src/td_json_ffi.dart';
export 'src/td_object.dart' show TdDecodeException, TdFunction, TdObject;
