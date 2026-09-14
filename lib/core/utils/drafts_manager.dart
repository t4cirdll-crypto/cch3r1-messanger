import 'package:shared_preferences/shared_preferences.dart';

import 'prefs_init.dart';

class DraftsManager {
  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs ??= await getSharedPreferencesSafely();
  }

  static String? _key(String conversationId, String? accountId) {
    if (accountId == null || accountId.isEmpty) return null;
    return 'draft.v2:${Uri.encodeComponent(accountId)}:${Uri.encodeComponent(conversationId)}';
  }

  static String? getDraft(String conversationId, {required String? accountId}) {
    final String? key = _key(conversationId, accountId);
    return key == null ? null : _prefs?.getString(key);
  }

  static Future<void> saveDraft(String conversationId, String text,
      {required String? accountId}) async {
    final String? key = _key(conversationId, accountId);
    if (key == null) return;
    if (text.trim().isEmpty) {
      await _prefs?.remove(key);
    } else {
      await _prefs?.setString(key, text);
    }
  }

  static Future<void> clearDraft(String conversationId,
      {required String? accountId}) async {
    final String? key = _key(conversationId, accountId);
    if (key != null) await _prefs?.remove(key);
  }
}
