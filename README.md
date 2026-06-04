# cch3r1-messanger

Минималистичный личный мессенджер на Flutter + Supabase.

* **Framework:** Flutter 3.x / Dart 3
* **State:** `flutter_riverpod` (codegen) + `freezed`
* **Navigation:** `go_router`
* **Offline cache:** `sqflite` + `path_provider`
* **Backend:** Supabase (PostgreSQL + Auth + Realtime + Storage)
* **Auth:** только по нику и паролю (никаких email / телефонов — используется скрытый
  маппинг `username → ${username}@local.app`)

## Структура проекта

Feature-First Clean Architecture. Каждая фича содержит слои `data/`, `domain/`,
`presentation/`.

```
lib/
├── main.dart                  # Инициализация Supabase, ProviderScope
├── app.dart                   # MaterialApp.router + тема + routing
├── config/
│   ├── routes.dart            # GoRouter + redirect по сессии
│   ├── theme.dart             # Material 3: светлая/тёмная
│   └── supabase_config.dart   # URL / anonKey / init
├── core/
│   ├── constants/             # Строки (ru) + пути к ассетам
│   ├── errors/                # Exceptions + Failures
│   ├── usecases/              # Абстрактный UseCase<Type, Params>
│   └── utils/                 # UsernameMapper, validators
├── features/
│   ├── auth/                  # Регистрация / вход / выход
│   ├── chat_list/             # Список диалогов
│   ├── chat/                  # Переписка + Realtime + пагинация
│   ├── search_user/           # Поиск по нику
│   └── profile/               # Редактирование профиля + аватар
└── services/
    └── connection_service.dart
```

## Supabase

1. Создайте проект Supabase, скопируйте `URL` и `anon key`.
2. Примените SQL-миграцию: `supabase/migrations/0001_init.sql`.
3. Задеплойте Edge Function:
   ```bash
   supabase functions deploy check-username --no-verify-jwt
   ```
4. В **Authentication → Providers → Email** отключите «Confirm email».
5. Создайте публичный bucket `avatars` в Storage.
6. Пропишите `URL` и `anon key` в `lib/config/supabase_config.dart` (или задайте через
   `--dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...`).

## Запуск

```bash
# Установить зависимости
flutter pub get

# Сгенерировать файлы: *.freezed.dart, *.g.dart, *.riverpod.dart
dart run build_runner build --delete-conflicting-outputs

# Собрать / запустить (Android)
flutter run \
  --dart-define=SUPABASE_URL=https://<your-project>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<your-anon-key>
```

## Генерация кода (build_runner)

Следующие файлы порождаются автоматически и НЕ должны редактироваться вручную:

| Исходник | Порождаемый файл |
|---|---|
| `*.freezed.dart` модели/состояния | `*.freezed.dart` |
| `@JsonSerializable()` модели | `*.g.dart` |
| `@riverpod` провайдеры | `*.g.dart` (riverpod_generator) |

Перегенерация:

```bash
dart run build_runner watch --delete-conflicting-outputs
```

## Сборка APK в CI

Готовый workflow для GitHub Actions (`Build Android APK`) — путь:
`.github/workflows/android-apk.yml`. Он собирает debug+release APK и
публикует их как артефакты:

* `cch3r1-messanger-debug-apk` — `app-debug.apk`
* `cch3r1-messanger-release-apk` — `app-release.apk` (подписан debug-ключом)

Полный YAML:

```yaml
name: Build Android APK

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
  workflow_dispatch:

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

jobs:
  build-apk:
    name: Build APK (debug + release)
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: "17"
      - uses: subosito/flutter-action@v2
        with:
          channel: stable
          cache: true
          flutter-version: "3.27.1"
      - run: flutter --version
      - run: flutter pub get
      - run: dart run build_runner build --delete-conflicting-outputs
      - run: flutter analyze
      - id: cfg
        run: |
          DEFINES=""
          if [ -n "${{ secrets.SUPABASE_URL }}" ]; then
            DEFINES="$DEFINES --dart-define=SUPABASE_URL=${{ secrets.SUPABASE_URL }}"
          fi
          if [ -n "${{ secrets.SUPABASE_ANON_KEY }}" ]; then
            DEFINES="$DEFINES --dart-define=SUPABASE_ANON_KEY=${{ secrets.SUPABASE_ANON_KEY }}"
          fi
          echo "defines=$DEFINES" >> "$GITHUB_OUTPUT"
      - run: flutter build apk --debug ${{ steps.cfg.outputs.defines }}
      - run: flutter build apk --release ${{ steps.cfg.outputs.defines }}
      - run: |
          mkdir -p artifacts
          cp build/app/outputs/flutter-apk/app-debug.apk artifacts/cch3r1-messanger-debug.apk
          cp build/app/outputs/flutter-apk/app-release.apk artifacts/cch3r1-messanger-release.apk
      - uses: actions/upload-artifact@v4
        with:
          name: cch3r1-messanger-debug-apk
          path: artifacts/cch3r1-messanger-debug.apk
          if-no-files-found: error
          retention-days: 30
      - uses: actions/upload-artifact@v4
        with:
          name: cch3r1-messanger-release-apk
          path: artifacts/cch3r1-messanger-release.apk
          if-no-files-found: error
          retention-days: 30
```

## Сборка APK и IPA в CI

В `.github/workflows/` лежат два workflow:

* `android-apk.yml` — `Build Android APK` (ubuntu-latest, JDK 17, Flutter 3.27.1).
* `ios-ipa.yml` — `Build iOS IPA (unsigned)` (macos-14, Xcode 15.4, Flutter 3.27.1).

Оба триггерятся на push/PR в `main` и на ручной запуск (`workflow_dispatch`).
Артефакты загружаются как `cch3r1-messanger-{debug,release}-apk` и
`cch3r1-messanger-ios-unsigned-ipa` (retention 30 дней).

### Secrets

`Settings → Secrets and variables → Actions` репозитория:

| Секрет | Обязательный? | Зачем |
|---|---|---|
| `SUPABASE_URL` | опц. | Перекрывает `lib/config/supabase_config.dart` через `--dart-define`. |
| `SUPABASE_ANON_KEY` | опц. | То же. |
| `GIPHY_API_KEY` | опц. | Ключ Giphy для GIF-вставок. |
| `ANDROID_KEYSTORE_BASE64` | опц. | `base64 -w0 release.keystore`. Если задан — релиз подписывается. |
| `ANDROID_KEYSTORE_PASSWORD` | опц. | Пароль keystore. |
| `ANDROID_KEY_ALIAS` | опц. | Alias ключа. |
| `ANDROID_KEY_PASSWORD` | опц. | Пароль ключа. |

### Android (`android-apk.yml`)

* Temurin JDK 17, Flutter 3.27.1 stable (с кэшем `~/.pub-cache`).
* `pub get` → `build_runner` → `flutter analyze`.
* Если заданы `ANDROID_KEYSTORE_*` — раскладывает `android/app/release.keystore`
  и `android/key.properties` перед сборкой; иначе release подписывается
  debug-ключом.
* Собирает **debug и release** APK.
* Артефакты: `cch3r1-messanger-debug-apk`, `cch3r1-messanger-release-apk`.

### iOS (`ios-ipa.yml`)

* `macos-14` + Xcode 15.4, Flutter 3.27.1 stable.
* `actions/cache@v4` для `ios/Pods` и `~/Library/Caches/CocoaPods` (ключ
  по `Podfile.lock`) — повторные сборки заметно быстрее.
* `flutter build ios --release --no-codesign` → `build/ios/iphoneos/Runner.app`
  оборачивается в `Payload/` и зипуется в `cch3r1-messanger-unsigned.ipa`.
* **Не подписан** — ставится через TrollStore / AltStore / Sideloadly / на
  джейлбрейк. Для App Store / TestFlight нужен экспорт из локального Xcode
  с сертификатом разработчика (это требует интерактивного доступа к Apple ID
  и не делается в CI).

### Как сгенерировать keystore для Android

```bash
keytool -genkey -v \
  -keystore android/app/release.keystore \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias cch3r1 \
  -storepass <KEYSTORE_PASSWORD> \
  -keypass <KEY_PASSWORD> \
  -dname "CN=cch3r1,O=local,C=RU"

base64 -w0 android/app/release.keystore
# скопировать в ANDROID_KEYSTORE_BASE64
```

Артефакты скачиваются в `Actions → <workflow> → <run> → Artifacts`.

## Безопасность

* Токены сессии хранятся `supabase_flutter` (secure storage под капотом).
* Скриншоты приложения разрешены (FLAG_SECURE снят) — пользователь может сохранять чаты и скачивать фото из галереи.
* Валидация ника на клиенте: `^[a-zA-Z0-9_]{3,20}$`.
* RLS включён для всех таблиц (см. `supabase/migrations/0001_init.sql`).

## Офлайн-режим

`sqflite` кэширует:
* профиль текущего пользователя,
* до 50 последних диалогов,
* до 100 последних сообщений в каждом чате.

При отсутствии сети приложение работает из локальной БД; при восстановлении
соединения данные подтягиваются с сервера.
