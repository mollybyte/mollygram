import 'package:flutter/material.dart';

import 'chat/fake_data.dart';
import 'glass.dart';
import 'icons.dart';
import 'theme.dart';
import 'widgets.dart';

/// Плавающий стеклянный остров со списком чатов.
class Sidebar extends StatefulWidget {
  const Sidebar({super.key, required this.selected, required this.onSelect});

  final int selected;
  final ValueChanged<int> onSelect;

  @override
  State<Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<Sidebar> {
  int _folder = 0;

  static const _folders = [
    ('Все', 0),
    ('Личные', 2),
    ('Работа', 3),
    ('Каналы', 0),
  ];

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    return Glass(
      radius: 16,
      child: DefaultTextStyle.merge(
        style: mgText(c),
        child: Column(
          children: [
            SizedBox(
              height: 44,
              child: Row(
                children: [
                  // Место под системные кнопки окна.
                  const SizedBox(width: 76, child: WindowDragArea()),
                  const Expanded(child: WindowDragArea()),
                  IconBtn(MgIcons.compose, tooltip: 'Новое сообщение'),
                  const SizedBox(width: 8),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Container(
                height: 30,
                padding: const EdgeInsets.symmetric(horizontal: 9),
                decoration: BoxDecoration(
                  color: c.field,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    DefaultTextStyle.merge(
                      style: TextStyle(color: c.fg2),
                      child: const MgIcon(
                        MgIcons.search,
                        size: 14,
                        stroke: 2.2,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: TextField(
                        style: mgText(c),
                        cursorHeight: 15,
                        decoration: InputDecoration.collapsed(
                          hintText: 'Поиск',
                          hintStyle: mgText(c).copyWith(color: c.fg2),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 6),
              child: Row(
                children: [
                  for (var i = 0; i < _folders.length; i++)
                    _FolderTab(
                      label: _folders[i].$1,
                      count: _folders[i].$2,
                      on: i == _folder,
                      onTap: () => setState(() => _folder = i),
                    ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
                itemCount: fakeChats.length,
                itemBuilder: (context, i) => _ChatRow(
                  chat: fakeChats[i],
                  on: i == widget.selected,
                  onTap: () => widget.onSelect(i),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FolderTab extends StatelessWidget {
  const _FolderTab({
    required this.label,
    required this.count,
    required this.on,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 26,
        margin: const EdgeInsets.only(right: 2),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: on ? c.field : Colors.transparent,
          borderRadius: BorderRadius.circular(13),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: on ? c.fg : c.fg2,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 5),
              Text('$count', style: TextStyle(fontSize: 11.5, color: c.fg2)),
            ],
          ],
        ),
      ),
    );
  }
}

class _ChatRow extends StatefulWidget {
  const _ChatRow({required this.chat, required this.on, required this.onTap});

  final FakeChat chat;
  final bool on;
  final VoidCallback onTap;

  @override
  State<_ChatRow> createState() => _ChatRowState();
}

class _ChatRowState extends State<_ChatRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final chat = widget.chat;
    final on = widget.on;
    final sub = on ? const Color(0xD1FFFFFF) : c.fg2;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 1),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: on ? c.accent : (_hover ? c.hover : Colors.transparent),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Avatar(chat.initials, size: 42),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            chat.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13.5,
                              color: on ? Colors.white : c.fg,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          chat.time,
                          style: TextStyle(fontSize: 11.5, color: sub),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            chat.last,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: sub),
                          ),
                        ),
                        if (chat.unread > 0) ...[
                          const SizedBox(width: 6),
                          _Badge(chat.unread, muted: chat.muted, onAccent: on),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.n, {required this.muted, required this.onAccent});

  final int n;
  final bool muted;
  final bool onAccent;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    return Container(
      constraints: const BoxConstraints(minWidth: 18),
      height: 18,
      padding: const EdgeInsets.symmetric(horizontal: 5),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: onAccent ? Colors.white : (muted ? c.muted : c.accent),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        '$n',
        style: TextStyle(
          fontSize: 11,
          height: 1,
          fontWeight: FontWeight.w600,
          color: onAccent ? c.accent : Colors.white,
        ),
      ),
    );
  }
}
