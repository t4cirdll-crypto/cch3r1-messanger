import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/entities/admin_entities.dart';

/// Все запросы админки идут через RPCs (SECURITY DEFINER на сервере).
class AdminRepository {
  AdminRepository(this._client);
  final SupabaseClient _client;

  Future<bool> isAdmin() async {
    try {
      final dynamic res = await _client.rpc<dynamic>('fn_is_admin');
      return res == true;
    } catch (_) {
      return false;
    }
  }

  Future<String?> selfDeviceId() async {
    try {
      final dynamic res =
          await _client.rpc<dynamic>('fn_admin_self_device_id');
      return res is String ? res : null;
    } catch (_) {
      return null;
    }
  }

  Future<AdminStats> stats() async {
    final dynamic res = await _client.rpc<dynamic>('fn_admin_stats');
    return AdminStats.fromJson((res as Map).cast<String, dynamic>());
  }

  Future<List<AdminUser>> users() async {
    final dynamic res = await _client.rpc<dynamic>('fn_admin_users_list');
    final List<dynamic> rows = (res as List<dynamic>?) ?? const <dynamic>[];
    return rows
        .cast<Map<String, dynamic>>()
        .map(AdminUser.fromJson)
        .toList();
  }

  Future<List<AdminConversation>> conversations() async {
    final dynamic res =
        await _client.rpc<dynamic>('fn_admin_conversations_list');
    final List<dynamic> rows = (res as List<dynamic>?) ?? const <dynamic>[];
    return rows
        .cast<Map<String, dynamic>>()
        .map(AdminConversation.fromJson)
        .toList();
  }

  Future<List<AdminMessage>> messages(String conversationId,
      {int limit = 200}) async {
    final dynamic res = await _client.rpc<dynamic>(
      'fn_admin_messages',
      params: <String, dynamic>{
        'p_conv_id': conversationId,
        'p_limit': limit,
      },
    );
    final List<dynamic> rows = (res as List<dynamic>?) ?? const <dynamic>[];
    return rows
        .cast<Map<String, dynamic>>()
        .map(AdminMessage.fromJson)
        .toList();
  }

  Future<void> setBanned({
    required String userId,
    required bool banned,
    String? reason,
  }) async {
    await _client.rpc<dynamic>(
      'fn_admin_set_banned',
      params: <String, dynamic>{
        'p_user_id': userId,
        'p_banned': banned,
        'p_reason': reason,
      },
    );
  }

  Future<void> deleteUser(String userId) async {
    await _client.rpc<dynamic>(
      'fn_admin_delete_user',
      params: <String, dynamic>{'p_user_id': userId},
    );
  }

  Future<void> deleteMessage(String messageId) async {
    await _client.rpc<dynamic>(
      'fn_admin_delete_message',
      params: <String, dynamic>{'p_message_id': messageId},
    );
  }

  Future<void> resetPassword({
    required String userId,
    required String newPassword,
  }) async {
    await _client.rpc<dynamic>(
      'fn_admin_reset_password',
      params: <String, dynamic>{
        'p_user_id': userId,
        'p_new_password': newPassword,
      },
    );
  }

  Future<int> broadcast(String text) async {
    final dynamic res = await _client.rpc<dynamic>(
      'fn_admin_broadcast',
      params: <String, dynamic>{'p_text': text},
    );
    if (res is int) return res;
    if (res is num) return res.toInt();
    return 0;
  }
}
