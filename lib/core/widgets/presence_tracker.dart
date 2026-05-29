import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/providers/auth_providers.dart';
import '../providers/supabase_providers.dart';

class PresenceTracker extends ConsumerStatefulWidget {
  const PresenceTracker({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  ConsumerState<PresenceTracker> createState() => _PresenceTrackerState();
}

class _PresenceTrackerState extends ConsumerState<PresenceTracker>
    with WidgetsBindingObserver {
  Timer? _heartbeatTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Initial update
    _updatePresence(true);
    _startHeartbeat();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopHeartbeat();
    _updatePresence(false);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _updatePresence(true);
      _startHeartbeat();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _stopHeartbeat();
      _updatePresence(false);
    }
  }

  void _startHeartbeat() {
    _stopHeartbeat();
    _heartbeatTimer = Timer.periodic(const Duration(minutes: 1), (Timer timer) {
      _updatePresence(true);
    });
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  Future<void> _updatePresence(bool online) async {
    final String? userId = ref.read(currentUserIdProvider);
    if (userId == null) {
      return;
    }

    try {
      final repo = await ref.read(authRepositoryProvider.future);
      await repo.setOnline(online);
    } catch (e) {
      debugPrint('Failed to update presence state: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Listen to changes in user ID to trigger online state immediately on login
    ref.listen<String?>(currentUserIdProvider, (String? prev, String? curr) {
      if (curr != null && prev != curr) {
        _updatePresence(true);
        _startHeartbeat();
      } else if (curr == null && prev != null) {
        _stopHeartbeat();
      }
    });

    return widget.child;
  }
}
