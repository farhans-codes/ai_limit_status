import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ai_limit_status/core/platform/app_window_service.dart';
import 'package:ai_limit_status/core/platform/tray_service.dart';
import 'package:ai_limit_status/features/settings/domain/entities/desktop_settings.dart';
import 'package:ai_limit_status/features/settings/domain/repositories/desktop_settings_repository.dart';
import 'package:ai_limit_status/features/settings/presentation/widgets/desktop_settings_dialog.dart';
import 'package:ai_limit_status/l10n/app_localizations.dart';

class DesktopSettingsController extends GetxController
    with WidgetsBindingObserver {
  DesktopSettingsController(
    this._repository,
    this._windowService,
    this._trayService,
  );

  final DesktopSettingsRepository _repository;
  final AppWindowService _windowService;
  final TrayService _trayService;

  final notificationsEnabled = false.obs;
  final launchAtStartupEnabled = false.obs;
  final isUpdating = false.obs;

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
    final l10n = _localizations;
    if (l10n == null) {
      return;
    }
    await _repository.initialize(l10n.appTitle);
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
      final l10n = _localizations;
      if (l10n == null) {
        return;
      }
      await _repository.initialize(l10n.appTitle);
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
    _onboardingCompleted = settings.onboardingCompleted;
  }

  Future<bool> _reloadStartupStatus() async {
    final settings = await _repository.load();
    return settings.launchAtStartupEnabled;
  }

  void _showUpdateFailure(
    DesktopSettingUpdateResult result, {
    required bool isNotification,
  }) {
    final l10n = _localizations;
    if (l10n == null) {
      return;
    }
    final message = switch (result) {
      DesktopSettingUpdateResult.permissionDenied =>
        l10n.notificationPermissionDenied,
      DesktopSettingUpdateResult.requiresApproval =>
        l10n.startupApprovalRequired,
      DesktopSettingUpdateResult.unsupported => l10n.startupUnsupported,
      DesktopSettingUpdateResult.failed => l10n.settingsUpdateFailed,
      DesktopSettingUpdateResult.succeeded => null,
    };
    if (message == null) {
      return;
    }
    Get.snackbar(
      l10n.settingsUpdateFailedTitle,
      message,
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 6),
      mainButton:
          isNotification &&
              result == DesktopSettingUpdateResult.permissionDenied
          ? TextButton(
              onPressed: openNotificationSettings,
              child: Text(l10n.openSystemSettings),
            )
          : null,
    );
  }

  AppLocalizations? get _localizations {
    final context = Get.context;
    return context == null ? null : AppLocalizations.of(context);
  }
}
