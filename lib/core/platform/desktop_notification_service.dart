import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class DesktopNotificationService {
  static const _windowsAppUserModelId = 'com.ailimitstatus.AILimitStatus';
  static const _windowsGuid = '6f4e47c9-7e92-47e4-a8a2-81c21e74b7ac';

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;
  Future<bool>? _initialization;
  int _nextNotificationId = 1;

  Future<bool> initialize(String appName) async {
    if (_isInitialized) {
      return true;
    }
    final initialization = _initialization;
    if (initialization != null) {
      return initialization;
    }
    final pendingInitialization = _initialize(appName);
    _initialization = pendingInitialization;
    final initialized = await pendingInitialization;
    if (!initialized) {
      _initialization = null;
    }
    return initialized;
  }

  Future<bool> _initialize(String appName) async {
    try {
      final initialized = await _notifications.initialize(
        settings: InitializationSettings(
          macOS: const DarwinInitializationSettings(
            requestAlertPermission: false,
            requestSoundPermission: false,
            requestBadgePermission: false,
          ),
          windows: WindowsInitializationSettings(
            appName: appName,
            appUserModelId: _windowsAppUserModelId,
            guid: _windowsGuid,
          ),
        ),
      );
      _isInitialized = Platform.isMacOS || initialized == true;
      return _isInitialized;
    } on Object {
      return false;
    }
  }

  Future<bool> requestPermission() async {
    if (!_isInitialized) {
      return false;
    }
    if (!Platform.isMacOS) {
      return Platform.isWindows;
    }
    try {
      if (await isPermissionGranted()) {
        return true;
      }
      final implementation = _notifications
          .resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin
          >();
      final granted =
          await implementation?.requestPermissions(alert: true, sound: true) ??
          false;
      return granted || await isPermissionGranted();
    } on Object {
      return false;
    }
  }

  Future<bool> isPermissionGranted() async {
    if (!_isInitialized) {
      return false;
    }
    if (!Platform.isMacOS) {
      return Platform.isWindows;
    }
    try {
      final implementation = _notifications
          .resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin
          >();
      final permissions = await implementation?.checkPermissions();
      return permissions?.isEnabled ?? false;
    } on Object {
      return false;
    }
  }

  Future<void> openPermissionSettings() async {
    if (!Platform.isMacOS) {
      return;
    }
    try {
      await _notifications
          .resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin
          >()
          ?.openAppNotificationSettings();
    } on Object {
      // Opening System Settings is a best-effort recovery path.
    }
  }

  Future<bool> show({required String title, required String body}) async {
    if (!_isInitialized || !await isPermissionGranted()) {
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
