import 'dart:async';

import 'package:ai_limit_status/core/platform/desktop_notification_service.dart';
import 'package:ai_limit_status/core/platform/desktop_startup_service.dart';
import 'package:ai_limit_status/features/settings/data/datasources/desktop_settings_store.dart';
import 'package:ai_limit_status/features/settings/domain/entities/desktop_settings.dart';
import 'package:ai_limit_status/features/settings/domain/repositories/desktop_settings_repository.dart';
import 'package:ai_limit_status/features/usage/domain/entities/provider_usage.dart';

class DesktopSettingsRepositoryImpl implements DesktopSettingsRepository {
  DesktopSettingsRepositoryImpl(
    this._store,
    this._notificationService,
    this._startupService,
  );

  final DesktopSettingsStore _store;
  final DesktopNotificationService _notificationService;
  final DesktopStartupService _startupService;
  final StreamController<ClaudeStatusLimitPreference>
  _claudeStatusLimitChanges = StreamController.broadcast();

  bool _isInitialized = false;

  @override
  Stream<ClaudeStatusLimitPreference> get claudeStatusLimitChanges =>
      _claudeStatusLimitChanges.stream;

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
      claudeStatusLimitPreference: stored.claudeStatusLimitPreference,
      visibleProviders: UsageProvider.values.toSet(),
      statusBarHiddenProviders: _statusBarHidden(stored),
    );
  }

  @override
  Future<Set<UsageProvider>> loadVisibleProviders() async {
    return UsageProvider.values.toSet();
  }

  @override
  Future<Set<UsageProvider>> loadStatusBarHiddenProviders() async {
    return _statusBarHidden(await _store.read());
  }

  @override
  Future<DesktopSettingUpdateResult> setProviderInStatusBar(
    UsageProvider provider,
    bool shown,
  ) async {
    try {
      final stored = await _store.read();
      final hidden = _statusBarHidden(stored);
      if (shown) {
        hidden.remove(provider);
      } else {
        hidden.add(provider);
      }
      // Writing the merged set retires the old "hidden providers" setting.
      await _store.write(
        stored.copyWith(
          hiddenProviders: const {},
          statusBarHiddenProviders: hidden,
        ),
      );
      return DesktopSettingUpdateResult.succeeded;
    } on Object {
      return DesktopSettingUpdateResult.failed;
    }
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
  Future<ClaudeStatusLimitPreference> loadClaudeStatusLimitPreference() async {
    return (await _store.read()).claudeStatusLimitPreference;
  }

  @override
  Future<DesktopSettingUpdateResult> setClaudeStatusLimitPreference(
    ClaudeStatusLimitPreference preference,
  ) async {
    try {
      final stored = await _store.read();
      await _store.write(
        stored.copyWith(claudeStatusLimitPreference: preference),
      );
      _claudeStatusLimitChanges.add(preference);
      return DesktopSettingUpdateResult.succeeded;
    } on Object {
      return DesktopSettingUpdateResult.failed;
    }
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

  /// Providers kept out of the status shortcut. Earlier versions could hide
  /// a provider entirely; those now keep their card and stay out of the
  /// status shortcut instead.
  Set<UsageProvider> _statusBarHidden(StoredDesktopSettings stored) => {
    ...stored.statusBarHiddenProviders,
    ...stored.hiddenProviders,
  };

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
