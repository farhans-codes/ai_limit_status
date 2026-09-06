// Run manually: dart --enable-asserts scripts/check_windows_claude_credentials.dart
// Synthetic data only; this does not access any OS credential store.
import 'dart:convert';
import 'dart:io';

import 'package:ai_limit_status/features/usage/data/datasources/windows_claude_credential_reader.dart';

Future<void> main() async {
  Future<String?> read(Map<int, String> parts) =>
      readWindowsClaudeCredentialDocument((part) async {
        final value = parts[part];
        return value == null ? null : utf8.encode(value);
      });

  const document = '{"claudeAiOauth":{"accessToken":"synthetic-only"}}';
  assert(await read({-1: document}) == document);
  assert(await read({}) == null);
  for (final invalid in [
    'not-json',
    '[]',
    '{"n":0,"l":4}',
    '{"n":257,"l":4}',
    '{"n":1.5,"l":4}',
    '{"n":1,"l":2401}',
  ]) {
    assert(await read({-2: invalid, -1: document}) == document);
  }

  final encoded = base64.encode(utf8.encode(document));
  final parts = {
    -2: jsonEncode({'n': 2, 'l': encoded.length}),
    -1: 'stale-single-value',
    0: encoded.substring(0, 12),
    1: encoded.substring(12),
  };
  assert(await read(parts) == document);
  assert(await read({...parts}..remove(1)) == null);
  assert(await read({...parts, 1: '${parts[1]}extra'}) == null);
  var rejected = false;
  try {
    await read({-2: '{"n":1,"l":4}', 0: '!!!!'});
  } on FormatException {
    rejected = true;
  }
  assert(rejected);
  stdout.writeln(
    'Windows Claude credential format checks passed (synthetic data).',
  );
}
