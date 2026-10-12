/// Привязка к TDLib через td_json и типы td_api.
///
/// Типов в td_api больше двух тысяч, и часть имён совпадает с Flutter
/// (`Text`, `Animation`, `Image` и т.д.), поэтому импортируйте с префиксом:
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
