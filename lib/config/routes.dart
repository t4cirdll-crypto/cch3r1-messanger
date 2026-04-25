import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Session;

import '../core/providers/supabase_providers.dart';
import '../features/auth/domain/entities/profile_entity.dart';
import '../features/auth/presentation/providers/auth_providers.dart';
import '../features/auth/presentation/screens/login_screen.dart';
import '../features/auth/presentation/screens/register_screen.dart';
import '../features/auth/presentation/screens/splash_screen.dart';
import '../features/chat/presentation/screens/chat_screen.dart';
import '../features/chat_list/domain/entities/conversation_entity.dart';
import '../features/chat_list/presentation/screens/chat_list_screen.dart';
import '../features/profile/presentation/screens/profile_screen.dart';
import '../features/search_user/presentation/screens/search_user_screen.dart';

/// GoRouter с редиректом по сессии Supabase.
final Provider<GoRouter> routerProvider = Provider<GoRouter>((Ref ref) {
  final _AuthRouterListenable listenable = _AuthRouterListenable(ref);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: listenable,
    redirect: (BuildContext _, GoRouterState state) {
      final AsyncValue<ProfileEntity?> auth = ref.read(authControllerProvider);
      final String? userId = ref.read(currentUserIdProvider);

      // Пока сессия инициализируется — показываем splash.
      if (auth.isLoading) {
        return state.matchedLocation == '/splash' ? null : '/splash';
      }
      final bool loggedIn = userId != null;
      final bool atAuth = state.matchedLocation == '/login' ||
          state.matchedLocation == '/register';

      if (!loggedIn) {
        return atAuth ? null : '/login';
      }
      if (loggedIn && (atAuth || state.matchedLocation == '/splash')) {
        return '/';
      }
      return null;
    },
    routes: <RouteBase>[
      GoRoute(
        path: '/splash',
        builder: (_, __) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (_, __) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/',
        builder: (_, __) => const ChatListScreen(),
      ),
      GoRoute(
        path: '/search',
        builder: (_, __) => const SearchUserScreen(),
      ),
      GoRoute(
        path: '/profile',
        builder: (_, __) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/chat/:id',
        builder: (BuildContext _, GoRouterState state) {
          final String id = state.pathParameters['id']!;
          final ConversationEntity? conv =
              state.extra is ConversationEntity
                  ? state.extra! as ConversationEntity
                  : null;
          return ChatScreen(conversationId: id, conversation: conv);
        },
      ),
    ],
    errorBuilder: (BuildContext _, GoRouterState state) => Scaffold(
      appBar: AppBar(title: const Text('Ошибка')),
      body: Center(child: Text(state.error?.message ?? 'Маршрут не найден')),
    ),
  );
});

/// Триггерит ребилд GoRouter при изменении состояния аутентификации.
class _AuthRouterListenable extends ChangeNotifier {
  _AuthRouterListenable(this._ref) {
    _ref.listen<AsyncValue<ProfileEntity?>>(
      authControllerProvider,
      (AsyncValue<ProfileEntity?>? prev, AsyncValue<ProfileEntity?> next) {
        notifyListeners();
      },
    );
    _ref.listen<Session?>(
      currentSessionProvider,
      (Session? prev, Session? next) => notifyListeners(),
    );
  }

  final Ref _ref;
}
