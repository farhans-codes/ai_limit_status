import 'package:ai_limit_status/features/settings/domain/entities/desktop_settings.dart';
import 'package:ai_limit_status/features/usage/domain/entities/provider_usage.dart';

abstract interface class DesktopSettingsRepository {
  Stream<ClaudeStatusLimitPreference> get claudeStatusLimitChanges;

  /// Emits whenever provider visibility changes, so usage can be refreshed
  /// immediately.
  Stream<void> get providerConfigurationChanges;

  Future<void> initialize(String appName);

  Future<DesktopSettings> load();

  Future<DesktopSettingUpdateResult> setNotificationsEnabled(bool enabled);

  Future<DesktopSettingUpdateResult> setLaunchAtStartupEnabled(bool enabled);

  Future<ClaudeStatusLimitPreference> loadClaudeStatusLimitPreference();

  Future<DesktopSettingUpdateResult> setClaudeStatusLimitPreference(
    ClaudeStatusLimitPreference preference,
  );

  Future<Set<UsageProvider>> loadVisibleProviders();

  Future<DesktopSettingUpdateResult> setProviderVisible(
    UsageProvider provider,
    bool visible,
  );

  Future<bool> canSendUsageWarnings();

  Future<void> completeOnboarding();

  Future<void> openNotificationSettings();
}
