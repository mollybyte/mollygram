# Security policy

Mollygram handles private conversations, so security reports are taken seriously.

## Supported versions

The project is in early development. Only the latest release and the `main` branch receive security fixes.

## Reporting a vulnerability

Please **do not open a public issue**. Report the vulnerability privately through [GitHub security advisories](https://github.com/mollybyte/mollygram/security/advisories/new).

Include:

- what the problem is and what an attacker could do with it;
- steps or a proof of concept to reproduce it;
- the affected version or commit and platform.

You will get an acknowledgement within 7 days. Once a fix is released, the advisory is published and you are credited unless you prefer otherwise.

## Scope

In scope: the Mollygram app, the plugin sandbox (`packages/plugin_host`) and its permission model, and how the app stores sessions and keys.

Out of scope: vulnerabilities in Telegram servers, the MTProto protocol or TDLib itself. Report those to [Telegram](https://telegram.org/faq#q-what-if-i-find-a-bug) or [TDLib](https://github.com/tdlib/td/issues). If a TDLib bug is exploitable through Mollygram, you can still report it here.
