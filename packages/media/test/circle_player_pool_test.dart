import 'package:flutter_test/flutter_test.dart';
import 'package:mollygram_media/mollygram_media.dart';

import 'fake_circle_player.dart';

void main() {
  late List<FakeCirclePlayer> made;
  late CirclePlayerPool pool;

  setUp(() {
    made = [];
    pool = CirclePlayerPool(
      create: (side) {
        final p = FakeCirclePlayer(side);
        made.add(p);
        return p;
      },
    );
  });

  test('a released player is stopped and handed out again', () async {
    final a = pool.acquire(640) as FakeCirclePlayer;
    await a.open(const CircleSource.asset('a.mp4'));
    await pool.release(a);

    expect(a.calls, ['open asset:///a.mp4', 'stop']);
    expect(a.disposed, isFalse);
    expect(pool.idleCount(640), 1);

    final b = pool.acquire(640);
    expect(b, same(a));
    expect(pool.created, 1);
    expect(pool.busyCount, 1);
  });

  test('players are kept per output size', () async {
    final a = pool.acquire(384);
    await pool.release(a);
    final b = pool.acquire(640);

    expect(b, isNot(same(a)));
    expect(b.outputSide, 640);
    expect(pool.idleCount(384), 1);
  });

  test('players beyond maxIdle are disposed on release', () async {
    final players = [for (var i = 0; i < 3; i++) pool.acquire(512)];
    for (final p in players) {
      await pool.release(p);
    }

    expect(pool.idleCount(512), 2);
    expect(made.where((p) => p.disposed), [players.last]);
  });

  test('warmUp creates idle players up to maxIdle', () {
    pool.warmUp(640, count: 5);

    expect(pool.idleCount(640), 2);
    expect(pool.created, 2);
    pool.acquire(640);
    expect(pool.created, 2);
  });

  test('releasing a player twice or a foreign player does nothing', () async {
    final a = pool.acquire(640);
    await pool.release(a);
    await pool.release(a);
    await pool.release(FakeCirclePlayer(640));

    expect(pool.idleCount(640), 1);
  });

  test('dispose frees idle players, and busy ones on release', () async {
    final idle = pool.acquire(640);
    final busy = pool.acquire(640);
    await pool.release(idle);
    await pool.dispose();

    expect((idle as FakeCirclePlayer).disposed, isTrue);
    expect((busy as FakeCirclePlayer).disposed, isFalse);
    await pool.release(busy);
    expect(busy.disposed, isTrue);
    expect(() => pool.acquire(640), throwsStateError);
  });
}
