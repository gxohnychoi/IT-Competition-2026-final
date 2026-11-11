import 'package:flutter/material.dart';
import '../core/app_theme.dart';

class MainScaffold extends StatelessWidget {
  final Widget child;
  final int currentIndex;
  final ValueChanged<int> onTabSelected;

  const MainScaffold({
    super.key,
    required this.child,
    required this.currentIndex,
    required this.onTabSelected,
  });

  static const _tabs = [
    (icon: Icons.home_rounded, label: '홈'),
    (icon: Icons.show_chart_rounded, label: '성장'),
    (icon: Icons.notifications_rounded, label: '알림'),
    (icon: Icons.settings_rounded, label: '설정'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(child: child),
      bottomNavigationBar: BottomAppBar(
        color: Colors.white,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            for (int i = 0; i < _tabs.length; i++)
              _NavItem(
                icon: _tabs[i].icon,
                label: _tabs[i].label,
                selected: currentIndex == i,
                onTap: () => onTabSelected(i),
              ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({required this.icon, required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primaryGreen : AppColors.textSecondary;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(color: color, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}
