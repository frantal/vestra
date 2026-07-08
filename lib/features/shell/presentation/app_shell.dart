import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import 'widgets/vestra_bottom_bar.dart';

/// Root navigation shell hosting the persistent bottom bar.
///
/// Wraps the [StatefulNavigationShell] provided by GoRouter so each tab keeps
/// its own navigation state across switches.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _goBranch(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: navigationShell,
      bottomNavigationBar: VestraBottomBar(
        currentIndex: navigationShell.currentIndex,
        onTap: _goBranch,
        onAddTap: () => context.pushNamed('add'),
      ),
    );
  }
}
