import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';

class MusicMoodPills extends StatelessWidget {
  final String selectedMood;
  final ValueChanged<String> onMoodSelected;

  const MusicMoodPills({
    super.key,
    required this.selectedMood,
    required this.onMoodSelected,
  });

  static const List<Map<String, String>> moods = [
    {'id': 'all', 'label': '⚡ Todos'},
    {'id': 'chill', 'label': '🌴 Chill & Sunset'},
    {'id': 'urbana', 'label': '🔥 Urbana & Trap'},
    {'id': 'lofi', 'label': '🎧 Lo-Fi Beats'},
    {'id': 'synthwave', 'label': '🚀 Synthwave 80s'},
    {'id': 'rock', 'label': '🎸 Rock & Indie'},
    {'id': 'pop', 'label': '✨ Pop Hits'},
    {'id': 'party', 'label': '🎉 Fiesta & Mix'},
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: moods.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final m = moods[index];
          final isSelected = m['id'] == selectedMood;

          return InkWell(
            borderRadius: BorderRadius.circular(19),
            onTap: () => onMoodSelected(m['id']!),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                gradient: isSelected ? c.primaryGradient : null,
                color: isSelected ? null : c.surface,
                borderRadius: BorderRadius.circular(19),
                border: Border.all(
                  color: isSelected ? Colors.transparent : c.glassBorder,
                  width: 1,
                ),
                boxShadow: [
                  if (isSelected)
                    BoxShadow(
                      color: c.primary.withOpacity(0.4),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    )
                  else if (!c.isDark)
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                ],
              ),
              child: Center(
                child: Text(
                  m['label']!,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                    color: isSelected ? Colors.white : c.textSecondary,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
