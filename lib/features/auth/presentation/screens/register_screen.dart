import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/utils/username_mapper.dart';
import '../../../../core/utils/validators.dart';
import '../providers/auth_providers.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _username = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _password2 = TextEditingController();
  bool _obscure = true;
  bool _busy = false;
  bool _checking = false;
  bool? _usernameAvailable;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    _password2.dispose();
    super.dispose();
  }

  Future<void> _checkUsername() async {
    final String value = _username.text;
    if (!UsernameMapper.isValid(value)) {
      _snack(AppStrings.errorUsernameFormat);
      return;
    }
    setState(() => _checking = true);
    try {
      final bool available =
          await ref.read(authControllerProvider.notifier).checkUsername(value);
      setState(() => _usernameAvailable = available);
      _snack(
        available ? AppStrings.usernameAvailable : AppStrings.errorUsernameTaken,
      );
    } catch (e) {
      _snack('${AppStrings.somethingWentWrong}: $e');
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);
    try {
      await ref.read(authControllerProvider.notifier).signUp(
            username: _username.text,
            password: _password.text,
          );
    } on UsernameTakenException {
      _snack(AppStrings.errorUsernameTaken);
    } on AuthException catch (e) {
      _snack(e.message);
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
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.signUpTitle)),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _username,
                      decoration: InputDecoration(
                        labelText: AppStrings.usernameLabel,
                        hintText: AppStrings.usernameHint,
                        prefixIcon: const Icon(Icons.alternate_email),
                        suffixIcon: _usernameAvailable == null
                            ? null
                            : Icon(
                                _usernameAvailable!
                                    ? Icons.check_circle
                                    : Icons.cancel,
                                color: _usernameAvailable!
                                    ? Colors.green
                                    : Theme.of(context).colorScheme.error,
                              ),
                      ),
                      textInputAction: TextInputAction.next,
                      validator: Validators.username,
                      onChanged: (_) {
                        if (_usernameAvailable != null) {
                          setState(() => _usernameAvailable = null);
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: _checking ? null : _checkUsername,
                        icon: _checking
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.search),
                        label: const Text(AppStrings.usernameCheck),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _password,
                      obscureText: _obscure,
                      decoration: InputDecoration(
                        labelText: AppStrings.passwordLabel,
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscure ? Icons.visibility : Icons.visibility_off,
                          ),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      textInputAction: TextInputAction.next,
                      validator: Validators.password,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _password2,
                      obscureText: _obscure,
                      decoration: const InputDecoration(
                        labelText: AppStrings.passwordRepeatLabel,
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                      textInputAction: TextInputAction.done,
                      validator: Validators.passwordMatch(() => _password.text),
                      onFieldSubmitted: (_) => _submit(),
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: _busy
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2.4),
                            )
                          : const Text(AppStrings.signUpButton),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _busy ? null : () => context.go('/login'),
                      child: const Text(AppStrings.goToSignIn),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
