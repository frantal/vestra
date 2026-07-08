import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/glow_button.dart';
import '../application/auth_providers.dart';

/// Account creation screen.
///
/// Creates a Supabase account when a backend is configured; otherwise it
/// advances the navigation flow (UI/dev mode).
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  bool _obscure = true;
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _createAccount() async {
    final repo = ref.read(authRepositoryProvider);
    if (repo == null) {
      context.go(AppRoutes.permissions);
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await repo.signUpWithEmail(
        email: _email.text.trim(),
        password: _password.text,
        fullName: _name.text.trim().isEmpty ? null : _name.text.trim(),
      );
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Criar conta')),
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
                    Text(
                      'Vamos começar',
                      style: theme.textTheme.headlineMedium,
                    ),
                    AppSpacing.gapSm,
                    Text(
                      'Crie a sua conta VESTRA.',
                      style: theme.textTheme.bodyMedium,
                    ),
                    AppSpacing.gapXl,
                    AppTextField(
                      label: 'Nome',
                      hint: 'O seu nome',
                      controller: _name,
                      icon: Icons.person_outline_rounded,
                      textInputAction: TextInputAction.next,
                    ),
                    AppSpacing.gapLg,
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
                      onSubmitted: (_) => _createAccount(),
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
                    AppSpacing.gapXl,
                    if (_error != null) ...[
                      Text(
                        _error!,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: AppColors.error),
                      ),
                      AppSpacing.gapMd,
                    ],
                    GlowButton(
                      label: 'Criar conta',
                      isLoading: _isLoading,
                      onPressed: _createAccount,
                    ),
                    AppSpacing.gapLg,
                    Text(
                      'Ao criar conta aceita os Termos e a Política de '
                      'Privacidade.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelMedium,
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
