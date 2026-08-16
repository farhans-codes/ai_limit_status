import 'package:ai_limit_status/core/platform/desktop_notification_service.dart';
import 'package:ai_limit_status/core/platform/desktop_startup_service.dart';
import 'package:ai_limit_status/features/settings/data/datasources/desktop_settings_store.dart';
import 'package:ai_limit_status/features/settings/domain/entities/desktop_settings.dart';
import 'package:ai_limit_status/features/settings/domain/repositories/desktop_settings_repository.dart';

class DesktopSettingsRepositoryImpl implements DesktopSettingsRepository {
  DesktopSettingsRepositoryImpl(
    this._store,
    this._notificationService,
    this._startupService,
  );

  final DesktopSettingsStore _store;
  final DesktopNotificationService _notificationService;
  final DesktopStartupService _startupService;

  bool _isInitialized = false;

  @override
  Future<void> initialize(String appName) async {
    if (_isInitialized) {
      return;
    }
    await _notificationService.initialize(appName);
    _startupService.setup(appName);
    _isInitialized = true;
  }

  @override
  Future<DesktopSettings> load() async {
    final stored = await _store.read();
    final notificationsEnabled = await _notificationsEnabled(stored);
    return DesktopSettings(
      notificationsEnabled: notificationsEnabled,
      launchAtStartupEnabled: await _startupService.isEnabled(),
      onboardingCompleted: stored.onboardingCompleted,
    );
  }

  @override
  Future<DesktopSettingUpdateResult> setNotificationsEnabled(
    bool enabled,
  ) async {
    final stored = await _store.read();
    if (!enabled) {
      await _store.write(
        stored.copyWith(
          notificationsEnabled: false,
          notificationPreferenceConfigured: true,
        ),
      );
      return DesktopSettingUpdateResult.succeeded;
    }

    final granted =
        await _notificationService.isPermissionGranted() ||
        await _notificationService.requestPermission();
    await _store.write(
      stored.copyWith(
        notificationsEnabled: granted,
        notificationPreferenceConfigured: granted,
      ),
    );
    return granted
        ? DesktopSettingUpdateResult.succeeded
        : DesktopSettingUpdateResult.permissionDenied;
  }

  @override
  Future<DesktopSettingUpdateResult> setLaunchAtStartupEnabled(
    bool enabled,
  ) async {
    final result = await _startupService.setEnabled(enabled);
    return switch (result) {
      StartupRegistrationResult.enabled || StartupRegistrationResult.disabled =>
        DesktopSettingUpdateResult.succeeded,
      StartupRegistrationResult.requiresApproval =>
        DesktopSettingUpdateResult.requiresApproval,
      StartupRegistrationResult.unsupported =>
        DesktopSettingUpdateResult.unsupported,
      StartupRegistrationResult.failed => DesktopSettingUpdateResult.failed,
    };
  }

  @override
  Future<bool> canSendUsageWarnings() async {
    final stored = await _store.read();
    return _notificationsEnabled(stored);
  }

  @override
  Future<void> completeOnboarding() async {
    final stored = await _store.read();
    await _store.write(stored.copyWith(onboardingCompleted: true));
  }

  @override
  Future<void> openNotificationSettings() {
    return _notificationService.openPermissionSettings();
  }

  Future<bool> _notificationsEnabled(StoredDesktopSettings stored) async {
    final permissionGranted = await _notificationService.isPermissionGranted();
    if (permissionGranted && !stored.notificationPreferenceConfigured) {
      await _store.write(
        stored.copyWith(
          notificationsEnabled: true,
          notificationPreferenceConfigured: true,
        ),
      );
      return true;
    }
    return stored.notificationsEnabled && permissionGranted;
  }
}
