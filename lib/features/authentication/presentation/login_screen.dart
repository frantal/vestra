import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/glow_button.dart';
import '../../../shared/widgets/social_button.dart';
import '../application/auth_providers.dart';
import '../domain/auth_repository.dart';

/// Login screen.
///
/// Uses the [AuthRepository] when a backend is configured; otherwise it simply
/// advances the navigation flow (UI/dev mode).
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  bool _obscure = true;
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit(Future<void> Function(AuthRepository repo) action) async {
    final repo = ref.read(authRepositoryProvider);
    if (repo == null) {
      // No backend configured: keep the flow moving in UI/dev mode.
      context.go(AppRoutes.permissions);
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await action(repo);
      if (mounted) context.go(AppRoutes.permissions);
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Ocorreu um erro. Tente novamente.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _signInEmail() => _submit(
        (repo) => repo.signInWithEmail(
          email: _email.text.trim(),
          password: _password.text,
        ),
      );

  void _signInGoogle() => _submit((repo) => repo.signInWithGoogle());

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: AppColors.backgroundGradient,
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Bem-vindo de volta', style: theme.textTheme.displayMedium),
                    AppSpacing.gapSm,
                    Text(
                      'Entre para aceder ao seu guarda-roupa.',
                      style: theme.textTheme.bodyMedium,
                    ),
                    AppSpacing.gapXl,
                    AppTextField(
                      label: 'Email',
                      hint: 'nome@email.com',
                      controller: _email,
                      icon: Icons.mail_outline_rounded,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                    ),
                    AppSpacing.gapLg,
                    AppTextField(
                      label: 'Senha',
                      hint: '••••••••',
                      controller: _password,
                      icon: Icons.lock_outline_rounded,
                      obscureText: _obscure,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _signInEmail(),
                      suffix: IconButton(
                        icon: Icon(
                          _obscure
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                          color: AppColors.textTertiary,
                        ),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {},
                        child: const Text('Esqueci a senha'),
                      ),
                    ),
                    if (_error != null) ...[
                      AppSpacing.gapSm,
                      Text(
                        _error!,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: AppColors.error),
                      ),
                    ],
                    AppSpacing.gapMd,
                    GlowButton(
                      label: 'Entrar',
                      isLoading: _isLoading,
                      onPressed: _signInEmail,
                    ),
                    AppSpacing.gapXl,
                    const _OrDivider(),
                    AppSpacing.gapLg,
                    SocialButton(
                      label: 'Continuar com Google',
                      icon: Icons.g_mobiledata_rounded,
                      onPressed: _signInGoogle,
                    ),
                    AppSpacing.gapMd,
                    SocialButton(
                      label: 'Continuar com Apple',
                      icon: Icons.apple_rounded,
                      onPressed: _signInGoogle,
                    ),
                    AppSpacing.gapMd,
                    SocialButton(
                      label: 'Continuar com Facebook',
                      icon: Icons.facebook_rounded,
                      onPressed: _signInGoogle,
                    ),
                    AppSpacing.gapXl,
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Não tem conta?',
                          style: theme.textTheme.bodyMedium,
                        ),
                        TextButton(
                          onPressed: () => context.push(AppRoutes.register),
                          child: const Text('Criar conta'),
                        ),
                      ],
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

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: AppColors.border)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Text('ou', style: Theme.of(context).textTheme.labelMedium),
        ),
        const Expanded(child: Divider(color: AppColors.border)),
      ],
    );
  }
}
