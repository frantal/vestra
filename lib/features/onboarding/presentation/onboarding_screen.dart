import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/shared_preferences_provider.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/glow_button.dart';

/// Content model for a single onboarding page.
class _OnboardingPage {
  const _OnboardingPage({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;
}

/// Onboarding carousel shown on first launch.
///
/// Presents the product value proposition across four pages, then persists a
/// "seen" flag and routes to login.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _controller = PageController();
  int _index = 0;

  static const List<_OnboardingPage> _pages = [
    _OnboardingPage(
      icon: Icons.checkroom_rounded,
      title: 'Conheça o seu guarda-roupa',
      subtitle: 'Digitalize as suas roupas e tenha tudo organizado num só '
          'lugar.',
    ),
    _OnboardingPage(
      icon: Icons.auto_awesome_rounded,
      title: 'A IA organiza tudo por si',
      subtitle: 'Reconhecimento automático de peças, cores e ocasiões.',
    ),
    _OnboardingPage(
      icon: Icons.wb_sunny_rounded,
      title: 'Sugestões inteligentes todos os dias',
      subtitle: 'Looks recomendados para o clima, o evento e o seu estilo.',
    ),
    _OnboardingPage(
      icon: Icons.rocket_launch_rounded,
      title: 'Comece agora',
      subtitle: 'O seu assistente pessoal de estilo está pronto.',
    ),
  ];

  bool get _isLast => _index == _pages.length - 1;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool(PrefKeys.onboardingSeen, true);
    if (mounted) {
      context.go(AppRoutes.login);
    }
  }

  void _next() {
    if (_isLast) {
      _finish();
    } else {
      _controller.nextPage(
        duration: AppDurations.normal,
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: AppColors.backgroundGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _finish,
                  child: const Text('Saltar'),
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _pages.length,
                  onPageChanged: (i) => setState(() => _index = i),
                  itemBuilder: (context, i) {
                    final page = _pages[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xl,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.glass,
                              border: Border.all(color: AppColors.border),
                            ),
                            child: ShaderMask(
                              shaderCallback: (bounds) => AppColors
                                  .primaryGradient
                                  .createShader(bounds),
                              child: Icon(
                                page.icon,
                                size: 56,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          AppSpacing.gapXl,
                          Text(
                            page.title,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.headlineMedium,
                          ),
                          AppSpacing.gapMd,
                          Text(
                            page.subtitle,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              _Dots(count: _pages.length, index: _index),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: GlowButton(
                  label: _isLast ? 'Começar' : 'Seguinte',
                  onPressed: _next,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final bool active = i == index;
        return AnimatedContainer(
          duration: AppDurations.normal,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: active ? 22 : 8,
          height: 8,
          decoration: BoxDecoration(
            borderRadius: AppRadius.brPill,
            color: active ? AppColors.primary : AppColors.border,
          ),
        );
      }),
    );
  }
}
