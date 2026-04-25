/// Конфигурация Supabase. Значения берём из `--dart-define`,
/// чтобы не коммитить ключи в репозиторий.
class SupabaseConfig {
  const SupabaseConfig._();

  // Дефолты — публичные значения проекта (безопасно для клиента: RLS включён,
  // anon-ключ имеет ровно те права, что описаны в политиках).
  // Их можно переопределить через `--dart-define` при сборке.
  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://eorpxscbzetqezctdeqg.supabase.co',
  );

  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'sb_publishable_qJxQoJK1C1HKQYNaiZTRFQ_hALJIPWr',
  );

  /// Имя функции, проверяющей свободен ли ник.
  static const String checkUsernameFunction = 'check-username';

  /// Публичный bucket для аватаров.
  static const String avatarsBucket = 'avatars';
}
