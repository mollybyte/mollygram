import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:mollygram_media_editor/mollygram_media_editor.dart';

void main() {
  const source = Size(400, 300);

  test('identity edit changes nothing', () {
    expect(const MediaEdit().isIdentity, isTrue);
    expect(const MediaEdit().rotatedLeft().isIdentity, isFalse);
  });

  test('four left turns come back to the start', () {
    const start = MediaEdit(crop: Rect.fromLTRB(0.1, 0.2, 0.5, 0.9));
    var edit = start;
    for (var i = 0; i < 4; i++) {
      edit = edit.rotatedLeft();
    }
    expect(edit.quarterTurns, 0);
    expect(edit.crop.left, closeTo(0.1, 1e-9));
    expect(edit.crop.top, closeTo(0.2, 1e-9));
    expect(edit.crop.right, closeTo(0.5, 1e-9));
    expect(edit.crop.bottom, closeTo(0.9, 1e-9));
  });

  test('a left turn swaps the oriented size and moves the crop', () {
    const edit = MediaEdit(crop: Rect.fromLTRB(0, 0, 0.5, 0.5));
    final turned = edit.rotatedLeft();
    expect(turned.quarterTurns, 3);
    expect(turned.orientedSize(source), const Size(300, 400));
    // The top-left quarter ends up bottom-left after a left turn.
    expect(turned.crop, const Rect.fromLTRB(0, 0.5, 0.5, 1));
  });

  test('a mirrored picture turns the other way at the source', () {
    final edit = const MediaEdit().flippedHorizontally().rotatedLeft();
    expect(edit.flipped, isTrue);
    expect(edit.quarterTurns, 1);
  });

  test('flipping twice is the identity', () {
    const edit = MediaEdit(crop: Rect.fromLTRB(0.1, 0.1, 0.4, 0.6));
    final back = edit.flippedHorizontally().flippedHorizontally();
    expect(back.flipped, isFalse);
    expect(back.crop.right, closeTo(0.4, 1e-9));
    expect(edit.flippedHorizontally().crop.left, closeTo(0.6, 1e-9));
  });

  test('an aspect preset fits the largest rectangle around the crop', () {
    final edit = const MediaEdit().withAspect(AspectPreset.square, source);
    final px = edit.cropIn(source);
    expect(px.width, closeTo(300, 1e-9));
    expect(px.height, closeTo(300, 1e-9));
    expect(px.center.dx, closeTo(200, 1e-9));
    expect(edit.ratioFor(source), 1);
  });

  test('presets follow the picture shape and flip with a turn', () {
    final landscape = const MediaEdit().withAspect(
      AspectPreset.ratio16x9,
      source,
    );
    expect(landscape.portrait, isFalse);
    expect(landscape.ratioFor(source), closeTo(16 / 9, 1e-9));
    final turned = landscape.rotatedLeft();
    expect(turned.portrait, isTrue);
    expect(turned.ratioFor(source), closeTo(9 / 16, 1e-9));
    final px = turned.cropIn(turned.orientedSize(source));
    expect(px.width / px.height, closeTo(9 / 16, 1e-6));
  });

  test('original keeps the source ratio', () {
    final edit = const MediaEdit().withAspect(AspectPreset.original, source);
    expect(edit.ratioFor(source), closeTo(4 / 3, 1e-9));
  });

  group('resizeCrop', () {
    const bounds = Size(400, 300);
    const start = Rect.fromLTRB(100, 100, 300, 200);

    test('free corner drag moves two edges and stays inside', () {
      final r = resizeCrop(
        start: start,
        handle: CropHandle.topLeft,
        delta: const Offset(-500, 20),
        bounds: bounds,
      );
      expect(r, const Rect.fromLTRB(0, 120, 300, 200));
    });

    test('free edge drag keeps a minimum size', () {
      final r = resizeCrop(
        start: start,
        handle: CropHandle.right,
        delta: const Offset(-1000, 0),
        bounds: bounds,
        minSize: 20,
      );
      expect(r, const Rect.fromLTRB(100, 100, 120, 200));
    });

    test('move is clamped to the picture', () {
      final r = resizeCrop(
        start: start,
        handle: CropHandle.move,
        delta: const Offset(500, -500),
        bounds: bounds,
      );
      expect(r, const Rect.fromLTRB(200, 0, 400, 100));
    });

    test('locked corner keeps the ratio and the opposite corner', () {
      final r = resizeCrop(
        start: start,
        handle: CropHandle.bottomRight,
        delta: const Offset(40, 0),
        bounds: bounds,
        ratio: 2,
      );
      expect(r.topLeft, start.topLeft);
      expect(r.width / r.height, closeTo(2, 1e-9));
      expect(r.width, closeTo(240, 1e-9));
    });

    test('locked corner stops at the picture edge', () {
      final r = resizeCrop(
        start: start,
        handle: CropHandle.bottomRight,
        delta: const Offset(1000, 1000),
        bounds: bounds,
        ratio: 2,
      );
      expect(r.right, lessThanOrEqualTo(400 + 1e-9));
      expect(r.bottom, lessThanOrEqualTo(300 + 1e-9));
      expect(r.width / r.height, closeTo(2, 1e-9));
    });

    test('locked edge grows around the center', () {
      final r = resizeCrop(
        start: start,
        handle: CropHandle.top,
        delta: const Offset(0, -20),
        bounds: bounds,
        ratio: 2,
      );
      expect(r.bottom, 200);
      expect(r.height, closeTo(120, 1e-9));
      expect(r.width, closeTo(240, 1e-9));
      expect(r.center.dx, closeTo(200, 1e-9));
    });
  });
}
