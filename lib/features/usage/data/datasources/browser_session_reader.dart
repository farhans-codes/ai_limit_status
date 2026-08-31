import 'dart:io';

import 'package:flutter/services.dart';

const _channel = MethodChannel('com.ailimitstatus/keychain');
const _macPromptTimeout = Duration(seconds: 45);

Future<String?> readChatGptBrowserCookieHeader() =>
    _readBrowserValue('readChatGPTWebCookieHeader');

Future<String?> readClaudeBrowserSessionKey() =>
    _readBrowserValue('readClaudeWebSessionKey');

Future<String?> _readBrowserValue(String method) async {
  if (!Platform.isMacOS) {
    return null;
  }
  try {
    final value = await _channel
        .invokeMethod<String>(method)
        .timeout(_macPromptTimeout);
    return value == null || value.isEmpty ? null : value;
  } on Object {
    return null;
  }
}
