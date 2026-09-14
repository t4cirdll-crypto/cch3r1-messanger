import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cch3r1_messanger/core/constants/app_strings.dart';
import 'package:cch3r1_messanger/core/errors/exceptions.dart';
import 'package:cch3r1_messanger/core/providers/supabase_providers.dart';
import 'package:cch3r1_messanger/features/auth/domain/entities/profile_entity.dart';
import 'package:cch3r1_messanger/features/auth/domain/repositories/auth_repository.dart';
import 'package:cch3r1_messanger/features/auth/presentation/providers/auth_providers.dart';
import 'package:cch3r1_messanger/features/auth/presentation/screens/login_screen.dart';

class _AuthRepository implements AuthRepository {
  final Completer<ProfileEntity> signInResult = Completer<ProfileEntity>();
  int signInCalls = 0;

  @override
  Future<ProfileEntity> signIn(
      {required String username, required String password}) {
    signInCalls++;
    return signInResult.future;
  }

  @override
  Future<ProfileEntity> signUp(
          {required String username, required String password}) async =>
      throw const UsernameTakenException();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ProviderContainer _container(_AuthRepository repository) => ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWith((_) async => repository),
        currentUserIdProvider.overrideWithValue(null),
        currentSessionProvider.overrideWithValue(null),
      ],
    );

void main() {
  test(
      'failed registration reaches the caller without replacing the auth state',
      () async {
    final ProviderContainer container = _container(_AuthRepository());
    addTearDown(container.dispose);
    await container.read(authControllerProvider.future);
    final List<AsyncValue<ProfileEntity?>> states = [];
    final subscription =
        container.listen(authControllerProvider, (_, next) => states.add(next));
    addTearDown(subscription.close);

    await expectLater(
        container.read(authControllerProvider.notifier).signUp(
              username: 'taken',
              password: 'password',
            ),
        throwsA(isA<UsernameTakenException>()));
    expect(container.read(authControllerProvider).valueOrNull, isNull);
    expect(states.any((state) => state.isLoading || state.hasError), isFalse);
  });

  testWidgets(
      'repeated keyboard submit sends once and preserves fields on error',
      (tester) async {
    final _AuthRepository repository = _AuthRepository();
    final ProviderContainer container = _container(repository);
    addTearDown(container.dispose);
    await container.read(authControllerProvider.future);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: LoginScreen()),
    ));
    await tester.pumpAndSettle();
    final Finder fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'alina');
    await tester.enterText(fields.at(1), 'wrong-password');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(repository.signInCalls, 1);
    expect(container.read(authControllerProvider).isLoading, isFalse);

    repository.signInResult
        .completeError(const AuthException('Invalid credentials'));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.errorInvalidCredentials), findsOneWidget);
    expect(
        tester.widget<TextFormField>(fields.at(0)).controller!.text, 'alina');
    expect(tester.widget<TextFormField>(fields.at(1)).controller!.text,
        'wrong-password');
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
