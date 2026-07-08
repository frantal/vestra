import 'package:flutter/material.dart';

import '../../../shared/widgets/feature_placeholder.dart';

/// Home / Dashboard tab. Real summary content lands in a later phase.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeaturePlaceholder(
      title: 'Home',
      icon: Icons.home_rounded,
      message: 'O seu resumo diário aparecerá aqui.',
    );
  }
}
