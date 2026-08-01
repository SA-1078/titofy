import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.settings_rounded, size: 48, color: AppColors.textMuted),
            SizedBox(height: 12),
            Text('Ajustes', style: TextStyle(color: AppColors.textMuted)),
            SizedBox(height: 4),
            Text('Próximamente', style: TextStyle(color: AppColors.textDisabled, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
