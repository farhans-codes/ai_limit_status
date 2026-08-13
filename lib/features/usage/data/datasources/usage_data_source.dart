import 'package:ai_limit_status/features/usage/data/models/provider_usage_model.dart';
import 'package:ai_limit_status/features/usage/data/datasources/claude_usage_reader.dart';
import 'package:ai_limit_status/features/usage/data/datasources/codex_usage_reader.dart';
import 'package:ai_limit_status/features/usage/data/datasources/usage_read_exception.dart';
import 'package:ai_limit_status/features/usage/data/datasources/usage_cache_store.dart';
import 'package:ai_limit_status/features/usage/domain/entities/provider_usage.dart';

abstract interface class UsageDataSource {
  Future<List<ProviderUsageModel>> fetchUsage();
}

class LiveUsageDataSource implements UsageDataSource {
  LiveUsageDataSource(this._codexReader, this._claudeReader, this._cacheStore);

  static const _maximumCachedUsageAge = Duration(hours: 24);

  final CodexUsageReader _codexReader;
  final ClaudeUsageReader _claudeReader;
  final UsageCacheStore _cacheStore;
  final Map<UsageProvider, ProviderUsageModel> _lastSuccessfulUsage = {};
  final Set<UsageProvider> _loadedPersistentCache = {};

  @override
  Future<List<ProviderUsageModel>> fetchUsage() {
    return Future.wait([
      _readProvider(UsageProvider.codex, _codexReader.read),
      _readProvider(UsageProvider.claude, _claudeReader.read),
    ]);
  }

  Future<ProviderUsageModel> _readProvider(
    UsageProvider provider,
    Future<ProviderUsageModel> Function() read,
  ) async {
    try {
      final usage = await read();
      _lastSuccessfulUsage[provider] = usage;
      try {
        await _cacheStore.writeUsage(usage);
      } on Object {
        // A cache write failure must not hide a successful live response.
      }
      return usage;
    } on UsageReadException catch (error) {
      if (error.issue == UsageConnectionIssue.unavailable) {
        final cachedUsage = await _readCachedUsage(provider);
        if (cachedUsage != null) {
          return cachedUsage.asStale();
        }
      }
      return ProviderUsageModel.disconnected(
        provider: provider,
        issue: error.issue,
      );
    } on Object {
      final cachedUsage = await _readCachedUsage(provider);
      if (cachedUsage != null) {
        return cachedUsage.asStale();
      }
      return ProviderUsageModel.disconnected(
        provider: provider,
        issue: UsageConnectionIssue.unavailable,
      );
    }
  }

  Future<ProviderUsageModel?> _readCachedUsage(UsageProvider provider) async {
    var cachedUsage = _lastSuccessfulUsage[provider];
    if (cachedUsage == null && _loadedPersistentCache.add(provider)) {
      cachedUsage = await _cacheStore.readUsage(provider);
      if (cachedUsage != null) {
        _lastSuccessfulUsage[provider] = cachedUsage;
      }
    }
    return cachedUsage != null && _isFresh(cachedUsage) ? cachedUsage : null;
  }

  bool _isFresh(ProviderUsageModel usage) {
    return DateTime.now().difference(usage.fetchedAt) <= _maximumCachedUsageAge;
  }
}
