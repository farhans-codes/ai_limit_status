import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class DesktopNotificationService {
  static const _windowsAppUserModelId = 'com.ailimitstatus.AILimitStatus';
  static const _windowsGuid = '6f4e47c9-7e92-47e4-a8a2-81c21e74b7ac';

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;
  int _nextNotificationId = 1;

  Future<bool> initialize(String appName) async {
    if (_isInitialized) {
      return true;
    }
    try {
      final initialized = await _notifications.initialize(
        settings: InitializationSettings(
          macOS: const DarwinInitializationSettings(
            requestAlertPermission: true,
            requestSoundPermission: true,
            requestBadgePermission: false,
          ),
          windows: WindowsInitializationSettings(
            appName: appName,
            appUserModelId: _windowsAppUserModelId,
            guid: _windowsGuid,
          ),
        ),
      );
      _isInitialized = initialized ?? false;
      return _isInitialized;
    } on Object {
      return false;
    }
  }

  Future<bool> show({required String title, required String body}) async {
    if (!_isInitialized) {
      return false;
    }
    try {
      await _notifications.show(
        id: _nextNotificationId++,
        title: title,
        body: body,
        notificationDetails: NotificationDetails(
          macOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentSound: true,
            presentBanner: true,
            presentList: true,
          ),
          windows: Platform.isWindows
              ? const WindowsNotificationDetails()
              : null,
        ),
      );
      return true;
    } on Object {
      return false;
    }
  }
}
