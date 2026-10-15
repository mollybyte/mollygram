import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mollygram_ui_kit/mollygram_ui_kit.dart';
import 'package:plugin_host/plugin_host.dart';

import 'app_plugins.dart';

export 'package:plugin_host/plugin_host.dart' show CodeSpan;

/// A code block of a message: its text and the language it was marked with.
typedef CodeBlock = ({String code, String? language});

/// Telegram messages are at most 4096 characters; anything longer is not
/// a message's code block and is left plain.
const maxHighlightedCode = 4096;

/// The colored pieces of [CodeBlock], from the plugins that render code
/// (`message.render.code`), or null to leave it plain.
final codeHighlightProvider = FutureProvider.autoDispose
    .family<List<CodeSpan>?, CodeBlock>((ref, block) async {
      if (block.code.isEmpty || block.code.length > maxHighlightedCode) {
        return null;
      }
      final plugins = await ref.watch(appPluginsProvider.future);
      void changed() => ref.invalidateSelf();
      plugins.revision.addListener(changed);
      ref.onDispose(() => plugins.revision.removeListener(changed));
      return plugins.highlightCode(block.code, block.language);
    });

/// The theme's color for a code token, after Xcode's default themes. Null
/// for plain text, which keeps the block's own color.
Color? codeTokenColor(String token, MgColors c) => switch (token) {
  'keyword' => c.isDark ? const Color(0xFFFF7AB2) : const Color(0xFF9B2393),
  'string' => c.isDark ? const Color(0xFFFF8170) : const Color(0xFFC41A16),
  'number' => c.isDark ? const Color(0xFFD9C97C) : const Color(0xFF1C00CF),
  'comment' => c.isDark ? const Color(0xFF7F8C98) : const Color(0xFF5D6C79),
  'function' => c.isDark ? const Color(0xFF67B7A4) : const Color(0xFF326D74),
  'type' => c.isDark ? const Color(0xFF5DD8FF) : const Color(0xFF0B4F79),
  'punctuation' => c.fg2,
  _ => null,
};
