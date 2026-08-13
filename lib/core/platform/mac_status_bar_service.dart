import 'dart:io';

import 'package:flutter/services.dart';

class MacStatusBarService {
  MacStatusBarService();

  static const _channel = MethodChannel('com.ailimitstatus/status_item');

  Future<void> initialize({
    required String openLabel,
    required String refreshLabel,
    required String quitLabel,
    required String initialTooltip,
    required String unavailableValue,
    required Future<void> Function() onRefresh,
    required Future<void> Function() onQuit,
    required void Function() onWillShow,
  }) async {
    if (!Platform.isMacOS) {
      return;
    }

    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'refresh':
          await onRefresh();
        case 'quit':
          await onQuit();
        case 'willShow':
          onWillShow();
      }
    });

    final codexSvg = await rootBundle.loadString('assets/icons/codex.svg');
    final claudeSvg = await rootBundle.loadString('assets/icons/claude.svg');
    await _channel.invokeMethod<void>('initialize', {
      'codexSvg': codexSvg,
      'claudeSvg': claudeSvg,
      'codexValue': unavailableValue,
      'claudeValue': unavailableValue,
      'openLabel': openLabel,
      'refreshLabel': refreshLabel,
      'quitLabel': quitLabel,
      'tooltip': initialTooltip,
    });
  }

  Future<void> update({
    required String codexValue,
    required String claudeValue,
    required String tooltip,
  }) async {
    if (!Platform.isMacOS) {
      return;
    }
    await _channel.invokeMethod<void>('update', {
      'codexValue': codexValue,
      'claudeValue': claudeValue,
      'tooltip': tooltip,
    });
  }

  Future<void> destroy() async {
    if (!Platform.isMacOS) {
      return;
    }
    await _channel.invokeMethod<void>('destroy');
    _channel.setMethodCallHandler(null);
  }
}
