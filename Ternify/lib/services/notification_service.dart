import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

/// Model notifikasi peternakan
class NotifikasiItem {
  final String id;
  final String tipe; // vaksinasi, pemeriksaan, kelahiran, berat, kesehatan
  final String prioritas; // tinggi, sedang, rendah
  final String judul;
  final String pesan;
  final String earTag;
  final String ikon;
  final DateTime waktu;
  bool dibaca;

  NotifikasiItem({
    required this.id,
    required this.tipe,
    required this.prioritas,
    required this.judul,
    required this.pesan,
    required this.earTag,
    required this.ikon,
    required this.waktu,
    this.dibaca = false,
  });

  factory NotifikasiItem.fromJson(Map<String, dynamic> json) {
    return NotifikasiItem(
      id: json['id']?.toString() ?? '',
      tipe: json['tipe'] ?? '',
      prioritas: json['prioritas'] ?? 'rendah',
      judul: json['judul'] ?? '',
      pesan: json['pesan'] ?? '',
      earTag: json['ear_tag'] ?? '',
      ikon: json['ikon'] ?? '',
      waktu: DateTime.tryParse(json['waktu'] ?? '') ?? DateTime.now(),
      dibaca: json['dibaca'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'tipe': tipe,
    'prioritas': prioritas,
    'judul': judul,
    'pesan': pesan,
    'ear_tag': earTag,
    'ikon': ikon,
    'waktu': waktu.toIso8601String(),
    'dibaca': dibaca,
  };

  /// Warna berdasarkan prioritas
  Color get prioritasColor {
    switch (prioritas) {
      case 'tinggi':
        return const Color(0xFFD92D20);
      case 'sedang':
        return const Color(0xFFF79009);
      default:
        return const Color(0xFF039855);
    }
  }

  /// Background color (soft) berdasarkan prioritas
  Color get prioritasBg {
    switch (prioritas) {
      case 'tinggi':
        return const Color(0xFFFEF3F2);
      case 'sedang':
        return const Color(0xFFFFFAEB);
      default:
        return const Color(0xFFF0FDF4);
    }
  }

  /// Icon berdasarkan tipe
  IconData get iconData {
    switch (ikon) {
      case 'vaccine':
        return Icons.vaccines_rounded;
      case 'medical':
        return Icons.medical_services_rounded;
      case 'baby':
        return Icons.child_care_rounded;
      case 'scale':
        return Icons.monitor_weight_rounded;
      case 'alert':
        return Icons.warning_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  /// Warna icon berdasarkan tipe
  Color get ikonColor {
    switch (tipe) {
      case 'vaksinasi':
        return const Color(0xFF6366F1); // indigo
      case 'pemeriksaan':
        return const Color(0xFF0284C7); // sky blue
      case 'kelahiran':
        return const Color(0xFFEC4899); // pink
      case 'berat':
        return const Color(0xFF8B5CF6); // violet
      case 'kesehatan':
        return const Color(0xFFD92D20); // red
      default:
        return const Color(0xFF475467);
    }
  }

  Color get ikonBg {
    return ikonColor.withValues(alpha: 0.1);
  }
}

/// Service untuk mengelola notifikasi
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const String _cachedNotifKey = 'cached_notifikasi';
  static const String _readIdsKey = 'read_notif_ids';

  bool _initialized = false;

  // ─────────────────────────────────────────────
  // INISIALISASI
  // ─────────────────────────────────────────────

  Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        // Handle tap notifikasi — bisa navigate ke screen notifikasi
      },
    );

    _initialized = true;
  }

  /// Minta permission notifikasi (Android 13+)
  Future<bool> requestPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final granted = await android?.requestNotificationsPermission();
    return granted ?? false;
  }

  // ─────────────────────────────────────────────
  // TAMPILKAN NOTIFIKASI SISTEM
  // ─────────────────────────────────────────────

  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? channelId,
    String? channelName,
  }) async {
    if (!_initialized) await initialize();

    final androidDetails = AndroidNotificationDetails(
      channelId ?? 'ternify_notif',
      channelName ?? 'Ternify Peternakan',
      channelDescription: 'Notifikasi pengingat peternakan domba',
      importance: Importance.high,
      priority: Priority.high,
      styleInformation: BigTextStyleInformation(body),
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.show(id, title, body, details);
  }

  // ─────────────────────────────────────────────
  // FETCH DARI API
  // ─────────────────────────────────────────────

  Future<List<NotifikasiItem>> fetchNotifikasi() async {
    try {
      final data = await ApiService.fetchNotifikasiData();
      final readIds = await _getReadIds();
      final items =
          (data['data'] as List? ?? []).map((e) {
            final item = NotifikasiItem.fromJson(
              Map<String, dynamic>.from(e as Map),
            );
            item.dibaca = readIds.contains(item.id);
            return item;
          }).toList();

      // Cache ke local
      await _cacheNotifikasi(items);
      return items;
    } catch (_) {
      // Fallback ke cache
      return await _loadCachedNotifikasi();
    }
  }

  // ─────────────────────────────────────────────
  // PUSH NOTIF SISTEM (batch untuk item prioritas tinggi)
  // ─────────────────────────────────────────────

  Future<void> pushPriorityNotifications(
    List<NotifikasiItem> items,
  ) async {
    if (!_initialized) await initialize();

    final tinggi = items
        .where((n) => n.prioritas == 'tinggi' && !n.dibaca)
        .take(3) // maksimal 3 notif sistem sekaligus
        .toList();

    for (int i = 0; i < tinggi.length; i++) {
      final n = tinggi[i];
      await showNotification(
        id: n.id.hashCode,
        title: n.judul,
        body: n.pesan,
      );
    }
  }

  // ─────────────────────────────────────────────
  // BACA STATUS
  // ─────────────────────────────────────────────

  Future<void> markAsRead(String notifId) async {
    final ids = await _getReadIds();
    ids.add(notifId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_readIdsKey, ids.toList());
  }

  Future<void> markAllAsRead(List<NotifikasiItem> items) async {
    final ids = items.map((n) => n.id).toSet();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_readIdsKey, ids.toList());
  }

  Future<Set<String>> _getReadIds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_readIdsKey)?.toSet() ?? {};
  }

  // ─────────────────────────────────────────────
  // CACHE LOKAL
  // ─────────────────────────────────────────────

  Future<void> _cacheNotifikasi(List<NotifikasiItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(items.map((e) => e.toJson()).toList());
    await prefs.setString(_cachedNotifKey, encoded);
  }

  Future<List<NotifikasiItem>> _loadCachedNotifikasi() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cachedNotifKey);
      if (raw == null || raw.isEmpty) return [];
      final decoded = jsonDecode(raw) as List;
      return decoded
          .map(
            (e) => NotifikasiItem.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<int> getUnreadCount() async {
    final items = await _loadCachedNotifikasi();
    return items.where((n) => !n.dibaca).length;
  }
}
