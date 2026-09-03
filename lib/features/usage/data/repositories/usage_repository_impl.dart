import 'package:ai_limit_status/features/settings/domain/repositories/desktop_settings_repository.dart';
import 'package:ai_limit_status/features/usage/data/datasources/usage_data_source.dart';
import 'package:ai_limit_status/features/usage/domain/entities/provider_usage.dart';
import 'package:ai_limit_status/features/usage/domain/repositories/usage_repository.dart';

class UsageRepositoryImpl implements UsageRepository {
  const UsageRepositoryImpl(this._dataSource, this._settingsRepository);

  final UsageDataSource _dataSource;
  final DesktopSettingsRepository _settingsRepository;

  /// Returns every provider the user has not hidden in Settings.
  ///
  /// Disconnected providers (CLI missing, signed out, browser session gone)
  /// are returned too, so the details window can show what is wrong and how
  /// to fix it instead of silently dropping the provider.
  @override
  Future<List<ProviderUsage>> fetchUsage() async {
    final visibleProviders = await _settingsRepository.loadVisibleProviders();
    return _dataSource.fetchUsage(providers: visibleProviders);
  }
}
