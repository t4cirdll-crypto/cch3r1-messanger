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

## Безопасность

* Токены сессии хранятся `supabase_flutter` (secure storage под капотом).
* `FLAG_SECURE` выставляется в `MainActivity.kt` — запрет скриншотов/записи экрана.
* Валидация ника на клиенте: `^[a-zA-Z0-9_]{3,20}$`.
* RLS включён для всех таблиц (см. `supabase/migrations/0001_init.sql`).

## Офлайн-режим

`sqflite` кэширует:
* профиль текущего пользователя,
* до 50 последних диалогов,
* до 100 последних сообщений в каждом чате.

При отсутствии сети приложение работает из локальной БД; при восстановлении
соединения данные подтягиваются с сервера.
