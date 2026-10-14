import 'package:flutter_test/flutter_test.dart';
import 'package:mollygram/src/session/telegram_session_launcher.dart';
import 'package:mollygram_core/mollygram_core.dart';

void main() {
  test('does not open TDLib without API credentials', () async {
    var opened = false;
    final launcher = TelegramSessionLauncher(
      startTdlib: (_) async {
        opened = true;
        throw UnimplementedError();
      },
    );

    await expectLater(
      launcher.start(const TelegramApiConfig(apiId: 0, apiHash: '')),
      throwsStateError,
    );
    expect(opened, isFalse);
  });

  group('bundledLibraryPath', () {
    String? resolve(
      String operatingSystem,
      String executable, {
      bool exists = true,
      List<String>? checked,
    }) => TelegramSessionLauncher.bundledLibraryPath(
      operatingSystem: operatingSystem,
      executable: executable,
      exists: (path) {
        checked?.add(path);
        return exists;
      },
    );

    test('Windows uses tdjson.dll next to the executable', () {
      expect(
        resolve('windows', r'C:\Program Files\Mollygram\mollygram.exe'),
        r'C:\Program Files\Mollygram\tdjson.dll',
      );
    });

    test('Linux uses lib/libtdjson.so in the bundle', () {
      expect(
        resolve('linux', '/opt/mollygram/mollygram'),
        '/opt/mollygram/lib/libtdjson.so',
      );
    });

    test('falls back to the system library when nothing is bundled', () {
      final checked = <String>[];
      expect(
        resolve(
          'windows',
          r'D:\src\build\runner\Debug\mollygram.exe',
          exists: false,
          checked: checked,
        ),
        isNull,
      );
      expect(
        resolve(
          'linux',
          '/home/dev/build/bundle/mollygram',
          exists: false,
          checked: checked,
        ),
        isNull,
      );
      expect(checked, [
        r'D:\src\build\runner\Debug\tdjson.dll',
        '/home/dev/build/bundle/lib/libtdjson.so',
      ]);
    });

    test('macOS keeps the copy in Contents/Frameworks', () {
      expect(
        resolve(
          'macos',
          '/Applications/Mollygram.app/Contents/MacOS/Mollygram',
          exists: false,
        ),
        '@executable_path/../Frameworks/libtdjson.dylib',
      );
    });

    test('other platforms use the system library', () {
      expect(resolve('android', '/system/bin/app_process'), isNull);
    });
  });
}
