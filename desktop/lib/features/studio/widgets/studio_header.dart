import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';
import '../../../core/services/api_service.dart';

class StudioHeader extends StatelessWidget {
  final ApiService api;

  const StudioHeader({super.key, required this.api});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: c.primary.withOpacity(0.35),
                blurRadius: 16,
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Image.asset(
            'assets/images/logo.png',
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Titofy',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: c.textPrimary,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Transcripción y sincronización de audio',
              style: TextStyle(
                fontSize: 12,
                color: c.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: api.isOnline ? const Color(0xFF142C1E) : const Color(0xFF2C1E14),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: api.isOnline
                  ? const Color(0xFF22C55E).withOpacity(0.35)
                  : const Color(0xFFF59E0B).withOpacity(0.35),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: api.isOnline ? const Color(0xFF22C55E) : const Color(0xFFF59E0B),
                ),
              ),
              const SizedBox(width: 7),
              Text(
                api.isOnline ? 'Motor disponible' : 'Motor desconectado',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: api.isOnline ? const Color(0xFF4ADE80) : const Color(0xFFFBBF24),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
