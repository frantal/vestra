import 'package:flutter/material.dart';

import '../../../shared/widgets/feature_placeholder.dart';

/// Profile tab. Account, preferences and backup land in a later phase.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeaturePlaceholder(
      title: 'Perfil',
      icon: Icons.person_rounded,
      message: 'Os seus dados e definições aparecerão aqui.',
    );
  }
}
