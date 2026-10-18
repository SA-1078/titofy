import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';
import '../../../core/services/library_service.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/locale_service.dart';
import '../../../shell/window_controls.dart';

/// Barra Superior de MusicPage: Navegación, Buscador, Estado IA y WindowControls
class MusicTopBar extends StatelessWidget {
  final TextEditingController searchCtrl;
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final LibraryService library;
  final ApiService api;
  final LocaleService loc;

  const MusicTopBar({
    super.key,
    required this.searchCtrl,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.library,
    required this.api,
    required this.loc,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Row(
        children: [
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back_ios_rounded, size: 15, color: c.textSecondary),
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(8),
                splashRadius: 18,
                onPressed: () {},
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: Icon(Icons.arrow_forward_ios_rounded, size: 15, color: c.textMuted),
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(8),
                splashRadius: 18,
                onPressed: () {},
              ),
            ],
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: c.glassBorder),
                boxShadow: [
                  if (!c.isDark)
                    BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  Icon(Icons.search_rounded, size: 18, color: c.textSecondary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: searchCtrl,
                      onChanged: onSearchChanged,
                      style: TextStyle(fontSize: 13, color: c.textPrimary),
                      decoration: InputDecoration(
                        hintText: loc.t('searchHint'),
                        hintStyle: TextStyle(fontSize: 12, color: c.textMuted),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  if (searchQuery.isNotEmpty)
                    IconButton(
                      icon: Icon(Icons.close_rounded, size: 16, color: c.textMuted),
                      splashRadius: 14,
                      onPressed: onClearSearch,
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 20),
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () async {
              if (!api.isOnline) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Iniciando microservicio de IA local (FastAPI en 127.0.0.1:8642)...'),
                    duration: Duration(seconds: 3),
                  ),
                );
                await api.ensureServerRunning();
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: (api.isOnline ? AppColors.success : AppColors.error).withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: (api.isOnline ? AppColors.success : AppColors.error).withOpacity(0.4),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: api.isOnline ? AppColors.success : AppColors.error,
                    ),
                  ),
                  const SizedBox(width: 7),
                  Text(
                    api.isOnline ? loc.t('iaOnline') : loc.t('iaOffline'),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: api.isOnline ? AppColors.success : AppColors.error,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 14),
          Stack(
            children: [
              IconButton(
                icon: Icon(Icons.notifications_none_rounded, size: 20, color: c.textSecondary),
                splashRadius: 18,
                onPressed: () {},
              ),
              Positioned(
                right: 10,
                top: 10,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: c.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 14),
          WindowControls(isDark: c.isDark),
        ],
      ),
    );
  }
}
