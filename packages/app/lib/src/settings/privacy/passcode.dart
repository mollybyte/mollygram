import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// PBKDF2 with HMAC-SHA256 (RFC 8018), one 32-byte block.
@visibleForTesting
Uint8List pbkdf2(List<int> password, List<int> salt, int iterations) {
  final hmac = Hmac(sha256, password);
  var block = hmac.convert([...salt, 0, 0, 0, 1]).bytes;
  final result = Uint8List.fromList(block);
  for (var i = 1; i < iterations; i++) {
    block = hmac.convert(block).bytes;
    for (var j = 0; j < result.length; j++) {
      result[j] ^= block[j];
    }
  }
  return result;
}

/// A passcode as it is kept: never the passcode, only a salted PBKDF2
/// hash of it.
@immutable
final class PasscodeHash {
  const PasscodeHash({
    required this.salt,
    required this.hash,
    required this.iterations,
  });

  /// Enough rounds to make guessing slow, quick enough not to show.
  /// Tests lower it.
  @visibleForTesting
  static var defaultIterations = 120000;

  /// Hashes [passcode] with a fresh random salt, off the UI isolate.
  static Future<PasscodeHash> create(String passcode, {int? iterations}) async {
    final rounds = iterations ?? defaultIterations;
    final random = Random.secure();
    final salt = Uint8List.fromList([
      for (var i = 0; i < 16; i++) random.nextInt(256),
    ]);
    final hash = await Isolate.run(
      () => pbkdf2(utf8.encode(passcode), salt, rounds),
    );
    return PasscodeHash(salt: salt, hash: hash, iterations: rounds);
  }

  factory PasscodeHash.fromJson(Map<String, Object?> json) => PasscodeHash(
    salt: base64.decode(json['salt']! as String),
    hash: base64.decode(json['hash']! as String),
    iterations: json['iterations']! as int,
  );

  final Uint8List salt;
  final Uint8List hash;
  final int iterations;

  /// Whether [passcode] is the one hashed; compares in constant time.
  Future<bool> verify(String passcode) async {
    final salt = this.salt;
    final iterations = this.iterations;
    final candidate = await Isolate.run(
      () => pbkdf2(utf8.encode(passcode), salt, iterations),
    );
    if (candidate.length != hash.length) return false;
    var diff = 0;
    for (var i = 0; i < hash.length; i++) {
      diff |= candidate[i] ^ hash[i];
    }
    return diff == 0;
  }

  Map<String, Object?> toJson() => {
    'salt': base64.encode(salt),
    'hash': base64.encode(hash),
    'iterations': iterations,
  };
}

/// The local passcode lock as saved: the hash, or null when it is off,
/// and how long the user may be away before the window locks.
@immutable
final class PasscodeSettings {
  const PasscodeSettings({this.hash, this.autoLockMinutes = 60});

  /// Reads what [toJson] wrote; null is no entry. Anything else that
  /// can't be read throws a [FormatException], so a damaged entry is never
  /// taken for "no passcode".
  factory PasscodeSettings.fromJson(Object? json) {
    if (json == null) return const PasscodeSettings();
    if (json is! Map<String, Object?>) {
      throw const FormatException('Passcode settings are not a map');
    }
    try {
      final hash = json['hash'];
      final minutes = json['autoLockMinutes'];
      return PasscodeSettings(
        hash: hash == null
            ? null
            : PasscodeHash.fromJson(hash as Map<String, Object?>),
        autoLockMinutes: autoLockChoices.contains(minutes)
            ? minutes! as int
            : 60,
      );
    } on Object catch (error) {
      throw FormatException('Damaged passcode settings: $error');
    }
  }

  /// The away times the settings offer, in minutes.
  static const autoLockChoices = [1, 5, 15, 60];

  final PasscodeHash? hash;
  final int autoLockMinutes;

  bool get enabled => hash != null;

  Map<String, Object?> toJson() => {
    if (hash != null) 'hash': hash!.toJson(),
    'autoLockMinutes': autoLockMinutes,
  };
}

/// Where the passcode settings live.
abstract interface class PasscodeStorage {
  Future<Object?> read();
  Future<void> write(Object? json);
}

/// The macOS keychain, through the same storage as the database key.
final class KeychainPasscodeStorage implements PasscodeStorage {
  KeychainPasscodeStorage({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            mOptions: MacOsOptions(usesDataProtectionKeychain: false),
          );

  static const _key = 'mollygram.passcode';
  final FlutterSecureStorage _storage;

  @override
  Future<Object?> read() async {
    final text = await _storage.read(key: _key);
    // A damaged entry throws, so it isn't taken for "no passcode".
    return text == null ? null : jsonDecode(text);
  }

  @override
  Future<void> write(Object? json) => json == null
      ? _storage.delete(key: _key)
      : _storage.write(key: _key, value: jsonEncode(json));
}

/// Keeps the settings in memory, for tests.
final class MemoryPasscodeStorage implements PasscodeStorage {
  MemoryPasscodeStorage([this.saved]);

  Object? saved;

  @override
  Future<Object?> read() async => saved;

  @override
  Future<void> write(Object? json) async => saved = json;
}

final passcodeStorageProvider = Provider<PasscodeStorage>(
  (ref) => KeychainPasscodeStorage(),
);

/// The time, replaceable in tests.
final passcodeClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

/// The lock as the window shows it.
@immutable
final class PasscodeState {
  const PasscodeState({
    this.settings = const PasscodeSettings(),
    this.loaded = false,
    this.locked = false,
    this.unreadable = false,
    this.failedAttempts = 0,
    this.retryAt,
  });

  final PasscodeSettings settings;

  /// Whether the keychain has been read; until then nothing is shown.
  final bool loaded;
  final bool locked;

  /// The keychain entry couldn't be read: the window stays locked and
  /// nothing is written over the entry.
  final bool unreadable;

  /// Wrong passcodes in a row.
  final int failedAttempts;

  /// After too many wrong passcodes, when the next try is taken.
  final DateTime? retryAt;

  PasscodeState copyWith({
    PasscodeSettings? settings,
    bool? loaded,
    bool? locked,
    bool? unreadable,
    int? failedAttempts,
    DateTime? Function()? retryAt,
  }) => PasscodeState(
    settings: settings ?? this.settings,
    loaded: loaded ?? this.loaded,
    locked: locked ?? this.locked,
    unreadable: unreadable ?? this.unreadable,
    failedAttempts: failedAttempts ?? this.failedAttempts,
    retryAt: retryAt == null ? this.retryAt : retryAt(),
  );
}

/// The passcode lock, after TelegramSwift's PasscodeSettings: locked at
/// launch when a passcode is set, locked after [PasscodeSettings
/// .autoLockMinutes] without a click or a key, and on ⌘L.
final class PasscodeLock extends Notifier<PasscodeState> {
  late DateTime _lastActivity;
  Timer? _timer;

  /// How often the away time is checked.
  static const checkEvery = Duration(seconds: 10);

  PasscodeStorage get _storage => ref.read(passcodeStorageProvider);
  DateTime _now() => ref.read(passcodeClockProvider)();

  @override
  PasscodeState build() {
    _lastActivity = _now();
    ref.onDispose(() => _timer?.cancel());
    unawaited(_load());
    return const PasscodeState();
  }

  Future<void> _load() async {
    final PasscodeSettings settings;
    try {
      settings = PasscodeSettings.fromJson(await _storage.read());
    } on Object {
      // Fail closed: an entry that can't be read may hold a passcode.
      state = const PasscodeState(loaded: true, locked: true, unreadable: true);
      return;
    }
    state = PasscodeState(
      settings: settings,
      loaded: true,
      locked: settings.enabled,
    );
    _watch();
  }

  /// Reads the keychain again, after it couldn't be read.
  Future<void> retryRead() async {
    if (!state.unreadable) return;
    await _load();
  }

  /// The away time is checked only while there is a passcode.
  void _watch() {
    if (!state.settings.enabled) {
      _timer?.cancel();
      _timer = null;
    } else {
      _timer ??= Timer.periodic(checkEvery, (_) => check());
    }
  }

  /// A click or a key: the away time starts again.
  void activity() => _lastActivity = _now();

  /// Locks the window when the user has been away long enough.
  void check() {
    final settings = state.settings;
    if (!settings.enabled || state.locked) return;
    final away = _now().difference(_lastActivity);
    if (away >= Duration(minutes: settings.autoLockMinutes)) lock();
  }

  void lock() {
    if (state.settings.enabled) state = state.copyWith(locked: true);
  }

  /// Wrong passcodes taken before tries are spaced out.
  static const freeAttempts = 5;

  /// How long to wait after [failures] wrong passcodes in a row: nothing
  /// for the first [freeAttempts], then 30 seconds, doubling each time up
  /// to an hour.
  static Duration delayAfter(int failures) {
    if (failures < freeAttempts) return Duration.zero;
    final seconds = 30 * pow(2, failures - freeAttempts);
    return Duration(seconds: min(seconds.toInt(), 3600));
  }

  /// Tries [passcode]. While a wait after wrong passcodes runs, nothing
  /// is checked.
  Future<UnlockResult> unlock(String passcode) async {
    final hash = state.settings.hash;
    if (state.unreadable) return UnlockResult.wrong;
    if (hash == null) return UnlockResult.unlocked;
    final retryAt = state.retryAt;
    if (retryAt != null && _now().isBefore(retryAt)) return UnlockResult.wait;
    if (!await hash.verify(passcode)) {
      final failures = state.failedAttempts + 1;
      final delay = delayAfter(failures);
      state = state.copyWith(
        failedAttempts: failures,
        retryAt: () => delay == Duration.zero ? null : _now().add(delay),
      );
      return UnlockResult.wrong;
    }
    activity();
    state = state.copyWith(
      locked: false,
      failedAttempts: 0,
      retryAt: () => null,
    );
    return UnlockResult.unlocked;
  }

  /// Whether [passcode] is the current one, without unlocking.
  Future<bool> verify(String passcode) async =>
      await state.settings.hash?.verify(passcode) ?? false;

  /// Turns the lock on, or changes the passcode.
  Future<void> setPasscode(String passcode, {int? iterations}) async {
    final hash = await PasscodeHash.create(passcode, iterations: iterations);
    await _save(
      PasscodeSettings(
        hash: hash,
        autoLockMinutes: state.settings.autoLockMinutes,
      ),
    );
    activity();
  }

  /// Removes the passcode; the auto-lock choice stays for next time.
  Future<void> turnOff() =>
      _save(PasscodeSettings(autoLockMinutes: state.settings.autoLockMinutes));

  Future<void> setAutoLock(int minutes) => _save(
    PasscodeSettings(hash: state.settings.hash, autoLockMinutes: minutes),
  );

  /// After logging out because the passcode was forgotten: removes it,
  /// even when the entry couldn't be read, and unlocks.
  Future<void> forget() async {
    final settings = PasscodeSettings(
      autoLockMinutes: state.settings.autoLockMinutes,
    );
    await _storage.write(settings.toJson());
    state = PasscodeState(settings: settings, loaded: true);
    _watch();
  }

  /// Writes [settings], then shows them; a failed write throws and
  /// changes nothing. An entry that couldn't be read is never written.
  Future<void> _save(PasscodeSettings settings) async {
    if (state.unreadable) {
      throw StateError('The passcode entry could not be read');
    }
    await _storage.write(settings.toJson());
    state = state.copyWith(
      settings: settings,
      locked: state.locked && settings.enabled,
    );
    _watch();
  }
}

enum UnlockResult { unlocked, wrong, wait }

final passcodeLockProvider = NotifierProvider<PasscodeLock, PasscodeState>(
  PasscodeLock.new,
);
