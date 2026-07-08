import 'package:flutter/material.dart';

import '../../../shared/widgets/feature_placeholder.dart';

/// Wardrobe tab. Clothing catalogue and filters land in a later phase.
class WardrobeScreen extends StatelessWidget {
  const WardrobeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const FeaturePlaceholder(
      title: 'Guarda-Roupa',
      icon: Icons.checkroom_rounded,
      message: 'As suas peças, por categorias, aparecerão aqui.',
    );
  }
}
