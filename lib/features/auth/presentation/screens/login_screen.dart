import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/glass_widgets.dart';
import '../providers/auth_providers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _username = TextEditingController();
  final TextEditingController _password = TextEditingController();
  bool _obscure = true;
  bool _busy = false;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);
    try {
      await ref.read(authControllerProvider.notifier).signIn(
            username: _username.text,
            password: _password.text,
          );
    } on AuthException {
      _snack(AppStrings.errorInvalidCredentials);
    } catch (e) {
      _snack('${AppStrings.somethingWentWrong}: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: GlassmorphicCard(
                blur: 24,
                borderRadius: AppRadius.xl,
                padding: const EdgeInsets.all(AppSpacing.xxl),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      AnimatedScale(
                        scale: _busy ? 0.94 : 1,
                        duration: AppDurations.normal,
                        curve: AppCurves.spring,
                        child: Center(
                          child: Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              color: scheme.primaryContainer,
                              borderRadius: AppRadius.lgAll,
                            ),
                            child: Icon(
                              Icons.forum_rounded,
                              size: 36,
                              color: scheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        AppStrings.appName,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        AppStrings.signInTitle,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxl + AppSpacing.xs),
                      TextFormField(
                        controller: _username,
                        autofillHints: const <String>[
                          AutofillHints.username,
                        ],
                        decoration: const InputDecoration(
                          labelText: AppStrings.usernameLabel,
                          hintText: AppStrings.usernameHint,
                          prefixIcon: Icon(Icons.alternate_email),
                        ),
                        textInputAction: TextInputAction.next,
                        validator: Validators.username,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      TextFormField(
                        controller: _password,
                        obscureText: _obscure,
                        autofillHints: const <String>[
                          AutofillHints.password,
                        ],
                        decoration: InputDecoration(
                          labelText: AppStrings.passwordLabel,
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                            icon: Icon(
                              _obscure
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                          ),
                        ),
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _submit(),
                        validator: Validators.password,
                      ),
                      const SizedBox(height: AppSpacing.xxl),
                      FilledButton(
                        onPressed: _busy ? null : _submit,
                        child: AnimatedSwitcher(
                          duration: AppDurations.fast,
                          switchInCurve: AppCurves.standard,
                          switchOutCurve: AppCurves.standard,
                          child: _busy
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.4,
                                  ),
                                )
                              : const Text(AppStrings.signInButton),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextButton(
                        onPressed: _busy ? null : () => context.go('/register'),
                        child: const Text(AppStrings.goToSignUp),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
