/// Маппер username → synthetic email.
///
/// Supabase Auth требует email, но пользователь вводит только ник.
/// Мы создаём «фейковый» email формата `${username}@local.app`, который
/// клиент нигде не показывает.
class UsernameMapper {
  const UsernameMapper._();

  static const String domain = 'local.app';
  static final RegExp _re = RegExp(r'^[a-zA-Z0-9_]{3,20}$');

  static String normalize(String raw) => raw.trim().toLowerCase();

  static bool isValid(String raw) => _re.hasMatch(normalize(raw));

  /// `alex_01` → `alex_01@local.app`
  static String toEmail(String username) => '${normalize(username)}@$domain';

  /// `alex_01@local.app` → `alex_01`
  static String? fromEmail(String? email) {
    if (email == null) return null;
    final int at = email.indexOf('@');
    if (at <= 0) return null;
    final String local = email.substring(0, at);
    return isValid(local) ? local : null;
  }
}
