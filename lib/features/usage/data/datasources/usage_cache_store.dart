import 'dart:convert';
import 'dart:io';

import 'package:ai_limit_status/features/usage/data/models/provider_usage_model.dart';
import 'package:ai_limit_status/features/usage/domain/entities/provider_usage.dart';

class UsageCacheStore {
  const UsageCacheStore();

  Future<ProviderUsageModel?> readUsage(UsageProvider provider) async {
    final file = _cacheFile(provider);
    try {
      if (!await file.exists()) {
        return null;
      }
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      final fetchedAt = DateTime.tryParse(
        decoded['fetchedAt']?.toString() ?? '',
      );
      final rawLimits = decoded['limits'];
      if (fetchedAt == null || rawLimits is! List) {
        return null;
      }
      final limits = rawLimits
          .whereType<Map<String, dynamic>>()
          .map(_decodeLimit)
          .nonNulls
          .toList();
      if (limits.isEmpty) {
        return null;
      }
      return ProviderUsageModel(
        provider: provider,
        limits: limits,
        isConnected: true,
        isInstalled: true,
        isStale: true,
        fetchedAt: fetchedAt.toLocal(),
      );
    } on Object {
      return null;
    }
  }

  Future<void> writeUsage(ProviderUsageModel usage) async {
    if (!usage.isConnected || usage.isStale || usage.limits.isEmpty) {
      return;
    }
    final file = _cacheFile(usage.provider);
    await file.parent.create(recursive: true);
    await file.writeAsString(
      jsonEncode({
        'fetchedAt': usage.fetchedAt.toUtc().toIso8601String(),
        'limits': usage.limits
            .map(
              (limit) => {
                'type': limit.type.name,
                'remainingPercent': limit.remainingPercent,
                'resetsAt': limit.resetsAt?.toUtc().toIso8601String(),
              },
            )
            .toList(),
      }),
      flush: true,
    );
  }

  UsageLimit? _decodeLimit(Map<String, dynamic> value) {
    final typeName = value['type'];
    final remainingPercent = value['remainingPercent'];
    if (typeName is! String || remainingPercent is! num) {
      return null;
    }
    UsageLimitType type;
    try {
      type = UsageLimitType.values.byName(typeName);
    } on ArgumentError {
      return null;
    }
    final rawResetTime = value['resetsAt'];
    final resetsAt = rawResetTime is String
        ? DateTime.tryParse(rawResetTime)?.toLocal()
        : null;
    return UsageLimit(
      type: type,
      remainingPercent: remainingPercent.toInt().clamp(0, 100),
      resetsAt: resetsAt,
    );
  }

  File _cacheFile(UsageProvider provider) {
    final environment = Platform.environment;
    final userHome = environment['HOME'];
    late final String baseDirectory;
    if (Platform.isWindows) {
      baseDirectory =
          environment['LOCALAPPDATA'] ??
          environment['USERPROFILE'] ??
          Directory.systemTemp.path;
      return File(
        '$baseDirectory\\AI Limit Status\\${provider.name}_usage_cache.json',
      );
    }
    if (Platform.isMacOS && userHome != null) {
      baseDirectory = '$userHome/Library/Application Support/AI Limit Status';
    } else {
      baseDirectory =
          environment['XDG_DATA_HOME'] ??
          (userHome == null
              ? '${Directory.systemTemp.path}/ai_limit_status'
              : '$userHome/.local/share/ai_limit_status');
    }
    return File('$baseDirectory/${provider.name}_usage_cache.json');
  }
}
