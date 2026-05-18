import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// One item in the in-app notification center (not the OS tray).
class AppNotificationItem {
  const AppNotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    this.isRead = false,
    this.category = 'general',
  });

  final String id;
  final String title;
  final String body;
  final DateTime createdAt;
  final bool isRead;

  /// push | reminder | booking | general
  final String category;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'createdAt': createdAt.toIso8601String(),
        'isRead': isRead,
        'category': category,
      };

  factory AppNotificationItem.fromJson(Map<String, dynamic> json) {
    return AppNotificationItem(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      isRead: json['isRead'] == true,
      category: json['category']?.toString() ?? 'general',
    );
  }

  AppNotificationItem copyWith({bool? isRead}) {
    return AppNotificationItem(
      id: id,
      title: title,
      body: body,
      createdAt: createdAt,
      isRead: isRead ?? this.isRead,
      category: category,
    );
  }
}

/// Persists recent notifications for the dashboard bell modal.
class NotificationInboxService {
  NotificationInboxService._(this._prefs);

  static const _storageKey = 'app_notification_inbox_v1';
  static const _maxItems = 80;

  final SharedPreferences _prefs;
  static NotificationInboxService? _instance;

  final _changes = StreamController<void>.broadcast();

  Stream<void> get changes => _changes.stream;

  void _notify() {
    if (!_changes.isClosed) _changes.add(null);
  }

  static Future<NotificationInboxService> getInstance() async {
    if (_instance != null) return _instance!;
    final prefs = await SharedPreferences.getInstance();
    _instance = NotificationInboxService._(prefs);
    return _instance!;
  }

  List<AppNotificationItem> get items {
    final raw = _prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .whereType<Map>()
          .map((m) => AppNotificationItem.fromJson(
                m.map((k, v) => MapEntry(k.toString(), v)),
              ))
          .where((n) => n.id.isNotEmpty)
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (_) {
      return [];
    }
  }

  int get unreadCount => items.where((n) => !n.isRead).length;

  Future<void> add({
    required String title,
    required String body,
    String category = 'general',
  }) async {
    final trimmedTitle = title.trim();
    final trimmedBody = body.trim();
    if (trimmedTitle.isEmpty && trimmedBody.isEmpty) return;

    final entry = AppNotificationItem(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: trimmedTitle.isEmpty ? 'Notification' : trimmedTitle,
      body: trimmedBody,
      createdAt: DateTime.now(),
      category: category,
    );

    final next = [entry, ...items].take(_maxItems).toList();
    await _prefs.setString(
      _storageKey,
      jsonEncode(next.map((e) => e.toJson()).toList()),
    );
    _notify();
  }

  Future<void> markAllRead() async {
    final next = items.map((n) => n.copyWith(isRead: true)).toList();
    await _prefs.setString(
      _storageKey,
      jsonEncode(next.map((e) => e.toJson()).toList()),
    );
    _notify();
  }

  Future<void> clearAll() async {
    await _prefs.remove(_storageKey);
    _notify();
  }
}
