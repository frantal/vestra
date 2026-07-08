import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// A single destination in the [VestraBottomBar].
class VestraBottomBarItem {
  const VestraBottomBarItem({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

/// Custom bottom navigation bar for VESTRA.
///
/// Renders four tab destinations plus a central elevated "+" action that is not
/// itself a tab. Positions map to the bar like: [0,1, +, 2,3].
class VestraBottomBar extends StatelessWidget {
  const VestraBottomBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.onAddTap,
  });

  /// Index of the active branch (0..3).
  final int currentIndex;
  final ValueChanged<int> onTap;
  final VoidCallback onAddTap;

  static const List<VestraBottomBarItem> _items = [
    VestraBottomBarItem(icon: Icons.home_rounded, label: 'Home'),
    VestraBottomBarItem(icon: Icons.checkroom_rounded, label: 'Guarda-Roupa'),
    VestraBottomBarItem(icon: Icons.auto_awesome_rounded, label: 'IA'),
    VestraBottomBarItem(icon: Icons.person_rounded, label: 'Perfil'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              _tab(0),
              _tab(1),
              _AddButton(onTap: onAddTap),
              _tab(2),
              _tab(3),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tab(int index) {
    final bool selected = index == currentIndex;
    final Color color =
        selected ? AppColors.primary : AppColors.textTertiary;
    final item = _items[index];

    return Expanded(
      child: InkResponse(
        onTap: () => onTap(index),
        radius: 40,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(item.icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppColors.primaryGradient,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.4),
                  blurRadius: 18,
                  spreadRadius: -2,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(
              Icons.add_rounded,
              color: AppColors.background,
              size: 28,
            ),
          ),
        ),
      ),
    );
  }
}
