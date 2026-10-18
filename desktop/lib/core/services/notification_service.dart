import 'package:flutter/foundation.dart';

enum NotificationType { download, lyrics, scan, system, error }

class AppNotification {
  final String id;
  final String title;
  final String message;
  final DateTime timestamp;
  final NotificationType type;
  final String? filePath;
  bool isRead;

  AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.timestamp,
    required this.type,
    this.filePath,
    this.isRead = false,
  });
}

/// Servicio central de notificaciones y registro de actividad de Titofy
class NotificationService extends ChangeNotifier {
  final List<AppNotification> _notifications = [];

  List<AppNotification> get notifications => List.unmodifiable(_notifications);
  int get unreadCount => _notifications.where((n) => !n.isRead).length;
  bool get hasUnread => unreadCount > 0;

  void add({
    required String title,
    required String message,
    required NotificationType type,
    String? filePath,
  }) {
    _notifications.insert(
      0,
      AppNotification(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        title: title,
        message: message,
        timestamp: DateTime.now(),
        type: type,
        filePath: filePath,
        isRead: false,
      ),
    );
    if (_notifications.length > 50) _notifications.removeLast();
    notifyListeners();
  }

  void markAllAsRead() {
    for (final n in _notifications) {
      n.isRead = true;
    }
    notifyListeners();
  }

  void clearAll() {
    _notifications.clear();
    notifyListeners();
  }
}
