import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

const _channel = MethodChannel('com.ailimitstatus/keychain');
const _macPromptTimeout = Duration(seconds: 45);
const _windowsBridgeTimeout = Duration(seconds: 2);

Future<String?> readChatGptBrowserCookieHeader() => _readBrowserValue(
  macMethod: 'readChatGPTWebCookieHeader',
  windowsKey: 'chatgptCookieHeader',
);

Future<String?> readClaudeBrowserSessionKey() => _readBrowserValue(
  macMethod: 'readClaudeWebSessionKey',
  windowsKey: 'claudeSessionKey',
);

Future<String?> _readBrowserValue({
  required String macMethod,
  required String windowsKey,
}) async {
  try {
    if (Platform.isMacOS) {
      return await _channel
          .invokeMethod<String>(macMethod)
          .timeout(_macPromptTimeout);
    }
    if (!Platform.isWindows) {
      return null;
    }
    final raw = await _channel
        .invokeMethod<String>('readWindowsBrowserSessions')
        .timeout(_windowsBridgeTimeout);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    final payload = jsonDecode(raw);
    if (payload is! Map<String, dynamic>) {
      return null;
    }
    final value = payload[windowsKey];
    return value is String && value.isNotEmpty ? value : null;
  } on Object {
    return null;
  }
}
