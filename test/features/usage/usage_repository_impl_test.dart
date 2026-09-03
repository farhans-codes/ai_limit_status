import 'package:ai_limit_status/features/settings/domain/entities/desktop_settings.dart';
import 'package:ai_limit_status/features/settings/domain/repositories/desktop_settings_repository.dart';
import 'package:ai_limit_status/features/usage/data/datasources/usage_data_source.dart';
import 'package:ai_limit_status/features/usage/data/models/provider_usage_model.dart';
import 'package:ai_limit_status/features/usage/data/repositories/usage_repository_impl.dart';
import 'package:ai_limit_status/features/usage/domain/entities/provider_usage.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeDataSource implements UsageDataSource {
  Set<UsageProvider>? requestedProviders;

  @override
  Future<List<ProviderUsageModel>> fetchUsage({
    Set<UsageProvider>? providers,
  }) async {
    requestedProviders = providers;
    return [
      for (final provider in providers ?? UsageProvider.values.toSet())
        ProviderUsageModel.disconnected(
          provider: provider,
          issue: UsageConnectionIssue.cliNotFound,
        ),
    ];
  }
}

class _FakeSettingsRepository implements DesktopSettingsRepository {
  _FakeSettingsRepository(this.visible);

  final Set<UsageProvider> visible;

  @override
  Future<Set<UsageProvider>> loadVisibleProviders() async => visible;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

void main() {
  test(
    'disconnected providers are returned instead of being dropped',
    () async {
      final dataSource = _FakeDataSource();
      final repository = UsageRepositoryImpl(
        dataSource,
        _FakeSettingsRepository(UsageProvider.values.toSet()),
      );

      final usages = await repository.fetchUsage();

      expect(usages.map((usage) => usage.provider), UsageProvider.values);
      expect(usages.every((usage) => !usage.isConnected), isTrue);
      expect(
        usages.every(
          (usage) => usage.connectionIssue == UsageConnectionIssue.cliNotFound,
        ),
        isTrue,
      );
    },
  );

  test('hidden providers are not read at all', () async {
    final dataSource = _FakeDataSource();
    final repository = UsageRepositoryImpl(
      dataSource,
      _FakeSettingsRepository({UsageProvider.codex}),
    );

    final usages = await repository.fetchUsage();

    expect(dataSource.requestedProviders, {UsageProvider.codex});
    expect(usages.single.provider, UsageProvider.codex);
  });

  test('DesktopSettings exposes visibility and manual session state', () {
    const settings = DesktopSettings(
      notificationsEnabled: false,
      launchAtStartupEnabled: false,
      onboardingCompleted: true,
      claudeStatusLimitPreference: ClaudeStatusLimitPreference.fiveHour,
      visibleProviders: {UsageProvider.claude},
      hasManualClaudeSessionKey: true,
    );
    expect(settings.visibleProviders, {UsageProvider.claude});
    expect(settings.hasManualClaudeSessionKey, isTrue);
  });
}
