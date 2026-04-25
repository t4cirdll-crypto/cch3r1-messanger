/// Конфигурация Giphy API. Ключ передаётся через `--dart-define=GIPHY_API_KEY=...`
/// при сборке. Если ключ пустой, GIF-функция остаётся отключённой и UI
/// показывает соответствующий placeholder.
class GiphyConfig {
  const GiphyConfig._();

  static const String apiKey = String.fromEnvironment(
    'GIPHY_API_KEY',
    defaultValue: '',
  );

  static bool get isEnabled => apiKey.isNotEmpty;

  /// Базовый URL Giphy v1.
  static const String baseUrl = 'https://api.giphy.com/v1/gifs';
}
