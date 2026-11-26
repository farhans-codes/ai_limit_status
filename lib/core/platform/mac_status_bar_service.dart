import 'dart:io';

import 'package:flutter/services.dart';

class MacStatusBarService {
  MacStatusBarService();

  static const _channel = MethodChannel('com.ailimitstatus/status_item');

  Future<void> initialize({
    required Map<String, String> providerIcons,
    required String openLabel,
    required String refreshLabel,
    required String quitLabel,
    required String initialTooltip,
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

    await _channel.invokeMethod<void>('initialize', {
      'icons': {
        for (final MapEntry(key: id, value: asset) in providerIcons.entries)
          id: await rootBundle.loadString(asset),
      },
      'openLabel': openLabel,
      'refreshLabel': refreshLabel,
      'quitLabel': quitLabel,
      'tooltip': initialTooltip,
    });
  }

  Future<void> update({
    required List<({String id, String value})> items,
    required String tooltip,
  }) async {
    if (!Platform.isMacOS) {
      return;
    }
    await _channel.invokeMethod<void>('update', {
      'items': [
        for (final item in items) {'id': item.id, 'value': item.value},
      ],
      'tooltip': tooltip,
    });
  }

  Future<void> show() async {
    if (!Platform.isMacOS) {
      return;
    }
    await _channel.invokeMethod<void>('show');
  }

  Future<void> destroy() async {
    if (!Platform.isMacOS) {
      return;
    }
    await _channel.invokeMethod<void>('destroy');
    _channel.setMethodCallHandler(null);
  }
}
