import 'package:mollygram_core/mollygram_core.dart';
import 'package:mollygram_tdlib/mollygram_tdlib.dart' as td;

import 'tdlib_desktop_configuration.dart';

typedef TdlibStarter = Future<td.Td> Function(String? libraryPath);
typedef TdlibParameterLoader = Future<TdlibParameters> Function(
  TelegramApiConfig api,
);

/// Desktop entry point for the TDLib session.
///
/// `TDJSON_PATH` is optional: bundled desktop releases can use the platform
/// loader, while development builds may point to a locally built library.
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
    final tdlib = await _startTdlib(_libraryPath.isEmpty ? null : _libraryPath);
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

  static Future<td.Td> _defaultStartTdlib(String? libraryPath) =>
      td.Td.start(libraryPath: libraryPath);
}
