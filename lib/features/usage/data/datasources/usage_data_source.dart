import 'package:ai_limit_status/features/usage/data/models/provider_usage_model.dart';
import 'package:ai_limit_status/features/usage/data/datasources/claude_usage_reader.dart';
import 'package:ai_limit_status/features/usage/data/datasources/codex_usage_reader.dart';
import 'package:ai_limit_status/features/usage/data/datasources/provider_usage_reader.dart';
import 'package:ai_limit_status/features/usage/data/datasources/usage_read_exception.dart';
import 'package:ai_limit_status/features/usage/data/datasources/usage_cache_store.dart';
import 'package:ai_limit_status/features/usage/domain/entities/provider_usage.dart';

abstract interface class UsageDataSource {
  /// Reads usage for [providers] (every provider when `null`). Providers the
  /// user hid are skipped entirely so they never trigger credential prompts.
  Future<List<ProviderUsageModel>> fetchUsage({Set<UsageProvider>? providers});
}

class LiveUsageDataSource implements UsageDataSource {
  LiveUsageDataSource(
    CodexUsageReader codexReader,
    ClaudeUsageReader claudeReader,
    this._cacheStore, {
    Map<UsageProvider, ProviderUsageReader> additionalReaders = const {},
  }) : _readers = {
         UsageProvider.codex: codexReader,
         UsageProvider.claude: claudeReader,
         ...additionalReaders,
       };

  /// Providers that get no card until they are found on this machine, so
  /// people who do not use them are not asked to set them up.
  static const _hiddenUntilInstalled = {UsageProvider.antigravity};

  static const _maximumCachedUsageAge = Duration(hours: 24);

  final Map<UsageProvider, ProviderUsageReader> _readers;
  final UsageCacheStore _cacheStore;
  final Map<UsageProvider, ProviderUsageModel> _lastSuccessfulUsage = {};
  final Set<UsageProvider> _loadedPersistentCache = {};

  @override
  Future<List<ProviderUsageModel>> fetchUsage({
    Set<UsageProvider>? providers,
  }) async {
    final requested = providers ?? UsageProvider.values.toSet();
    final usages = await Future.wait([
      for (final MapEntry(key: provider, value: reader) in _readers.entries)
        if (requested.contains(provider)) _readProvider(provider, reader),
    ]);
    return usages.nonNulls.toList();
  }

  Future<ProviderUsageModel?> _readProvider(
    UsageProvider provider,
    ProviderUsageReader reader,
  ) async {
    try {
      final usage = await reader.read();
      _lastSuccessfulUsage[provider] = usage;
      try {
        await _cacheStore.writeUsage(usage);
      } on Object {
        // A cache write failure must not hide a successful live response.
      }
      return usage;
    } on UsageReadException catch (error) {
      if (error.issue == UsageConnectionIssue.unavailable ||
          error.issue == UsageConnectionIssue.appNotRunning) {
        final cachedUsage = await _readCachedUsage(provider);
        if (cachedUsage != null) {
          return cachedUsage.asStale();
        }
      }
      if (error.issue == UsageConnectionIssue.cliNotFound &&
          _hiddenUntilInstalled.contains(provider)) {
        return null;
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
