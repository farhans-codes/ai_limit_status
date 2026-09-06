import 'dart:convert';

/// Reads Claude's single UTF-8 blob or manifest-first base64 chunks.
/// Part -2 is the manifest, -1 is the single blob, and 0..255 are chunks.
Future<String?> readWindowsClaudeCredentialDocument(
  Future<List<int>?> Function(int part) readBytes,
) async {
  Future<String?> readPart(int part) async {
    final bytes = await readBytes(part);
    return bytes == null ? null : utf8.decode(bytes);
  }

  // Claude publishes the manifest last. A leftover single-value entry must
  // not mask a newer chunked credential, even if that chunked read fails.
  Map<String, dynamic>? manifest;
  try {
    final raw = await readPart(-2);
    final value = raw == null ? null : jsonDecode(raw);
    if (value is Map<String, dynamic>) manifest = value;
  } on FormatException {
    // Match Claude's single-value fallback for an invalid manifest.
  }
  final count = manifest?['n'];
  final length = manifest?['l'];
  if (count is! int ||
      length is! int ||
      count < 1 ||
      count > 256 ||
      length < 1 ||
      length > count * 2400) {
    return readPart(-1);
  }
  final encoded = StringBuffer();
  for (var index = 0; index < count; index++) {
    final chunk = await readPart(index);
    if (chunk == null || chunk.length > 2400) return null;
    encoded.write(chunk);
  }
  if (encoded.length != length) return null;
  return utf8.decode(base64.decode(encoded.toString()));
}
