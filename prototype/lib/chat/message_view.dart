import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../circle/circle_controller.dart';
import '../icons.dart';
import '../theme.dart';
import 'fake_data.dart';

const _maxBubble = 420.0;

/// Одна строка ленты. Сообщения сплошные, без стекла.
class MessageView extends StatelessWidget {
  const MessageView({
    super.key,
    required this.msg,
    required this.newerSameSide,
    required this.circle,
  });

  final FakeMessage msg;

  /// Следующее (более новое) сообщение от того же отправителя: малый отступ.
  final bool newerSameSide;
  final CircleController circle;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    if (msg.kind == MsgKind.date) return _DatePill(msg.text);

    final Widget body = switch (msg.kind) {
      MsgKind.text => _TextBubble(msg),
      MsgKind.photos => _Photos(msg),
      MsgKind.file => _FileBubble(msg),
      MsgKind.voice => _Voice(msg),
      MsgKind.circle => _StaticCircle(msg),
      MsgKind.liveCircle => LiveCircle(controller: circle),
      MsgKind.date => const SizedBox.shrink(),
    };
    return Padding(
      padding: EdgeInsets.only(top: newerSameSide ? 0 : 6, bottom: 4),
      child: Align(
        alignment: msg.out ? Alignment.centerRight : Alignment.centerLeft,
        child: DefaultTextStyle.merge(style: mgText(c), child: body),
      ),
    );
  }
}

BorderRadius _radius(bool out) => out
    ? const BorderRadius.only(
        topLeft: Radius.circular(16),
        topRight: Radius.circular(16),
        bottomLeft: Radius.circular(16),
        bottomRight: Radius.circular(5),
      )
    : const BorderRadius.only(
        topLeft: Radius.circular(16),
        topRight: Radius.circular(16),
        bottomLeft: Radius.circular(5),
        bottomRight: Radius.circular(16),
      );

BoxDecoration _bubble(MgColors c, bool out) => BoxDecoration(
  color: out ? c.bubbleOut : c.bubbleIn,
  borderRadius: _radius(out),
  boxShadow: c.bubbleShadow == null
      ? null
      : [
          BoxShadow(
            color: c.bubbleShadow!,
            offset: const Offset(0, 1),
            blurRadius: 1,
          ),
        ],
);

class _Meta extends StatelessWidget {
  const _Meta(this.msg);
  final FakeMessage msg;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final style = TextStyle(fontSize: 11, height: 1.35, color: c.fg2);
    final ticks = msg.out ? (msg.read ? ' ✓✓' : ' ✓') : '';
    if (msg.deleted) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('удалено', style: style),
          const SizedBox(width: 12),
          Text(msg.time, style: style),
        ],
      );
    }
    return Text('${msg.time}$ticks', style: style);
  }
}

class _TextBubble extends StatelessWidget {
  const _TextBubble(this.msg);
  final FakeMessage msg;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final bubble = Container(
      constraints: const BoxConstraints(maxWidth: _maxBubble),
      padding: const EdgeInsets.fromLTRB(11, 7, 11, 5),
      decoration: _bubble(c, msg.out),
      // Время в правом нижнем углу, текст обтекает его, как в Telegram:
      // в конец текста добавляется невидимый отступ под ширину метки.
      child: Stack(
        children: [
          Text.rich(
            TextSpan(
              text: msg.text,
              children: [
                WidgetSpan(
                  child: SizedBox(
                    width: 40 + (msg.out ? 14 : 0) + (msg.deleted ? 56 : 0),
                    height: 14,
                  ),
                ),
              ],
            ),
          ),
          Positioned(right: 0, bottom: -1, child: _Meta(msg)),
        ],
      ),
    );
    return msg.deleted ? Opacity(opacity: 0.55, child: bubble) : bubble;
  }
}

const _photoTones = [
  Color(0xFFB9A68F),
  Color(0xFF8FA2B3),
  Color(0xFFA6B497),
  Color(0xFFC3B2A4),
  Color(0xFF9AA79F),
  Color(0xFFB7A0A6),
];

class _Photos extends StatelessWidget {
  const _Photos(this.msg);
  final FakeMessage msg;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final n = math.min(msg.photoCount, 4);
    final extra = msg.photoCount - n;
    Widget tile(int i, double h) => Expanded(
      child: Container(
        height: h,
        color: _photoTones[(i + msg.time.length) % _photoTones.length],
        alignment: Alignment.center,
        child: i == 3 && extra > 0
            ? Text(
                '+$extra',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              )
            : null,
      ),
    );
    final rows = <Widget>[];
    if (n == 1) {
      rows.add(Row(children: [tile(0, 220)]));
    } else {
      rows.add(
        Row(children: [tile(0, 150), const SizedBox(width: 2), tile(1, 150)]),
      );
      if (n == 3) {
        rows.addAll([
          const SizedBox(height: 2),
          Row(children: [tile(2, 110)]),
        ]);
      }
      if (n == 4) {
        rows.addAll([
          const SizedBox(height: 2),
          Row(children: [tile(2, 110), const SizedBox(width: 2), tile(3, 110)]),
        ]);
      }
    }
    return Container(
      width: 360,
      padding: const EdgeInsets.all(3),
      decoration: _bubble(c, msg.out),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: _radius(msg.out) - BorderRadius.circular(3),
            child: Column(mainAxisSize: MainAxisSize.min, children: rows),
          ),
          Positioned(right: 7, bottom: 6, child: _OnMediaPill(msg.time)),
        ],
      ),
    );
  }
}

class _OnMediaPill extends StatelessWidget {
  const _OnMediaPill(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: const Color(0x59000000),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 11, color: Colors.white, height: 1.35),
      ),
    );
  }
}

class _FileBubble extends StatelessWidget {
  const _FileBubble(this.msg);
  final FakeMessage msg;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final size =
        '${(msg.text.length * 0.37).toStringAsFixed(1).replaceAll('.', ',')} МБ';
    return Container(
      width: 280,
      padding: const EdgeInsets.fromLTRB(11, 9, 11, 6),
      decoration: _bubble(c, msg.out),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: c.accent, shape: BoxShape.circle),
            child: const DefaultTextStyle(
              style: TextStyle(color: Colors.white),
              child: MgIcon(MgIcons.download, size: 18, stroke: 2),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  msg.text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                Row(
                  children: [
                    Text(size, style: TextStyle(fontSize: 11, color: c.fg2)),
                    const Spacer(),
                    _Meta(msg),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Voice extends StatelessWidget {
  const _Voice(this.msg);
  final FakeMessage msg;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    return Container(
      width: 300,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
      decoration: _bubble(c, msg.out),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: c.accent, shape: BoxShape.circle),
            child: const DefaultTextStyle(
              style: TextStyle(color: Colors.white),
              child: MgIcon(MgIcons.play, size: 14),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 20,
                  child: CustomPaint(
                    painter: _WavePainter(msg.wave, c.accent),
                    size: const Size(double.infinity, 20),
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text(
                      '0:${(msg.wave.first + 8).toString().padLeft(2, '0')}',
                      style: TextStyle(fontSize: 11, color: c.fg2),
                    ),
                    const Spacer(),
                    _Meta(msg),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  _WavePainter(this.wave, this.color);
  final List<int> wave;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    for (var i = 0; i < wave.length; i++) {
      final h = wave[i].toDouble();
      final x = i * 4.5;
      if (x + 2.5 > size.width) break;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, (size.height - h) / 2, 2.5, h),
          const Radius.circular(2),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_WavePainter old) =>
      old.wave != wave || old.color != color;
}

/// Не проигрывающийся кружок: заливка и кольцо прогресса.
class _StaticCircle extends StatelessWidget {
  const _StaticCircle(this.msg);
  final FakeMessage msg;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      height: 200,
      child: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              color: Color(0xFF8E9A93),
              shape: BoxShape.circle,
            ),
          ),
          Positioned(
            left: 12,
            bottom: 14,
            child: _OnMediaPill('0:12 · ${msg.time}'),
          ),
        ],
      ),
    );
  }
}

/// Кружок 640x640, который реально проигрывается. Клик: пуск и пауза.
class LiveCircle extends StatefulWidget {
  const LiveCircle({super.key, required this.controller, this.size = 240});

  final CircleController controller;
  final double size;

  @override
  State<LiveCircle> createState() => _LiveCircleState();
}

class _LiveCircleState extends State<LiveCircle> {
  @override
  void initState() {
    super.initState();
    widget.controller.attach();
  }

  @override
  void dispose() {
    widget.controller.detach();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      CircleVideo(controller: widget.controller, size: widget.size);
}

/// Сама текстура кружка: используется и в ленте, и в плавающем режиме.
class CircleVideo extends StatelessWidget {
  const CircleVideo({super.key, required this.controller, required this.size});

  final CircleController controller;
  final double size;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => controller.setPlaying(!controller.playing),
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          return SizedBox(
            width: size,
            height: size,
            child: Stack(
              children: [
                const Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Color(0xFF8E9A93),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Positioned.fill(
                  child: ClipOval(
                    child: RepaintBoundary(child: controller.view()),
                  ),
                ),
                if (!controller.playing)
                  Center(
                    child: Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: Color(0x59000000),
                        shape: BoxShape.circle,
                      ),
                      child: const DefaultTextStyle(
                        style: TextStyle(color: Colors.white),
                        child: MgIcon(MgIcons.play, size: 18),
                      ),
                    ),
                  ),
                Positioned(
                  left: size * 0.06,
                  bottom: size * 0.07,
                  child: _OnMediaPill(
                    controller.error != null
                        ? 'ошибка плеера'
                        : '640 · ${controller.backend.label}',
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DatePill extends StatelessWidget {
  const _DatePill(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 10),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0x2E000000),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.white,
              height: 1.35,
            ),
          ),
        ),
      ),
    );
  }
}
