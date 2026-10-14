import 'dart:io';

import 'package:flutter/foundation.dart';
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
/// macos/scripts/bundle_tdjson.sh). Release builds for Windows and Linux carry
/// it next to the executable (tdjson.dll) and in lib/ (libtdjson.so), placed
/// there by .github/workflows/release.yml. `--dart-define=TDJSON_PATH=...`
/// points to another build of the library.
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
    return bundledLibraryPath(
      operatingSystem: Platform.operatingSystem,
      executable: Platform.resolvedExecutable,
      exists: (path) => File(path).existsSync(),
    );
  }

  /// Where the release bundle keeps libtdjson for [operatingSystem], given the
  /// app's [executable]. On Windows and Linux a build without the bundled
  /// library (`flutter run`) returns null, so the system copy is used.
  @visibleForTesting
  static String? bundledLibraryPath({
    required String operatingSystem,
    required String executable,
    required bool Function(String path) exists,
  }) {
    final String path;
    switch (operatingSystem) {
      case 'macos':
        return '@executable_path/../Frameworks/libtdjson.dylib';
      case 'windows':
        final end = executable.lastIndexOf(RegExp(r'[\\/]'));
        path = '${end < 0 ? '.' : executable.substring(0, end)}\\tdjson.dll';
      case 'linux':
        final end = executable.lastIndexOf('/');
        path =
            '${end < 0 ? '.' : executable.substring(0, end)}/lib/libtdjson.so';
      default:
        return null;
    }
    return exists(path) ? path : null;
  }

  static Future<td.Td> _defaultStartTdlib(String? libraryPath) =>
      td.Td.start(libraryPath: libraryPath);
}
