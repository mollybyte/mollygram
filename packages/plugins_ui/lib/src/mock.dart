import 'dart:ui';

import 'controller.dart';

/// Third-party plugins from design/Plugins.dc.html, for the screen before
/// the app has a real catalog, and for screenshots and tests.
///
/// The manifests are parsed by the real host parser, so a mistake in them
/// fails like a broken plugin would.
List<PluginEntry> mockPlugins({DateTime? now}) {
  final t = now ?? DateTime.now();
  return [
    PluginEntry.parse(
      '''
id: dev.tgplug.summary
name: Summary
version: 2.3.0
author: tgplug.dev
description: >-
  Recaps unread messages in a chat or folder: what was decided, what you
  were asked, where you were mentioned. Works with a local model or your own
  API key.
runtime: js
sdk: ^1.0
permissions:
  messages.read: on_command
  net: [user_endpoint]
  storage: 5mb
commands:
  - { name: /summary, title: Summary of the current chat, shortcut: ⌘⇧S }
  - { name: /summary_folder, title: For the whole folder }
settings:
  - { key: menu, type: toggle, label: Button in chat menu, default: true }
  - { key: auto, type: toggle, label: Summarize when opening a folder, default: false }
  - { key: mentions, type: toggle, label: Highlight mentions, default: true }
''',
      installed: true,
      updatedAt: t.subtract(const Duration(days: 3)),
      updateSource: '''
id: dev.tgplug.summary
name: Summary
version: 2.4.0
author: tgplug.dev
description: >-
  Recaps unread messages in a chat or folder and can insert the summary into
  your reply.
runtime: js
sdk: ^1.0
permissions:
  messages.read: on_command
  composer.write: true
  net: [user_endpoint]
  storage: 5mb
commands:
  - { name: /summary, title: Summary of the current chat, shortcut: ⌘⇧S }
  - { name: /summary_folder, title: For the whole folder }
''',
      glyph: 'Σ',
      color: const Color(0xFF5E5CE6),
    ),
    PluginEntry.parse(
      '''
id: dev.mollygram.transcribe
name: Transcribe
version: 1.0.0
author: Mollygram
description: >-
  Transcribes voice and round video messages on the device, with no network
  and no Premium.
runtime: js
sdk: ^1.0
permissions:
  media.read: [voice, round]
  storage: 1mb
hooks: [message.render.voice, message.render.round]
settings:
  - { key: auto, type: toggle, label: Transcribe automatically, default: false }
  - key: language
    type: select
    label: Language
    default: auto
    options:
      - { value: auto, label: Detect automatically }
      - { value: ru, label: Russian }
      - { value: en, label: English }
''',
      installed: true,
      updatedAt: t.subtract(const Duration(days: 5)),
      glyph: '≈',
      color: const Color(0xFFE5484D),
    ),
    PluginEntry.parse(
      '''
id: tools.calm.quiet
name: Quiet hours
version: 1.4.0
author: calm.tools
description: >-
  Holds notifications on a schedule and delivers them in a single batch.
  Favorite contacts always get through.
runtime: js
sdk: ^1.0
permissions:
  notifications.manage: true
hooks: [notification.incoming]
''',
      installed: true,
      enabled: false,
      updatedAt: t.subtract(const Duration(days: 14)),
      glyph: 'Z',
      color: const Color(0xFF8E8E93),
    ),
    PluginEntry.parse(
      '''
id: tg.shiki.code
name: Code highlighting
version: 3.0.0
author: shiki-tg
description: Highlights code blocks in theme colors, adds line numbers and a copy button.
runtime: js
sdk: ^1.0
hooks: [message.render.code]
''',
      installed: true,
      updatedAt: t.subtract(const Duration(days: 31)),
      glyph: '{',
      color: const Color(0xFF30A46C),
    ),
    PluginEntry.parse(
      '''
id: dev.unfurl.cards
name: Link cards
version: 0.9.8
author: unfurl
description: >-
  Shows a card instead of the regular preview: GitHub PR status, a Figma
  frame, a YouTube timestamp.
runtime: js
sdk: ^1.0
permissions:
  net: [github.com, figma.com, youtube.com]
''',
      glyph: '↗',
      color: const Color(0xFFB07D3A),
    ),
    PluginEntry.parse(
      '''
id: io.graphy.stats
name: Chat statistics
version: 0.6.1
author: graphy
description: Builds activity charts from local history. Sends nothing out.
runtime: js
sdk: ^1.0
permissions:
  messages.read: all
commands:
  - { name: /stats, title: Open statistics }
''',
      glyph: '▤',
      color: const Color(0xFF636366),
    ),
  ];
}
