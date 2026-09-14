import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:cch3r1_messanger/config/theme.dart';
import 'package:cch3r1_messanger/core/providers/supabase_providers.dart';
import 'package:cch3r1_messanger/core/utils/drafts_manager.dart';
import 'package:cch3r1_messanger/features/chat/presentation/providers/chat_providers.dart';
import 'package:cch3r1_messanger/features/chat/presentation/screens/chat_screen.dart';
import 'package:cch3r1_messanger/features/chat/presentation/screens/in_chat_search_screen.dart';
import 'package:cch3r1_messanger/features/chat_list/presentation/providers/chat_list_providers.dart';
import 'package:cch3r1_messanger/features/chat_list/presentation/screens/chat_list_screen.dart';
import 'package:cch3r1_messanger/features/search_user/presentation/providers/search_providers.dart';
import 'package:cch3r1_messanger/features/search_user/presentation/screens/search_user_screen.dart';
import 'package:cch3r1_messanger/services/connection_service.dart';

import 'preview_data.dart';

Future<void> main() async {
  final WidgetsBinding binding = WidgetsFlutterBinding.ensureInitialized();
  binding.ensureSemantics();
  await initializeDateFormatting('ru');
  await DraftsManager.init();
  final PreviewStore store = PreviewStore();
  runApp(ProviderScope(
    overrides: [
      currentUserIdProvider.overrideWithValue(previewUserId),
      supabaseClientProvider.overrideWith((_) =>
          throw StateError('Supabase отключён в изолированном UI-превью')),
      chatListRepositoryProvider.overrideWith((_) async => store),
      chatRepositoryProvider.overrideWith((_) async => store),
      connectivityProvider.overrideWith((_) => Stream<bool>.value(true)),
      typingChannelProvider.overrideWith((_, __) => PreviewTypingChannel()),
      searchResultsProvider.overrideWith((ref) async {
        final String query =
            ref.watch(searchQueryProvider).trim().toLowerCase();
        return query.length < 2
            ? []
            : previewPeople.where((p) => p.username.contains(query)).toList();
      }),
    ],
    child: _PreviewApp(store: store),
  ));
}

class _PreviewApp extends ConsumerStatefulWidget {
  const _PreviewApp({required this.store});
  final PreviewStore store;

  @override
  ConsumerState<_PreviewApp> createState() => _PreviewAppState();
}

class _PreviewAppState extends ConsumerState<_PreviewApp> {
  bool _dark = false;
  late final GoRouter _router = GoRouter(routes: <RouteBase>[
    GoRoute(path: '/', builder: (_, __) => const ChatListScreen()),
    GoRoute(
        path: '/chat/:id',
        builder: (_, state) => ChatScreen(
              conversationId: state.pathParameters['id']!,
              conversation:
                  widget.store.conversation(state.pathParameters['id']!),
            ),
        routes: <RouteBase>[
          GoRoute(
              path: 'search',
              builder: (_, state) => InChatSearchScreen(
                  conversationId: state.pathParameters['id']!)),
        ]),
    GoRoute(path: '/search', builder: (_, __) => const SearchUserScreen()),
    for (final String path in ['/profile', '/group/new'])
      GoRoute(path: path, builder: (_, __) => const _PreviewLimitScreen()),
  ]);

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp.router(
        title: 'cch3r1 — локальное UI-превью',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(null),
        darkTheme: AppTheme.dark(null),
        themeMode: _dark ? ThemeMode.dark : ThemeMode.light,
        routerConfig: _router,
        builder: (BuildContext context, Widget? child) =>
            Column(children: <Widget>[
          Material(
            color: Theme.of(context).colorScheme.surfaceContainerHigh,
            child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(children: <Widget>[
                    Expanded(
                        child: Text('ДЕМО · локальные данные',
                            style: Theme.of(context).textTheme.labelSmall)),
                    IconButton(
                      tooltip: 'Сбросить демоданные',
                      icon: const Icon(Icons.restart_alt, size: 20),
                      onPressed: () {
                        widget.store.reset();
                        ref.invalidate(chatListControllerProvider);
                        ref.invalidate(chatControllerProvider);
                        _router.go('/');
                      },
                    ),
                    IconButton(
                      tooltip: _dark ? 'Светлая тема' : 'Тёмная тема',
                      onPressed: () => setState(() => _dark = !_dark),
                      icon: Icon(
                          _dark
                              ? Icons.light_mode_outlined
                              : Icons.dark_mode_outlined,
                          size: 20),
                    ),
                  ]),
                )),
          ),
          Expanded(child: child!),
        ]),
      );
}

class _PreviewLimitScreen extends StatelessWidget {
  const _PreviewLimitScreen();

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Локальное UI-превью')),
        body: const Center(
            child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
              'В превью доступны список диалогов, поиск и текстовая переписка. '
              'Профиль, создание групп и вложения проверяются в мобильной сборке. '
              'Подключения к Supabase нет.',
              textAlign: TextAlign.center),
        )),
      );
}
