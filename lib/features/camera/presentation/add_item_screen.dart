import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_states.dart';

/// Full-screen "add" flow launched from the central bottom-bar button.
///
/// In later phases this hosts the capture options (photograph piece, photograph
/// outfit, import from gallery) and the AI recognition flow.
class AddItemScreen extends StatelessWidget {
  const AddItemScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Adicionar'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: const DecoratedBox(
        decoration: BoxDecoration(gradient: AppColors.backgroundGradient),
        child: AppEmptyState(
          icon: Icons.add_a_photo_rounded,
          title: 'Adicionar peça',
          message: 'Fotografar peça, fotografar outfit ou importar da galeria '
              'aparecerá aqui.',
        ),
      ),
    );
  }
}
