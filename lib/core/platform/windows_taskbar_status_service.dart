import 'dart:io';

import 'package:flutter/services.dart';

class WindowsTaskbarStatusService {
  WindowsTaskbarStatusService();

  static const _channel = MethodChannel(
    'com.ailimitstatus/windows_taskbar_status',
  );

  Future<void> initialize({
    required String openLabel,
    required String refreshLabel,
    required String quitLabel,
    required String initialTooltip,
    required Future<void> Function() onToggle,
    required Future<void> Function() onShow,
    required Future<void> Function() onRefresh,
    required Future<void> Function() onQuit,
  }) async {
    if (!Platform.isWindows) {
      return;
    }

    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'toggle':
          await onToggle();
        case 'show':
          await onShow();
        case 'refresh':
          await onRefresh();
        case 'quit':
          await onQuit();
      }
    });

    await _channel.invokeMethod<void>('initialize', {
      'openLabel': openLabel,
      'refreshLabel': refreshLabel,
      'quitLabel': quitLabel,
      'tooltip': initialTooltip,
    });
  }

  Future<void> update({
    required String? codexValue,
    required String? claudeValue,
    required String tooltip,
  }) async {
    if (!Platform.isWindows) {
      return;
    }
    await _channel.invokeMethod<void>('update', {
      'codexValue': codexValue,
      'claudeValue': claudeValue,
      'tooltip': tooltip,
    });
  }

  Future<void> destroy() async {
    if (!Platform.isWindows) {
      return;
    }
    await _channel.invokeMethod<void>('destroy');
    _channel.setMethodCallHandler(null);
  }
}
