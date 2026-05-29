import 'package:shared_preferences/shared_preferences.dart';

class DraftsManager {
  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  static String? getDraft(String conversationId) {
    return _prefs?.getString('draft_$conversationId');
  }

  static Future<void> saveDraft(String conversationId, String text) async {
    if (text.trim().isEmpty) {
      await _prefs?.remove('draft_$conversationId');
    } else {
      await _prefs?.setString('draft_$conversationId', text);
    }
  }

  static Future<void> clearDraft(String conversationId) async {
    await _prefs?.remove('draft_$conversationId');
  }
}
