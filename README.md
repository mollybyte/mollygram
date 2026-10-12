<p align="center">
  <img src="docs/assets/banner.png" alt="mollygram" width="840">
</p>

<p align="center">
  Кастомный клиент Telegram для десктопа на Flutter: macOS, Windows, Linux.
</p>

<p align="center">
  <a href="https://github.com/mollybyte/mollygram/actions/workflows/ci.yml"><img src="https://github.com/mollybyte/mollygram/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
  <a href="LICENSE"><img src="https://img.shields.io/github/license/mollybyte/mollygram?color=D6336C" alt="Лицензия"></a>
  <a href="https://github.com/mollybyte/mollygram/commits/main"><img src="https://img.shields.io/github/last-commit/mollybyte/mollygram?color=D6336C" alt="Последний коммит"></a>
  <img src="https://img.shields.io/badge/%D1%81%D1%82%D0%B0%D1%82%D1%83%D1%81-%D0%BF%D1%80%D0%BE%D1%82%D0%BE%D1%82%D0%B8%D0%BF-D6336C" alt="Статус: прототип">
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

Раскладка как у официального Telegram Desktop, чтобы не переучиваться. Сверху liquid glass и то, чего не хватает в официальном клиенте.

> [!NOTE]
> Ранняя стадия: есть макеты и основа проекта с привязкой к TDLib, интерфейса и входа в аккаунт пока нет.

## Что планируется

| | |
|---|---|
| **Плагины** | Песочница с явными правами в манифесте, в духе exteraGram. |
| **Приватность** | Режим призрака: без отметок о прочтении, без «печатает» и статуса «в сети». Локальное сохранение удалённых сообщений и история правок. |
| **Медиа** | Кружки в 120 кадров/с и до 1080p, фото и видео без сжатия по умолчанию. |
| **Работа с чатами** | Вкладки, сплит на два чата, командная палитра по <kbd>⌘</kbd> <kbd>K</kbd>. |
| **Внешний вид** | Liquid glass только на плавающем слое: боковая панель, шапка чата, поле ввода, палитра. Светлая и тёмная темы. |

## Стек

| Компонент | Что используем |
|---|---|
| UI | [Flutter](https://flutter.dev) desktop, канал stable |
| Протокол | [TDLib](https://github.com/tdlib/td) через `dart:ffi` |
| Платформы | macOS, Windows, Linux |

Первое, что нужно проверить: держит ли Flutter размытие под прокручиваемым чатом и воспроизведение кружков в 120 кадров/с.

## CI/CD

| Workflow | Когда запускается | Что делает |
|---|---|---|
| [`ci.yml`](.github/workflows/ci.yml) | push в `main`, pull request | `dart format`, `flutter analyze`, `flutter test`, затем release-сборка под macOS, Windows и Linux |
| [`release.yml`](.github/workflows/release.yml) | тег `v*` | Собирает три платформы с ключами из секретов и публикует архивы в GitHub Releases |
| [`tdlib.yml`](.github/workflows/tdlib.yml) | смена версии TDLib, вручную | Собирает universal `libtdjson.dylib` для macOS и публикует в релиз `tdlib-<версия>` |

## Разработка

| Пакет | Что внутри |
|---|---|
| [`packages/tdlib`](packages/tdlib) | Привязка `dart:ffi` к td_json, цикл `td_receive` в фоновом изоляте, типы td_api из схемы |
| `packages/core` | Модели и состояние поверх TDLib, без Flutter |
| `packages/ui_kit` | Общие виджеты, стекло, тема |
| `packages/media` | Видео, кружки, голосовые |
| `packages/plugin_host` | Песочница плагинов |
| `packages/app` | Само приложение |

Монорепо на [pub workspaces](https://dart.dev/tools/pub/workspaces): `flutter pub get` в корне ставит зависимости всех пакетов.

Ключи Telegram в репозиторий не попадают. Получите `api_id` и `api_hash` на [my.telegram.org](https://my.telegram.org), скопируйте [`config/telegram.example.json`](config/telegram.example.json) в `config/telegram.json` (он в `.gitignore`) и запускайте так:

```sh
cd packages/app
flutter run -d macos --dart-define-from-file=../../config/telegram.json
```

Для релизов те же значения лежат в секретах репозитория `TELEGRAM_API_ID` и `TELEGRAM_API_HASH`.

## Бренд

<img src="docs/assets/icon.svg" alt="Значок Mollygram" width="96" align="right">

Значок: белый пузырь сообщения с буквой m на малиновом фоне. Неоновый вордмарк используется только в промо: README, лендинг, канал. В самом приложении неона нет.

| Цвет | Светлая тема | Тёмная тема |
|---|---|---|
| Акцент по умолчанию | ![](https://img.shields.io/badge/-%230071E3-0071E3) | ![](https://img.shields.io/badge/-%230A84FF-0A84FF) |
| Малиновый акцент (опция) | ![](https://img.shields.io/badge/-%23D6336C-D6336C) | ![](https://img.shields.io/badge/-%23FF5C93-FF5C93) |
| Исходящие, малиновая тема | ![](https://img.shields.io/badge/-%23FCE4EE-FCE4EE) | ![](https://img.shields.io/badge/-%235A2338-5A2338) |
| Неон, только промо | ![](https://img.shields.io/badge/-%23FF2E88-FF2E88) | ![](https://img.shields.io/badge/-%2312070F-12070F) |

Акцент в приложении по умолчанию системный синий, малиновый включается в настройках. Исходники значка лежат в [`docs/assets`](docs/assets).

## Макеты

В `design/` лежат исходники интерактивных макетов: главное окно, медиа и файлы чата, плагины, командная палитра и настройки. Это формат дизайн-канваса (`.dc.html`), сам по себе в браузере он не откроется.

## Лицензия

[GPL-3.0](LICENSE)
