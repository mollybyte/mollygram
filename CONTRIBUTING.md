# Contributing to Mollygram

Thanks for your interest in Mollygram. This document describes how the project is organized and what a change needs before it can be merged.

By taking part you agree to follow the [Code of Conduct](CODE_OF_CONDUCT.md). Security issues go through [`SECURITY.md`](SECURITY.md), not public issues.

## Getting started

Flutter is managed with [fvm](https://fvm.app); the version is pinned in [`.fvmrc`](.fvmrc).

```sh
fvm install
fvm flutter pub get
```

The repository is a [pub workspace](https://dart.dev/tools/pub/workspaces): one `pub get` at the root resolves every package under `packages/`. See the [README](README.md#development) for the package layout and for running the app with your own Telegram API keys.

Before opening a pull request, run the same checks as CI for the packages you touched:

```sh
dart format packages/<name>
fvm flutter analyze packages/<name>
cd packages/<name> && fvm flutter test   # or `dart test` for pure Dart packages
```

If you change the TDLib schema or the generator, regenerate the bindings with `dart run packages/tdlib/tool/generate.dart` and commit the result.

## Language and style

- English is the language of the codebase: identifiers, comments, docs, commit messages, issues and pull requests.
- Dart code follows [Effective Dart](https://dart.dev/effective-dart) and is formatted with `dart format`. Doc comments use `///`, start with a one-sentence summary, and explain *why* rather than restating the code.
- UI strings are written in English first. Every user-facing string has a Russian translation that is kept in sync with the English one. In Russian strings only the first word is capitalized ("Режим призрака", not "Режим Призрака").

## Branches

Work happens on short-lived branches off `main`, named `<type>/<short-description>`, for example:

```
feat/chat-tabs
fix/circle-playback-stutter
docs/plugin-permissions
```

`main` is always releasable. Do not push to it directly.

## Commit messages

Mollygram follows [Conventional Commits 1.0.0](https://www.conventionalcommits.org/en/v1.0.0/):

```
<type>(<scope>): <description>

[optional body]

[optional footer(s)]
```

- **type** is one of:

  | Type | Use for | Version bump |
  |---|---|---|
  | `feat` | A new user-facing feature | minor |
  | `fix` | A bug fix | patch |
  | `perf` | A performance improvement | patch |
  | `refactor` | Code change that neither fixes a bug nor adds a feature | none |
  | `docs` | Documentation only | none |
  | `test` | Adding or fixing tests | none |
  | `build` | Build system, dependencies, Flutter or TDLib version | none |
  | `ci` | CI and release workflows | none |
  | `style` | Formatting, no code change | none |
  | `chore` | Anything else that does not touch shipped code | none |
  | `revert` | Reverting an earlier commit | depends |

- **scope** is optional and names the area: `app`, `core`, `tdlib`, `ui_kit`, `media`, `plugin_host`, `plugin_sdk`, `prototype`, `design`, `web`, `docs`, `ci`, `deps`, `release`.
- **description** is imperative, lowercase, without a trailing period: `add split view for two chats`, not `Added split view.`
- A gitmoji may follow the colon if you like: `feat(app): ✨ add split view for two chats`. Keep the type first, because the changelog and release tooling read it.
- Breaking changes add `!` after the type or scope and explain the change in a `BREAKING CHANGE:` footer.

Examples:

```
feat(app): add command palette on cmd+k
fix(tdlib): close the client when the receive isolate exits
perf(media): reuse the decoder between video messages
docs(plugins): describe the storage permission
feat(plugin_sdk)!: rename onMessage to onMessageRender

BREAKING CHANGE: plugins must subscribe to message.render instead of message.
```

## Pull requests

- Keep a pull request focused on one change. Fill in the [pull request template](.github/pull_request_template.md).
- **The PR title must be a Conventional Commit** (`feat(app): add chat tabs`). CI checks it, because pull requests are squash-merged and the title becomes the commit on `main`.
- CI must be green: format, analyze, codegen check, tests and builds.
- Include screenshots or a short recording for UI changes, in both light and dark themes.
- New features need tests where it is practical; bug fixes need a test that reproduces the bug.

## Versioning and releases

Mollygram follows [Semantic Versioning](https://semver.org). While the version is `0.x`, a minor bump may contain breaking changes.

Releases are automated with [release-please](https://github.com/googleapis/release-please):

1. Every push to `main` updates a release pull request titled `chore: release <version>`. It bumps the version in [`packages/app/pubspec.yaml`](packages/app/pubspec.yaml) and [`.release-please-manifest.json`](.release-please-manifest.json) and adds the new entries to [`CHANGELOG.md`](CHANGELOG.md), all derived from the commit messages.
2. Merging the release pull request creates the `v<version>` tag and the GitHub release.
3. The [release workflow](.github/workflows/release.yml) builds macOS, Windows and Linux and attaches the archives to that release.

Do not edit `CHANGELOG.md` or version numbers by hand; write a good commit message instead.

## Plugins

The plugin API and manifest format are documented in [`docs/plugins.md`](docs/plugins.md). Changes to the plugin SDK are part of the public API: mark breaking ones with `!`.

## License

By contributing you agree that your contributions are licensed under the [GPL-3.0](LICENSE).
