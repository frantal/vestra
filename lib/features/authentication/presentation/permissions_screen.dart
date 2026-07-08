import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/glow_button.dart';

/// A permission the app requests during setup.
class _PermissionItem {
  const _PermissionItem({
    required this.icon,
    required this.title,
    required this.description,
    this.optional = false,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool optional;
}

/// Permissions screen shown after login (UI only for now).
///
/// Actual OS permission requests (via `permission_handler`) are wired in a
/// later phase; toggles here reflect the user's intent.
class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({super.key});

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen> {
  static const List<_PermissionItem> _items = [
    _PermissionItem(
      icon: Icons.photo_camera_rounded,
      title: 'Câmara',
      description: 'Para fotografar e reconhecer as suas peças.',
    ),
    _PermissionItem(
      icon: Icons.photo_library_rounded,
      title: 'Fotos',
      description: 'Para importar roupas da sua galeria.',
    ),
    _PermissionItem(
      icon: Icons.notifications_rounded,
      title: 'Notificações',
      description: 'Lembretes de lavagem, clima e sugestões.',
    ),
    _PermissionItem(
      icon: Icons.location_on_rounded,
      title: 'Localização',
      description: 'Recomendações de acordo com o clima.',
    ),
    _PermissionItem(
      icon: Icons.calendar_month_rounded,
      title: 'Calendário',
      description: 'Sugestões para os seus eventos.',
      optional: true,
    ),
  ];

  final Set<int> _granted = {0, 1, 2, 3};

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
              Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Permissões', style: theme.textTheme.displayMedium),
                    AppSpacing.gapSm,
                    Text(
                      'A VESTRA precisa de alguns acessos para funcionar '
                      'plenamente.',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xl,
                  ),
                  itemCount: _items.length,
                  separatorBuilder: (_, __) => AppSpacing.gapMd,
                  itemBuilder: (context, i) {
                    final item = _items[i];
                    final bool granted = _granted.contains(i);
                    return GlassCard(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: const BoxDecoration(
                              borderRadius: AppRadius.brMd,
                              color: AppColors.glass,
                            ),
                            child: Icon(item.icon, color: AppColors.primary),
                          ),
                          AppSpacing.gapLg,
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        item.title,
                                        style: theme.textTheme.titleMedium,
                                      ),
                                    ),
                                    if (item.optional) ...[
                                      AppSpacing.gapSm,
                                      Text(
                                        '(opcional)',
                                        style: theme.textTheme.labelMedium,
                                      ),
                                    ],
                                  ],
                                ),
                                AppSpacing.gapXs,
                                Text(
                                  item.description,
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: granted,
                            onChanged: (v) => setState(() {
                              if (v) {
                                _granted.add(i);
                              } else {
                                _granted.remove(i);
                              }
                            }),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: GlowButton(
                  label: 'Continuar',
                  onPressed: () => context.go(AppRoutes.home),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
