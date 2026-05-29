import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import '../utils/proxy_settings.dart';

/// Кастомный HTTP клиент для Supabase SDK, который на лету
/// применяет настройки прокси без перезапуска приложения.
class DynamicProxyHttpClient extends http.BaseClient {
  IOClient? _currentClient;
  String? _lastProxyConfig;

  IOClient _getClient() {
    final bool enabled = ProxySettings.isEnabled;
    final String type = ProxySettings.type;
    final String host = ProxySettings.host;
    final int port = ProxySettings.port;

    final String configString = '$enabled|$type|$host|$port';
    if (_currentClient != null && _lastProxyConfig == configString) {
      return _currentClient!;
    }

    final HttpClient innerClient = HttpClient();
    
    // Таймауты для более надежного соединения в плохих условиях сети
    innerClient.connectionTimeout = const Duration(seconds: 15);

    if (enabled && host.isNotEmpty && port > 0) {
      innerClient.findProxy = (Uri uri) {
        if (type == 'SOCKS5') {
          return 'SOCKS5 $host:$port; SOCKS $host:$port';
        } else {
          return 'PROXY $host:$port';
        }
      };
      
      // Игнорируем ошибки самоподписанных сертификатов при отладке / через прокси
      innerClient.badCertificateCallback = (X509Certificate cert, String host, int port) => true;
    }

    _lastProxyConfig = configString;
    _currentClient = IOClient(innerClient);
    return _currentClient!;
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _getClient().send(request);
  }
}
