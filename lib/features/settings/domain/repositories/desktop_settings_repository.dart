import 'package:ai_limit_status/features/settings/domain/entities/desktop_settings.dart';

abstract interface class DesktopSettingsRepository {
  Future<void> initialize(String appName);

  Future<DesktopSettings> load();

  Future<DesktopSettingUpdateResult> setNotificationsEnabled(bool enabled);

  Future<DesktopSettingUpdateResult> setLaunchAtStartupEnabled(bool enabled);

  Future<bool> canSendUsageWarnings();

  Future<void> completeOnboarding();

  Future<void> openNotificationSettings();
}
