import 'dart:io';

import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;

import 'tdlib_desktop_configuration.dart';

typedef TdlibStarter = Future<td.Td> Function(String? libraryPath);
typedef TdlibParameterLoader = Future<TdlibParameters> Function(
  TelegramApiConfig api,
);

/// Desktop entry point for the TDLib session.
///
/// The macOS app carries libtdjson in Contents/Frameworks (see
/// macos/scripts/bundle_tdjson.sh). `--dart-define=TDJSON_PATH=...` points to
/// another build of the library.
final class TelegramSessionLauncher {
  TelegramSessionLauncher({
    TdlibStarter? startTdlib,
    TdlibParameterLoader? loadParameters,
  }) : _startTdlib = startTdlib ?? _defaultStartTdlib,
       _loadParameters = loadParameters ?? TdlibDesktopConfiguration().load;

  static const _libraryPath = String.fromEnvironment('TDJSON_PATH');

  final TdlibStarter _startTdlib;
  final TdlibParameterLoader _loadParameters;

  Future<TelegramSession> start(TelegramApiConfig api) async {
    if (!api.isConfigured) {
      throw StateError('Telegram API credentials have not been configured.');
    }
    final tdlib = await _startTdlib(libraryPath);
    try {
      return await TelegramSession.attach(
        tdlib,
        parameters: await _loadParameters(api),
      );
    } catch (_) {
      await tdlib.close();
      rethrow;
    }
  }

  /// dlopen does not search the app bundle for a bare file name, so the
  /// bundled copy is named by its path.
  static String? get libraryPath {
    if (_libraryPath.isNotEmpty) return _libraryPath;
    if (Platform.isMacOS) {
      return '@executable_path/../Frameworks/libtdjson.dylib';
    }
    return null;
  }

  static Future<td.Td> _defaultStartTdlib(String? libraryPath) =>
      td.Td.start(libraryPath: libraryPath);
}
