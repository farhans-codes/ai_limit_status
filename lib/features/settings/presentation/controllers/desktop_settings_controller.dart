import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ai_limit_status/core/constants/app_strings.dart';
import 'package:ai_limit_status/core/platform/app_window_service.dart';
import 'package:ai_limit_status/core/platform/browser_bridge_service.dart';
import 'package:ai_limit_status/core/platform/tray_service.dart';
import 'package:ai_limit_status/features/settings/domain/entities/desktop_settings.dart';
import 'package:ai_limit_status/features/settings/domain/repositories/desktop_settings_repository.dart';
import 'package:ai_limit_status/features/settings/presentation/widgets/desktop_settings_dialog.dart';
import 'package:ai_limit_status/features/usage/domain/entities/provider_usage.dart';

class DesktopSettingsController extends GetxController
    with WidgetsBindingObserver {
  DesktopSettingsController(
    this._repository,
    this._windowService,
    this._trayService,
    this._browserBridgeService,
  );

  final DesktopSettingsRepository _repository;
  final AppWindowService _windowService;
  final TrayService _trayService;
  final BrowserBridgeService _browserBridgeService;

  final notificationsEnabled = false.obs;
  final launchAtStartupEnabled = false.obs;
  final claudeStatusLimitPreference = ClaudeStatusLimitPreference.fiveHour.obs;
  final visibleProviders = UsageProvider.values.toSet().obs;
  final hasManualClaudeSessionKey = false.obs;

  /// `null` until probed, or on platforms without a bridge.
  final browserBridgeConnected = Rxn<bool>();
  final isUpdating = false.obs;

  /// Whether the platform can store a pasted claude.ai session key.
  bool get supportsManualClaudeSession => Platform.isWindows;

  bool get supportsBrowserBridge => _browserBridgeService.isSupported;

  bool _isInitialized = false;
  bool _dialogOpen = false;
  bool _onboardingCompleted = false;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void onReady() {
    super.onReady();
    unawaited(_initialize());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _isInitialized &&
        !isUpdating.value) {
      unawaited(_reload());
    }
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    super.onClose();
  }

  Future<void> _initialize() async {
    await _repository.initialize(AppStrings.instance.appTitle);
    await _reload();
    _isInitialized = true;

    if (!_onboardingCompleted) {
      await _windowService.whenReady;
      await _trayService.showDashboard();
      await openSettings(firstRun: true);
    }
  }

  Future<void> openSettings({bool firstRun = false}) async {
    if (_dialogOpen) {
      return;
    }
    if (!_isInitialized) {
      await _repository.initialize(AppStrings.instance.appTitle);
      await _reload();
      _isInitialized = true;
    } else {
      await _reload();
    }

    _dialogOpen = true;
    _windowService.setModalOpen(true);
    try {
      await Get.dialog<void>(
        DesktopSettingsDialog(controller: this, firstRun: firstRun),
        barrierDismissible: !firstRun,
      );
    } finally {
      _windowService.setModalOpen(false);
      _dialogOpen = false;
    }
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    if (isUpdating.value) {
      return;
    }
    isUpdating.value = true;
    try {
      final result = await _repository.setNotificationsEnabled(enabled);
      notificationsEnabled.value =
          result == DesktopSettingUpdateResult.succeeded && enabled;
      if (result != DesktopSettingUpdateResult.succeeded) {
        _showUpdateFailure(result, isNotification: true);
      }
    } finally {
      isUpdating.value = false;
    }
  }

  Future<void> setLaunchAtStartupEnabled(bool enabled) async {
    if (isUpdating.value) {
      return;
    }
    isUpdating.value = true;
    try {
      final result = await _repository.setLaunchAtStartupEnabled(enabled);
      if (result == DesktopSettingUpdateResult.succeeded) {
        launchAtStartupEnabled.value = enabled;
      } else {
        launchAtStartupEnabled.value = await _reloadStartupStatus();
        _showUpdateFailure(result, isNotification: false);
      }
    } finally {
      isUpdating.value = false;
    }
  }

  Future<void> setClaudeStatusLimitPreference(
    ClaudeStatusLimitPreference preference,
  ) async {
    if (isUpdating.value || preference == claudeStatusLimitPreference.value) {
      return;
    }
    isUpdating.value = true;
    try {
      final result = await _repository.setClaudeStatusLimitPreference(
        preference,
      );
      if (result == DesktopSettingUpdateResult.succeeded) {
        claudeStatusLimitPreference.value = preference;
      } else {
        _showUpdateFailure(result, isNotification: false);
      }
    } finally {
      isUpdating.value = false;
    }
  }

  Future<void> setProviderVisible(UsageProvider provider, bool visible) async {
    if (isUpdating.value) {
      return;
    }
    isUpdating.value = true;
    try {
      final result = await _repository.setProviderVisible(provider, visible);
      if (result == DesktopSettingUpdateResult.succeeded) {
        final providers = {...visibleProviders};
        if (visible) {
          providers.add(provider);
        } else {
          providers.remove(provider);
        }
        visibleProviders.assignAll(providers);
      } else {
        _showUpdateFailure(result, isNotification: false);
      }
    } finally {
      isUpdating.value = false;
    }
  }

  /// Stores the pasted claude.ai `sessionKey`; an empty value clears it.
  Future<bool> saveManualClaudeSessionKey(String sessionKey) async {
    if (isUpdating.value) {
      return false;
    }
    final trimmed = sessionKey.trim();
    if (trimmed.isNotEmpty && !trimmed.startsWith('sk-ant-')) {
      _showMessage(
        AppStrings.instance.settingsUpdateFailedTitle,
        AppStrings.instance.claudeSessionKeyInvalid,
      );
      return false;
    }
    isUpdating.value = true;
    try {
      final result = await _repository.setManualClaudeSessionKey(trimmed);
      if (result == DesktopSettingUpdateResult.succeeded) {
        hasManualClaudeSessionKey.value = trimmed.isNotEmpty;
        return true;
      }
      _showUpdateFailure(result, isNotification: false);
      return false;
    } finally {
      isUpdating.value = false;
    }
  }

  Future<void> clearManualClaudeSessionKey() => saveManualClaudeSessionKey('');

  Future<void> refreshBrowserBridgeStatus() async {
    browserBridgeConnected.value = await _browserBridgeService.isConnected();
  }

  Future<void> openBrowserExtensionFolder() async {
    if (!await _browserBridgeService.openExtensionFolder()) {
      _showMessage(
        AppStrings.instance.settingsUpdateFailedTitle,
        AppStrings.instance.browserExtensionFolderMissing,
      );
    }
  }

  Future<void> finish() async {
    if (!_onboardingCompleted) {
      await _repository.completeOnboarding();
      _onboardingCompleted = true;
    }
    if (Get.isDialogOpen == true) {
      Get.back<void>();
    }
  }

  Future<void> openNotificationSettings() {
    return _repository.openNotificationSettings();
  }

  Future<void> _reload() async {
    final settings = await _repository.load();
    notificationsEnabled.value = settings.notificationsEnabled;
    launchAtStartupEnabled.value = settings.launchAtStartupEnabled;
    claudeStatusLimitPreference.value = settings.claudeStatusLimitPreference;
    visibleProviders.assignAll(settings.visibleProviders);
    hasManualClaudeSessionKey.value = settings.hasManualClaudeSessionKey;
    _onboardingCompleted = settings.onboardingCompleted;
    unawaited(refreshBrowserBridgeStatus());
  }

  void _showMessage(String title, String message) {
    Get.snackbar(
      title,
      message,
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 6),
    );
  }

  Future<bool> _reloadStartupStatus() async {
    final settings = await _repository.load();
    return settings.launchAtStartupEnabled;
  }

  void _showUpdateFailure(
    DesktopSettingUpdateResult result, {
    required bool isNotification,
  }) {
    final strings = AppStrings.instance;
    final message = switch (result) {
      DesktopSettingUpdateResult.permissionDenied =>
        strings.notificationPermissionDenied,
      DesktopSettingUpdateResult.requiresApproval =>
        strings.startupApprovalRequired,
      DesktopSettingUpdateResult.unsupported => strings.startupUnsupported,
      DesktopSettingUpdateResult.failed => strings.settingsUpdateFailed,
      DesktopSettingUpdateResult.succeeded => null,
    };
    if (message == null) {
      return;
    }
    Get.snackbar(
      strings.settingsUpdateFailedTitle,
      message,
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 6),
      mainButton:
          isNotification &&
              result == DesktopSettingUpdateResult.permissionDenied
          ? TextButton(
              onPressed: openNotificationSettings,
              child: Text(strings.openSystemSettings),
            )
          : null,
    );
  }
}
