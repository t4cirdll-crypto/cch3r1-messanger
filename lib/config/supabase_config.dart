/// Конфигурация Supabase. Значения берём из `--dart-define`,
/// чтобы не коммитить ключи в репозиторий.
class SupabaseConfig {
  const SupabaseConfig._();

  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://YOUR-PROJECT.supabase.co',
  );

  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'YOUR-ANON-KEY',
  );

  /// Имя функции, проверяющей свободен ли ник.
  static const String checkUsernameFunction = 'check-username';

  /// Публичный bucket для аватаров.
  static const String avatarsBucket = 'avatars';
}
