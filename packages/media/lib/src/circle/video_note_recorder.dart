import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../audio/voice_recorder.dart';
import 'circle_quality.dart';

/// The live camera picture while a video message records.
@immutable
class VideoNotePreview {
  const VideoNotePreview({
    required this.textureId,
    required this.width,
    required this.height,
    this.cameras = 1,
    this.mirrored = true,
  });

  factory VideoNotePreview._from(Map<String, Object?> info) => VideoNotePreview(
    textureId: info['textureId']! as int,
    width: info['width']! as int,
    height: info['height']! as int,
    cameras: info['cameras'] as int? ?? 1,
    mirrored: info['mirrored'] as bool? ?? true,
  );

  /// A Flutter texture with the camera frames, uncropped.
  final int textureId;
  final int width;
  final int height;

  /// How many cameras there are to switch between.
  final int cameras;

  /// Whether the camera faces the user, so the preview shows it as a
  /// mirror.
  final bool mirrored;
}

/// A finished video message, ready to send.
@immutable
class RecordedVideoNote {
  const RecordedVideoNote({
    required this.path,
    required this.duration,
    required this.side,
  });

  /// A square H.264 MP4.
  final String path;
  final Duration duration;
  final int side;
}

/// Records one video message at a time through the
/// `mollygram/video_note_capture` channel
/// (macos/Runner/VideoNoteCaptureChannel.swift): the camera cropped to a
/// square of [quality], with the microphone.
class VideoNoteRecorder {
  VideoNoteRecorder({
    required this.directory,
    this.quality = CircleQuality.standard,
    this.channel = const MethodChannel('mollygram/video_note_capture'),
  });

  /// Where recordings are written.
  final Future<String> Function() directory;
  final CircleQuality quality;
  final MethodChannel channel;

  /// The camera picked last, so the next recording starts with it, in any
  /// chat, until the app quits.
  static String? _camera;

  @visibleForTesting
  static void debugForgetCamera() => _camera = null;

  /// Camera and microphone together.
  Future<MicrophonePermission> permission() async {
    try {
      return switch (await channel.invokeMethod<String>('permission')) {
        'granted' => MicrophonePermission.granted,
        'undetermined' => MicrophonePermission.undetermined,
        _ => MicrophonePermission.denied,
      };
    } on MissingPluginException {
      throw const VoiceRecorderException(VoiceRecorderError.unavailable);
    }
  }

  Future<bool> requestPermission() async =>
      await channel.invokeMethod<bool>('requestPermission') ?? false;

  /// Turns the camera on and starts recording.
  Future<VideoNotePreview> start() async {
    final dir = await directory();
    final path =
        '$dir${Platform.pathSeparator}video_'
        '${DateTime.now().millisecondsSinceEpoch}.mp4';
    try {
      final info = await channel.invokeMapMethod<String, Object?>('start', {
        'side': quality.side,
        'path': path,
        'camera': ?_camera,
      });
      return VideoNotePreview._from(info!);
    } on PlatformException catch (e) {
      throw VoiceRecorderException(VoiceRecorderError.unavailable, e.message);
    } on MissingPluginException {
      throw const VoiceRecorderException(VoiceRecorderError.unavailable);
    }
  }

  /// Goes on recording with the next camera; null when the recording
  /// ended meanwhile.
  Future<VideoNotePreview?> switchCamera() async {
    try {
      final info = await channel.invokeMapMethod<String, Object?>(
        'switchCamera',
      );
      if (info == null) return null;
      _camera = info['camera'] as String?;
      return VideoNotePreview._from(info);
    } on PlatformException {
      return null;
    }
  }

  /// Finishes the file and completes with it.
  Future<RecordedVideoNote> stop() async {
    final info = await channel.invokeMapMethod<String, Object?>('stop');
    final ms = info!['durationMs']! as int;
    return RecordedVideoNote(
      path: info['path']! as String,
      // Telegram's limit, in case the last frames ran over.
      duration: Duration(
        milliseconds: math.min(ms, CircleQuality.maxDuration.inMilliseconds),
      ),
      side: quality.side,
    );
  }

  /// Turns the camera off and deletes the recording.
  Future<void> cancel() => channel.invokeMethod<void>('cancel');
}
