import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import 'app_states.dart';

/// Temporary scaffold used by feature screens that are not yet implemented.
///
/// Provides a consistent app bar and an [AppEmptyState] so navigation and the
/// design system can be validated end-to-end before real content lands.
class FeaturePlaceholder extends StatelessWidget {
  const FeaturePlaceholder({
    super.key,
    required this.title,
    required this.icon,
    required this.message,
    this.showAppBar = true,
  });

  final String title;
  final IconData icon;
  final String message;
  final bool showAppBar;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: showAppBar
          ? AppBar(title: Text(title))
          : null,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: AppColors.backgroundGradient,
        ),
        child: AppEmptyState(icon: icon, title: title, message: message),
      ),
    );
  }
}
