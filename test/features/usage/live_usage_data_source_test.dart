import 'package:ai_limit_status/features/usage/data/datasources/claude_usage_reader.dart';
import 'package:ai_limit_status/features/usage/data/datasources/codex_usage_reader.dart';
import 'package:ai_limit_status/features/usage/data/datasources/usage_cache_store.dart';
import 'package:ai_limit_status/features/usage/data/datasources/usage_data_source.dart';
import 'package:ai_limit_status/features/usage/data/datasources/usage_read_exception.dart';
import 'package:ai_limit_status/features/usage/data/models/provider_usage_model.dart';
import 'package:ai_limit_status/features/usage/domain/entities/provider_usage.dart';
import 'package:flutter_test/flutter_test.dart';

class _ThrowingClaudeReader implements ClaudeUsageReader {
  int reads = 0;

  @override
  Future<ProviderUsageModel> read() async {
    reads++;
    throw const UsageReadException(UsageConnectionIssue.browserBlocked);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _ThrowingCodexReader implements CodexUsageReader {
  int reads = 0;

  @override
  Future<ProviderUsageModel> read() async {
    reads++;
    throw const UsageReadException(UsageConnectionIssue.cliNotFound);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _NoopCacheStore implements UsageCacheStore {
  @override
  Future<ProviderUsageModel?> readUsage(UsageProvider provider) async => null;

  @override
  Future<void> writeUsage(ProviderUsageModel usage) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

void main() {
  test('only requested providers are read and issues are preserved', () async {
    final claude = _ThrowingClaudeReader();
    final codex = _ThrowingCodexReader();
    final dataSource = LiveUsageDataSource(codex, claude, _NoopCacheStore());

    final usages = await dataSource.fetchUsage(
      providers: {UsageProvider.claude},
    );

    expect(codex.reads, 0);
    expect(claude.reads, 1);
    expect(usages.single.provider, UsageProvider.claude);
    expect(usages.single.isConnected, isFalse);
    expect(usages.single.connectionIssue, UsageConnectionIssue.browserBlocked);
    // Only a missing CLI marks the provider as not installed.
    expect(usages.single.isInstalled, isTrue);
  });

  test('every provider is read when no filter is given', () async {
    final claude = _ThrowingClaudeReader();
    final codex = _ThrowingCodexReader();
    final dataSource = LiveUsageDataSource(codex, claude, _NoopCacheStore());

    final usages = await dataSource.fetchUsage();

    expect(usages.map((usage) => usage.provider), UsageProvider.values);
    expect(codex.reads, 1);
    expect(claude.reads, 1);
  });
}
