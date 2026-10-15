<p align="center">
  <img src="docs/assets/banner.png" alt="mollygram" width="840">
</p>

<p align="center">
  A custom desktop Telegram client built with Flutter for macOS, Windows and Linux.
</p>

<p align="center">
  <a href="https://github.com/mollybyte/mollygram/actions/workflows/ci.yml"><img src="https://github.com/mollybyte/mollygram/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
  <a href="LICENSE"><img src="https://img.shields.io/github/license/mollybyte/mollygram?color=D6336C" alt="License"></a>
  <a href="https://github.com/mollybyte/mollygram/commits/main"><img src="https://img.shields.io/github/last-commit/mollybyte/mollygram?color=D6336C" alt="Last commit"></a>
  <img src="https://img.shields.io/badge/status-prototype-D6336C" alt="Status: prototype">
  <a href="https://www.conventionalcommits.org"><img src="https://img.shields.io/badge/Conventional%20Commits-1.0.0-D6336C" alt="Conventional Commits"></a>
</p>

<p align="center">
  <a href="https://flutter.dev"><img src="https://img.shields.io/badge/Flutter-stable-02569B?logo=flutter&logoColor=white" alt="Flutter"></a>
  <a href="https://dart.dev"><img src="https://img.shields.io/badge/Dart-3-0175C2?logo=dart&logoColor=white" alt="Dart"></a>
  <a href="https://github.com/tdlib/td"><img src="https://img.shields.io/badge/TDLib-FFI-26A5E4?logo=telegram&logoColor=white" alt="TDLib"></a>
  <img src="https://img.shields.io/badge/macOS-000000?logo=apple&logoColor=white" alt="macOS">
  <img src="https://img.shields.io/badge/Windows-0078D4?logo=windows11&logoColor=white" alt="Windows">
  <img src="https://img.shields.io/badge/Linux-FCC624?logo=linux&logoColor=black" alt="Linux">
</p>

---

The layout follows the official Telegram Desktop, so there is nothing to relearn. On top of it: liquid glass and the features the official client is missing.

> [!NOTE]
> Early stage: sign-in, the chat list, chats with every message type, tabs, split view and the command palette work. The order of what comes next is in [`docs/roadmap.md`](docs/roadmap.md), the feature backlog against the official client in [`docs/parity.md`](docs/parity.md).

## Planned features

| | |
|---|---|
| **Plugins** | A sandbox with explicit permissions declared in the manifest, in the spirit of exteraGram. |
| **Privacy** | Ghost mode: no read receipts, no "typing" and no "online" status. Locally saved deleted messages and edit history. |
| **Media** | Video messages at 120 fps and up to 640×640, photos and videos sent uncompressed by default. |
| **Chat workflow** | Tabs, a split view for two chats, a command palette on <kbd>⌘</kbd> <kbd>K</kbd>. |
| **Look** | Liquid glass only on the floating layer: sidebar, chat header, composer, palette. Light and dark themes. |

## Stack

| Component | Technology |
|---|---|
| UI | [Flutter](https://flutter.dev) desktop, stable channel |
| Protocol | [TDLib](https://github.com/tdlib/td) via `dart:ffi` |
| Plugins | JavaScript and TypeScript on [QuickJS-ng](https://github.com/quickjs-ng/quickjs), see [`docs/plugins.md`](docs/plugins.md) |
| Platforms | macOS, Windows, Linux |

## Development

| Package | Contents |
|---|---|
| [`packages/tdlib`](packages/tdlib) | `dart:ffi` bindings to td_json, the `td_receive` loop in a background isolate, td_api types generated from the schema |
| `packages/core` | Models and state on top of TDLib, no Flutter dependency |
| `packages/ui_kit` | Shared widgets, glass, theme |
| `packages/media` | Video, video messages, voice messages |
| [`packages/shell`](packages/shell) | Window layout: chat tabs, split view, ⌘K command palette |
| [`packages/plugin_host`](packages/plugin_host) | Plugin sandbox and the built-in Filters and Translate plugins |
| `packages/plugins_ui` | The plugins settings screen |
| `packages/plugin_sdk` | TypeScript types for plugin authors |
| `packages/app` | The application itself |

Flutter is installed with [fvm](https://fvm.app). The version is pinned in [`.fvmrc`](.fvmrc) and CI uses the same one. The project tracks the latest stable Flutter.

```sh
git clone --recurse-submodules https://github.com/mollybyte/mollygram.git
cd mollygram
fvm install
fvm flutter pub get
```

If you cloned without `--recurse-submodules`, run `git submodule update --init --recursive` once: the plugin host builds QuickJS from the [quickjs-ng](https://github.com/quickjs-ng/quickjs) submodule.

The repository is a monorepo on [pub workspaces](https://dart.dev/tools/pub/workspaces): `pub get` at the root installs dependencies for every package.

Telegram API keys never go into the repository. Get your `api_id` and `api_hash` at [my.telegram.org](https://my.telegram.org), copy [`config/telegram.example.json`](config/telegram.example.json) to `config/telegram.json` (it is in `.gitignore`) and run:

```sh
cd packages/app
fvm flutter run -d macos --dart-define-from-file=../../config/telegram.json
```

Release builds take the same values from the repository secrets `TELEGRAM_API_ID` and `TELEGRAM_API_HASH`.

## Contributing

Contributions are welcome. Read [`CONTRIBUTING.md`](CONTRIBUTING.md) first: the project uses [Conventional Commits](https://www.conventionalcommits.org) and [Semantic Versioning](https://semver.org), and the changelog is generated from commit messages. Please follow the [Code of Conduct](CODE_OF_CONDUCT.md). Report vulnerabilities privately as described in [`SECURITY.md`](SECURITY.md).

## CI/CD

| Workflow | Runs on | What it does |
|---|---|---|
| [`ci.yml`](.github/workflows/ci.yml) | push to `main`, pull requests | `dart format`, `flutter analyze`, `flutter test`, then release builds for macOS, Windows and Linux |
| [`pr-title.yml`](.github/workflows/pr-title.yml) | pull requests | Checks that the PR title follows Conventional Commits |
| [`release-please.yml`](.github/workflows/release-please.yml) | push to `main` | Keeps a release PR with the next version and `CHANGELOG.md` up to date; merging it tags `v*` and starts the release |
| [`release.yml`](.github/workflows/release.yml) | `v*` tag, release PR merge | Builds all three platforms with keys from secrets and attaches the archives to the GitHub release |
| [`plugin_host.yml`](.github/workflows/plugin_host.yml) | changes to the plugin packages | Builds QuickJS and runs the plugin host tests on all three platforms, and tests the plugins screen |
| [`tdlib.yml`](.github/workflows/tdlib.yml) | TDLib version change, manual | Builds a universal `libtdjson.dylib` for macOS and publishes it to the `tdlib-<version>` release |

## Brand

<img src="docs/assets/icon.svg" alt="Mollygram icon" width="96" align="right">

The icon is a white speech bubble with the letter m on a raspberry background. The neon wordmark is for promo only: README, website, channel. The app itself has no neon.

| Color | Light theme | Dark theme |
|---|---|---|
| Default accent | ![](https://img.shields.io/badge/-%230071E3-0071E3) | ![](https://img.shields.io/badge/-%230A84FF-0A84FF) |
| Raspberry accent (optional) | ![](https://img.shields.io/badge/-%23D6336C-D6336C) | ![](https://img.shields.io/badge/-%23FF5C93-FF5C93) |
| Outgoing bubbles, raspberry theme | ![](https://img.shields.io/badge/-%23FCE4EE-FCE4EE) | ![](https://img.shields.io/badge/-%235A2338-5A2338) |
| Neon, promo only | ![](https://img.shields.io/badge/-%23FF2E88-FF2E88) | ![](https://img.shields.io/badge/-%2312070F-12070F) |

The in-app accent defaults to system blue; raspberry can be turned on in settings. Icon sources live in [`docs/assets`](docs/assets).

## Design mockups

`design/` holds the sources of the interactive mockups: main window, chat media and files, plugins, command palette and settings. Each mockup can switch between English and Russian. They use the design canvas format (`.dc.html`) and do not open in a plain browser.

## License

[GPL-3.0](LICENSE)
