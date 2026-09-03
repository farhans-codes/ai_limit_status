import 'dart:io';

import 'package:ai_limit_status/core/diagnostics/app_log.dart';
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
    void Function()? onPopoverWillShow,
    void Function()? onPopoverShown,
    void Function()? onPopoverHidden,
  }) async {
    if (!Platform.isWindows) {
      return;
    }

    _channel.setMethodCallHandler((call) async {
      AppLog.log('taskbar: native event ${call.method}');
      switch (call.method) {
        // Older runner builds asked Dart to toggle/show the window; the
        // current runner does it natively and only reports the outcome.
        case 'toggle':
          await onToggle();
        case 'show':
          await onShow();
        case 'refresh':
          await onRefresh();
        case 'quit':
          await onQuit();
        case 'popoverWillShow':
          onPopoverWillShow?.call();
        case 'popoverShown':
          onPopoverShown?.call();
        case 'popoverHidden':
          onPopoverHidden?.call();
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

  /// Shows the details window anchored to the taskbar indicators.
  ///
  /// Returns `null` when the runner does not implement native popover
  /// handling (older build), so the caller can fall back to positioning the
  /// window from Dart.
  Future<bool?> showPopover() => _invokePopoverMethod('showPopover');

  Future<bool?> togglePopover() => _invokePopoverMethod('togglePopover');

  Future<bool?> hidePopover() => _invokePopoverMethod('hidePopover');

  Future<bool?> isPopoverVisible() => _invokePopoverMethod('isPopoverVisible');

  Future<bool?> _invokePopoverMethod(String method) async {
    if (!Platform.isWindows) {
      return null;
    }
    try {
      final result = await _channel.invokeMethod<bool>(method);
      AppLog.log('taskbar: $method -> $result');
      return result ?? true;
    } on MissingPluginException {
      AppLog.log('taskbar: $method not implemented by this runner');
      return null;
    } on PlatformException catch (error) {
      AppLog.log('taskbar: $method failed: ${error.code} ${error.message}');
      return null;
    }
  }

  Future<void> destroy() async {
    if (!Platform.isWindows) {
      return;
    }
    await _channel.invokeMethod<void>('destroy');
    _channel.setMethodCallHandler(null);
  }
}
