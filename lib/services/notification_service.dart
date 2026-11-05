import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    try {
      await _notificationsPlugin.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (response) {
          debugPrint('[NotificationService] Tapped notification: ${response.payload}');
        },
      );
      _isInitialized = true;
    } catch (e) {
      debugPrint('[NotificationService] Initialization error: $e');
    }
  }

  /// Shows ongoing conversion progress in Android notification drawer
  Future<void> showProgressNotification({
    required int notificationId,
    required String title,
    required String fileName,
    required int progressPercent,
    required double speedRatio,
  }) async {
    if (!Platform.isAndroid || !_isInitialized) return;

    try {
      final androidDetails = AndroidNotificationDetails(
        'v2a_conversions',
        'Media Conversions',
        channelDescription: 'Active video to audio conversion tasks',
        importance: Importance.low,
        priority: Priority.low,
        ongoing: true,
        onlyAlertOnce: true,
        showProgress: true,
        maxProgress: 100,
        progress: progressPercent,
      );

      final speedText = speedRatio > 0 ? ' • ${speedRatio.toStringAsFixed(1)}x' : '';
      await _notificationsPlugin.show(
        id: notificationId,
        title: title,
        body: '$fileName ($progressPercent%$speedText)',
        notificationDetails: NotificationDetails(android: androidDetails),
      );
    } catch (e) {
      debugPrint('[NotificationService] Progress notification error: $e');
    }
  }

  /// Shows completion notification
  Future<void> showCompletionNotification({
    required int notificationId,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!Platform.isAndroid || !_isInitialized) return;

    try {
      const androidDetails = AndroidNotificationDetails(
        'v2a_results',
        'Conversion Results',
        channelDescription: 'Notifies when media conversions complete or fail',
        importance: Importance.high,
        priority: Priority.high,
        ongoing: false,
      );

      await _notificationsPlugin.show(
        id: notificationId,
        title: title,
        body: body,
        notificationDetails: const NotificationDetails(android: androidDetails),
        payload: payload,
      );
    } catch (e) {
      debugPrint('[NotificationService] Completion notification error: $e');
    }
  }

  /// Cancels a specific notification
  Future<void> cancelNotification(int notificationId) async {
    try {
      await _notificationsPlugin.cancel(id: notificationId);
    } catch (_) {}
  }
}
