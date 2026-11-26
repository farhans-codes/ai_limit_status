import 'package:ai_limit_status/features/settings/domain/entities/desktop_settings.dart';
import 'package:ai_limit_status/features/usage/domain/entities/provider_usage.dart';

abstract interface class DesktopSettingsRepository {
  Stream<ClaudeStatusLimitPreference> get claudeStatusLimitChanges;

  Future<void> initialize(String appName);

  Future<DesktopSettings> load();

  Future<DesktopSettingUpdateResult> setNotificationsEnabled(bool enabled);

  Future<DesktopSettingUpdateResult> setLaunchAtStartupEnabled(bool enabled);

  Future<ClaudeStatusLimitPreference> loadClaudeStatusLimitPreference();

  Future<DesktopSettingUpdateResult> setClaudeStatusLimitPreference(
    ClaudeStatusLimitPreference preference,
  );

  /// Every provider is read; the status shortcut is the only place a
  /// provider can be hidden.
  Future<Set<UsageProvider>> loadVisibleProviders();

  Future<Set<UsageProvider>> loadStatusBarHiddenProviders();

  Future<DesktopSettingUpdateResult> setProviderInStatusBar(
    UsageProvider provider,
    bool shown,
  );

  Future<bool> canSendUsageWarnings();

  Future<void> completeOnboarding();

  Future<void> openNotificationSettings();
}
