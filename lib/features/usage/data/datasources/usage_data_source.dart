import 'package:ai_limit_status/features/usage/data/models/provider_usage_model.dart';
import 'package:ai_limit_status/features/usage/data/datasources/claude_usage_reader.dart';
import 'package:ai_limit_status/features/usage/data/datasources/codex_usage_reader.dart';
import 'package:ai_limit_status/features/usage/data/datasources/usage_read_exception.dart';
import 'package:ai_limit_status/features/usage/domain/entities/provider_usage.dart';

abstract interface class UsageDataSource {
  Future<List<ProviderUsageModel>> fetchUsage();
}

class LiveUsageDataSource implements UsageDataSource {
  LiveUsageDataSource(this._codexReader, this._claudeReader);

  static const _maximumCachedUsageAge = Duration(minutes: 15);

  final CodexUsageReader _codexReader;
  final ClaudeUsageReader _claudeReader;
  final Map<UsageProvider, ProviderUsageModel> _lastSuccessfulUsage = {};

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
      return usage;
    } on UsageReadException catch (error) {
      final cachedUsage = _lastSuccessfulUsage[provider];
      if (error.issue == UsageConnectionIssue.unavailable &&
          _isFresh(cachedUsage)) {
        return cachedUsage;
      }
      return ProviderUsageModel.disconnected(
        provider: provider,
        issue: error.issue,
      );
    } on Object {
      final cachedUsage = _lastSuccessfulUsage[provider];
      if (_isFresh(cachedUsage)) {
        return cachedUsage;
      }
      return ProviderUsageModel.disconnected(
        provider: provider,
        issue: UsageConnectionIssue.unavailable,
      );
    }
  }

  bool _isFresh(ProviderUsageModel? usage) {
    return usage != null &&
        DateTime.now().difference(usage.fetchedAt) <= _maximumCachedUsageAge;
  }
}
