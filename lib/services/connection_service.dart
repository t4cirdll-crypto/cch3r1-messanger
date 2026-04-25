import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Стрим онлайн-статуса устройства.
final StreamProvider<bool> connectivityProvider = StreamProvider<bool>((Ref ref) {
  final Connectivity connectivity = Connectivity();
  final StreamController<bool> controller = StreamController<bool>.broadcast();

  // Текущее состояние при подписке.
  connectivity.checkConnectivity().then(
    (List<ConnectivityResult> result) => controller.add(_isOnline(result)),
  );

  final StreamSubscription<List<ConnectivityResult>> sub =
      connectivity.onConnectivityChanged.listen(
    (List<ConnectivityResult> result) => controller.add(_isOnline(result)),
  );

  ref.onDispose(() {
    sub.cancel();
    controller.close();
  });

  return controller.stream;
});

bool _isOnline(List<ConnectivityResult> result) {
  return result.any(
    (ConnectivityResult r) => r != ConnectivityResult.none,
  );
}
